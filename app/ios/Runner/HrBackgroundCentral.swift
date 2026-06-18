import CoreBluetooth
import Flutter
import Foundation

/// A CoreBluetooth central that owns the recording-time connection to a
/// heart-rate strap and buffers samples natively.
///
/// Why this exists: when iOS suspends the app, the Dart isolate is frozen and
/// can't receive BLE notifications over the platform channel — that's the data
/// loss we saw in the support logs (a ~49 minute gap). iOS still wakes the
/// *native* process briefly for each notification (granted by the
/// `bluetooth-central` background mode). This class runs in those windows: it
/// parses the heart-rate value and appends it to an in-memory buffer. The Dart
/// side later drains the buffer through the `drain` method. The append is cheap
/// enough to finish inside the wake window, where thawing the whole Flutter
/// engine to run the Dart handler is not — that's the whole reason this lives in
/// Swift and not in Dart.
///
/// The buffer is in-memory, so it survives *suspension* (the process is frozen
/// but resident) but not *termination*. The restore identifier lets iOS relaunch
/// us into the central after a BLE event if the app was killed; a future step
/// could also append to a flat file for termination durability.
final class HrBackgroundCentral: NSObject {
  static let shared = HrBackgroundCentral()

  private static let channelName = "cardiorounds/hr_central"
  private static let restoreId = "cardiorounds.hr.central"
  private static let hrService = CBUUID(string: "180D")
  private static let hrMeasurement = CBUUID(string: "2A37")

  // Standard HR notify characteristic is live-only, so a sample older than this
  // is not worth waiting on; used only to throttle reconnect log spam.
  private let queue = DispatchQueue(label: "cardiorounds.hr.central")

  private var central: CBCentralManager?
  private var channel: FlutterMethodChannel?

  // Guards the buffers, which are written from the CoreBluetooth `queue` and
  // read from the platform-channel thread during `drain`.
  private let lock = NSLock()
  private var sampleBuffer: [[String: Any]] = []
  private var eventBuffer: [[String: Any]] = []

  private var peripheral: CBPeripheral?
  private var targetId: UUID?
  private var desiredName: String?
  // True between `start` and `stop`; drives auto-reconnect on disconnect.
  private var recording = false
  // Deferred until the central reaches `.poweredOn`.
  private var pendingStart: (() -> Void)?

  // Diagnostics: counts samples so we can emit a heartbeat to the log roughly
  // once a minute from inside the BLE callback (a Timer wouldn't fire while
  // suspended). See NativeAppLog for why this is the proof of background life.
  private var samplesSinceHeartbeat = 0
  private var samplesTotal = 0
  private static let heartbeatEvery = 60

  // MARK: - Wiring

  /// Called once at launch. Creating the central here (with the restore key)
  /// is what makes `willRestoreState:` eligible to fire after a relaunch.
  func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    self.channel = channel

    central = CBCentralManager(
      delegate: self,
      queue: queue,
      options: [CBCentralManagerOptionRestoreIdentifierKey: Self.restoreId]
    )
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "start":
      guard let remoteId = args?["remoteId"] as? String, let uuid = UUID(uuidString: remoteId) else {
        result(FlutterError(code: "bad_args", message: "Missing remoteId", details: nil))
        return
      }
      start(uuid: uuid, name: args?["name"] as? String, result: result)
    case "drain":
      result(drain())
    case "stop":
      stop()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Lifecycle

  private func start(uuid: UUID, name: String?, result: @escaping FlutterResult) {
    queue.async {
      self.targetId = uuid
      self.desiredName = name
      self.recording = true
      self.samplesTotal = 0
      self.samplesSinceHeartbeat = 0
      self.clearBuffers()
      NativeAppLog.log("BTNative", "start for \(name ?? uuid.uuidString)")

      let connect = { [weak self] in
        guard let self, let central = self.central else { return }
        if let known = central.retrievePeripherals(withIdentifiers: [uuid]).first {
          self.connect(known)
        } else {
          // Not cached by the system — scan for the HR service and match by id.
          central.scanForPeripherals(withServices: [Self.hrService])
        }
      }

      if self.central?.state == .poweredOn {
        connect()
      } else {
        // Bluetooth not ready yet; run once `centralManagerDidUpdateState` fires.
        self.pendingStart = connect
      }
      // Resolve immediately. Samples arrive asynchronously via `drain`; the Dart
      // side shows "Connecting…" until the first one lands, mirroring the old
      // flutter_blue_plus source's behavior.
      result(name)
    }
  }

  private func connect(_ peripheral: CBPeripheral) {
    self.peripheral = peripheral
    peripheral.delegate = self
    central?.stopScan()
    central?.connect(peripheral, options: nil)
  }

  private func stop() {
    queue.async {
      NativeAppLog.log("BTNative", "stop after \(self.samplesTotal) samples total")
      self.recording = false
      self.pendingStart = nil
      self.central?.stopScan()
      if let peripheral = self.peripheral {
        self.central?.cancelPeripheralConnection(peripheral)
      }
      self.peripheral = nil
      self.targetId = nil
    }
  }

  // MARK: - Buffer

  private func appendSample(bpm: Int?) {
    let entry: [String: Any] = ["tMs": nowMs(), "bpm": bpm ?? NSNull()]
    lock.lock()
    sampleBuffer.append(entry)
    let buffered = sampleBuffer.count
    lock.unlock()

    samplesTotal += 1
    samplesSinceHeartbeat += 1
    // Heartbeat from inside the BLE callback: if these lines keep appearing in
    // the log while the Dart `[Recording]` lines are silent, native ran while
    // the app was suspended. `buffered` shows how much is waiting for Dart to
    // drain — a large value after a quiet stretch is the backlog being recovered.
    if samplesSinceHeartbeat >= Self.heartbeatEvery {
      NativeAppLog.log(
        "BTNative",
        "alive: \(samplesTotal) samples total, \(buffered) buffered awaiting drain"
      )
      samplesSinceHeartbeat = 0
    }
  }

  private func appendEvent(_ kind: String, _ message: String?) {
    let entry: [String: Any] = ["tMs": nowMs(), "kind": kind, "message": message ?? NSNull()]
    lock.lock()
    eventBuffer.append(entry)
    lock.unlock()
  }

  private func clearBuffers() {
    lock.lock()
    sampleBuffer.removeAll()
    eventBuffer.removeAll()
    lock.unlock()
  }

  /// Returns everything accumulated since the previous drain and clears the
  /// buffers. After a suspension this returns the whole backlog in one call.
  private func drain() -> [String: Any] {
    lock.lock()
    let samples = sampleBuffer
    let events = eventBuffer
    sampleBuffer.removeAll()
    eventBuffer.removeAll()
    lock.unlock()
    return ["samples": samples, "events": events]
  }

  private func nowMs() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }

  /// Parses a Heart Rate Measurement (0x2A37) value. Mirrors the Dart
  /// `parseHeartRateMeasurement`: uint8 or uint16 by the flags bit, and 0 is
  /// treated as null (some straps emit 0 on contact loss).
  private func parseHeartRate(_ data: Data) -> Int? {
    guard data.count >= 2 else { return nil }
    let flags = data[0]
    let isUInt16 = (flags & 0x01) != 0
    let bpm: Int
    if isUInt16 {
      guard data.count >= 3 else { return nil }
      bpm = Int(data[1]) | (Int(data[2]) << 8)
    } else {
      bpm = Int(data[1])
    }
    return bpm <= 0 ? nil : bpm
  }
}

// MARK: - CBCentralManagerDelegate

extension HrBackgroundCentral: CBCentralManagerDelegate {
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    guard central.state == .poweredOn else { return }
    if let pending = pendingStart {
      pendingStart = nil
      pending()
    }
  }

  func centralManager(
    _ central: CBCentralManager,
    didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any],
    rssi RSSI: NSNumber
  ) {
    // Reached only on the scan fallback when the peripheral wasn't cached.
    guard let targetId, peripheral.identifier == targetId else { return }
    connect(peripheral)
  }

  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    peripheral.discoverServices([Self.hrService])
  }

  func centralManager(
    _ central: CBCentralManager,
    didDisconnectPeripheral peripheral: CBPeripheral,
    error: Error?
  ) {
    appendSample(bpm: nil) // signal-loss marker for the Dart pipeline
    appendEvent("disconnected", error?.localizedDescription ?? "disconnected")
    NativeAppLog.log("BTNative", "disconnected: \(error?.localizedDescription ?? "no error")")
    // Keep trying as long as the recording is live. iOS completes this connect
    // request whenever the strap is back in range — including from a background
    // wake — which is exactly the durability we want.
    if recording {
      appendEvent("reconnecting", nil)
      central.connect(peripheral, options: nil)
    }
  }

  func centralManager(
    _ central: CBCentralManager,
    didFailToConnect peripheral: CBPeripheral,
    error: Error?
  ) {
    appendEvent("disconnected", error?.localizedDescription ?? "connect failed")
    if recording {
      central.connect(peripheral, options: nil)
    }
  }

  /// iOS relaunched us (e.g. after termination) due to a BLE event and is
  /// handing back the peripheral it had. Re-adopt it so notifications resume.
  func centralManager(
    _ central: CBCentralManager,
    willRestoreState dict: [String: Any]
  ) {
    let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral]
    guard let restored = peripherals?.first else { return }
    recording = true
    targetId = restored.identifier
    peripheral = restored
    restored.delegate = self
    appendEvent("reconnecting", "restored")
    NativeAppLog.log("BTNative", "willRestoreState: relaunched into central by iOS")
  }
}

// MARK: - CBPeripheralDelegate

extension HrBackgroundCentral: CBPeripheralDelegate {
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    guard let service = peripheral.services?.first(where: { $0.uuid == Self.hrService }) else {
      appendEvent("disconnected", "no heart-rate service")
      return
    }
    peripheral.discoverCharacteristics([Self.hrMeasurement], for: service)
  }

  func peripheral(
    _ peripheral: CBPeripheral,
    didDiscoverCharacteristicsFor service: CBService,
    error: Error?
  ) {
    guard let char = service.characteristics?.first(where: { $0.uuid == Self.hrMeasurement }) else {
      appendEvent("disconnected", "no heart-rate characteristic")
      return
    }
    peripheral.setNotifyValue(true, for: char)
    appendEvent("connected", nil)
    NativeAppLog.log("BTNative", "notifications enabled - ready")
  }

  func peripheral(
    _ peripheral: CBPeripheral,
    didUpdateValueFor characteristic: CBCharacteristic,
    error: Error?
  ) {
    guard characteristic.uuid == Self.hrMeasurement, let data = characteristic.value else { return }
    appendSample(bpm: parseHeartRate(data))
  }
}
