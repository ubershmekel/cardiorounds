import CoreBluetooth
import Flutter
import Foundation

/// A CoreBluetooth central that owns the recording-time connections to one or
/// more heart-rate straps and buffers their samples natively, per device.
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
/// One central, many peripherals: iOS only grants one `CBCentralManager`, but a
/// session can record several straps at once. Everything downstream of the
/// central is therefore keyed by `CBPeripheral.identifier` (the device UUID):
/// separate buffers, separate reconnect, separate start/stop. Samples from two
/// straps are never merged into one stream — see
/// `docs/design/multi-device-recording.md`.
///
/// The buffers are in-memory, so they survive *suspension* (the process is
/// frozen but resident) but not *termination*. The restore identifier lets iOS
/// relaunch us into the central after a BLE event if the app was killed; a
/// future step could also append to a flat file for termination durability.
final class HrBackgroundCentral: NSObject {
  static let shared = HrBackgroundCentral()

  private static let channelName = "cardiorounds/hr_central"
  private static let restoreId = "cardiorounds.hr.central"
  private static let hrService = CBUUID(string: "180D")
  private static let hrMeasurement = CBUUID(string: "2A37")

  private let queue = DispatchQueue(label: "cardiorounds.hr.central")

  private var central: CBCentralManager?
  // Guards lazy creation of `central` in `ensureCentral`, which can be hit from
  // the platform-channel thread (first scan) and from the main thread (a BLE
  // restore relaunch) at roughly the same time.
  private let centralLock = NSLock()
  private var channel: FlutterMethodChannel?

  // Guards the buffers, which are written from the CoreBluetooth `queue` and
  // read from the platform-channel thread during `drain` / `scanDrain`.
  private let lock = NSLock()
  // Per-device sample/event buffers, keyed by peripheral UUID. Two straps never
  // share a buffer, so their samples can't cross-feed into each other's stream.
  private var sampleBuffers: [UUID: [[String: Any]]] = [:]
  private var eventBuffers: [UUID: [[String: Any]]] = [:]
  // Keyed by UUID so repeated discoveries just update RSSI; never cleared until
  // scanStop so the Dart side always sees the full accumulated list.
  private var scanDevices: [UUID: [String: Any]] = [:]

  // Peripherals we've adopted (connecting, connected, or reconnecting), keyed by
  // UUID. A device is in here from `connect` until its `stop`.
  private var peripherals: [UUID: CBPeripheral] = [:]
  // Devices the session wants recorded. Drives auto-reconnect and keeps the
  // shared scan alive until every target is adopted. A device leaves on `stop`.
  private var targets: Set<UUID> = []
  // True between `scanStart` and `scanStop`; fills scanDevices in didDiscover.
  private var discoveryScanning = false
  // Actions deferred until the central reaches `.poweredOn`. A list (not a
  // single closure) so concurrent starts/scans don't clobber each other.
  private var pendingActions: [() -> Void] = []

  // Diagnostics: counts samples so we can emit a heartbeat to the log roughly
  // once a minute from inside the BLE callback (a Timer wouldn't fire while
  // suspended). See NativeAppLog for why this is the proof of background life.
  private var samplesSinceHeartbeat = 0
  private var samplesTotal = 0
  private static let heartbeatEvery = 60

  // MARK: - Wiring

  /// Called once at launch. Only wires up the method channel — the
  /// `CBCentralManager` is created lazily by `ensureCentral` on the first scan
  /// or connect, so the iOS Bluetooth permission prompt appears when the user
  /// reaches the record screen rather than at launch. The one exception is a
  /// BLE restore relaunch, where AppDelegate calls `ensureCentral` eagerly so
  /// `willRestoreState:` can fire (permission is already granted in that case).
  func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    self.channel = channel
  }

  /// Idempotently creates the central with the restore key. Creating a
  /// `CBCentralManager` is the call that triggers the iOS permission prompt, so
  /// the timing of the *first* call here is the timing of the prompt.
  func ensureCentral() {
    centralLock.lock()
    defer { centralLock.unlock() }
    guard central == nil else { return }
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
      guard let remoteId = args?["remoteId"] as? String, let uuid = UUID(uuidString: remoteId) else {
        result(FlutterError(code: "bad_args", message: "Missing remoteId", details: nil))
        return
      }
      result(drain(for: uuid))
    case "stop":
      guard let remoteId = args?["remoteId"] as? String, let uuid = UUID(uuidString: remoteId) else {
        result(FlutterError(code: "bad_args", message: "Missing remoteId", details: nil))
        return
      }
      stop(uuid: uuid)
      result(nil)
    case "scanStart":
      scanStart(result: result)
    case "scanStop":
      scanStop()
      result(nil)
    case "scanDrain":
      result(scanDrain())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Lifecycle

  private func start(uuid: UUID, name: String?, result: @escaping FlutterResult) {
    queue.async {
      self.ensureCentral()
      // Reset the diagnostic counters only when starting the first device of a
      // session; a second `start` must not zero the running total.
      if self.targets.isEmpty {
        self.samplesTotal = 0
        self.samplesSinceHeartbeat = 0
      }
      self.targets.insert(uuid)
      self.clearBuffers(for: uuid)
      NativeAppLog.log("BTNative", "start for \(name ?? uuid.uuidString)")

      let connect = { [weak self] in
        guard let self, let central = self.central else { return }
        // Re-check intent: a deferred start (Bluetooth was off) may run after the
        // device was already stopped, in which case it's no longer a target.
        guard self.targets.contains(uuid) else { return }
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
        self.pendingActions.append(connect)
      }
      // Resolve immediately. Samples arrive asynchronously via `drain`; the Dart
      // side shows "Connecting…" until the first one lands, mirroring the old
      // flutter_blue_plus source's behavior.
      result(name)
    }
  }

  private func connect(_ peripheral: CBPeripheral) {
    peripherals[peripheral.identifier] = peripheral
    peripheral.delegate = self
    central?.connect(peripheral, options: nil)
    maybeStopScan()
  }

  private func stop(uuid: UUID) {
    queue.async {
      NativeAppLog.log("BTNative", "stop \(uuid.uuidString) after \(self.samplesTotal) samples total")
      self.targets.remove(uuid)
      if let peripheral = self.peripherals[uuid] {
        self.central?.cancelPeripheralConnection(peripheral)
        self.peripherals[uuid] = nil
      }
      // Leave this device's buffers: the Dart side does a final `drain` before
      // `stop`, so they're already empty; clearing here would be a no-op race.
      self.maybeStopScan()
    }
  }

  // MARK: - Discovery scan

  private func scanStart(result: @escaping FlutterResult) {
    queue.async {
      self.ensureCentral()
      guard let central = self.central else {
        result(FlutterError(code: "not_ready", message: "Central not initialised", details: nil))
        return
      }
      NativeAppLog.log("BTNative", "scanStart")
      self.lock.lock()
      self.scanDevices.removeAll()
      self.lock.unlock()
      self.discoveryScanning = true
      let startScan = { [weak self] in
        guard let self else { return }
        // Re-check intent: a deferred scan (Bluetooth was off) may run after
        // scanStop cleared discoveryScanning; don't start a stray scan then.
        guard self.discoveryScanning else { return }
        central.scanForPeripherals(withServices: [Self.hrService])
      }
      if central.state == .poweredOn {
        startScan()
      } else {
        self.pendingActions.append(startScan)
      }
      result(nil)
    }
  }

  private func scanStop() {
    queue.async {
      NativeAppLog.log("BTNative", "scanStop")
      self.discoveryScanning = false
      self.maybeStopScan()
      self.lock.lock()
      self.scanDevices.removeAll()
      self.lock.unlock()
    }
  }

  /// Stops the shared hardware scan only when nothing still needs it: no
  /// discovery scan is running and every recording target has been adopted
  /// (connecting or connected). The connect-fallback scan and the discovery
  /// scan share one `scanForPeripherals`, so this is the single owner of when it
  /// ends. Must be called on `queue`.
  private func maybeStopScan() {
    guard !discoveryScanning else { return }
    let allTargetsAdopted = targets.isSubset(of: Set(peripherals.keys))
    if allTargetsAdopted {
      central?.stopScan()
    }
  }

  /// Returns all peripherals discovered since the last `scanStart`, sorted by
  /// most-recently-updated. Does not clear — the list accumulates until
  /// `scanStop` so the Dart side always sees the full picture between polls.
  private func scanDrain() -> [[String: Any]] {
    lock.lock()
    let result = Array(scanDevices.values)
    lock.unlock()
    return result
  }

  private func appendScannedDevice(_ peripheral: CBPeripheral, rssi: Int) {
    let entry: [String: Any] = [
      "id": peripheral.identifier.uuidString,
      "name": peripheral.name ?? "",
      "rssi": rssi,
    ]
    lock.lock()
    scanDevices[peripheral.identifier] = entry
    lock.unlock()
  }

  // MARK: - Buffer

  private func appendSample(bpm: Int?, for id: UUID) {
    let entry: [String: Any] = ["tMs": nowMs(), "bpm": bpm ?? NSNull()]
    lock.lock()
    sampleBuffers[id, default: []].append(entry)
    let buffered = sampleBuffers[id]?.count ?? 0
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

  private func appendEvent(_ kind: String, _ message: String?, for id: UUID) {
    let entry: [String: Any] = ["tMs": nowMs(), "kind": kind, "message": message ?? NSNull()]
    lock.lock()
    eventBuffers[id, default: []].append(entry)
    lock.unlock()
  }

  private func clearBuffers(for id: UUID) {
    lock.lock()
    sampleBuffers[id] = []
    eventBuffers[id] = []
    lock.unlock()
  }

  /// Returns everything accumulated for one device since the previous drain and
  /// clears its buffers. After a suspension this returns the whole backlog in one
  /// call. Only this device's samples are returned — never another strap's.
  private func drain(for id: UUID) -> [String: Any] {
    lock.lock()
    let samples = sampleBuffers[id] ?? []
    let events = eventBuffers[id] ?? []
    sampleBuffers[id] = []
    eventBuffers[id] = []
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
    let pending = pendingActions
    pendingActions.removeAll()
    for action in pending {
      action()
    }
  }

  func centralManager(
    _ central: CBCentralManager,
    didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any],
    rssi RSSI: NSNumber
  ) {
    if discoveryScanning {
      appendScannedDevice(peripheral, rssi: RSSI.intValue)
    }
    // Connect-fallback: we're hunting for specific target devices by UUID. Only
    // adopt one we haven't already (another target may still need the scan).
    let id = peripheral.identifier
    if targets.contains(id), peripherals[id] == nil {
      connect(peripheral)
    }
  }

  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    peripheral.discoverServices([Self.hrService])
  }

  func centralManager(
    _ central: CBCentralManager,
    didDisconnectPeripheral peripheral: CBPeripheral,
    error: Error?
  ) {
    let id = peripheral.identifier
    appendSample(bpm: nil, for: id) // signal-loss marker for the Dart pipeline
    appendEvent("disconnected", error?.localizedDescription ?? "disconnected", for: id)
    NativeAppLog.log("BTNative", "disconnected \(id.uuidString): \(error?.localizedDescription ?? "no error")")
    // Keep trying as long as this device is still a wanted target. iOS completes
    // the connect request whenever the strap is back in range — including from a
    // background wake — which is exactly the durability we want. A device removed
    // via `stop` is no longer a target, so it won't auto-reconnect.
    if targets.contains(id) {
      appendEvent("reconnecting", nil, for: id)
      central.connect(peripheral, options: nil)
    }
  }

  func centralManager(
    _ central: CBCentralManager,
    didFailToConnect peripheral: CBPeripheral,
    error: Error?
  ) {
    let id = peripheral.identifier
    appendEvent("disconnected", error?.localizedDescription ?? "connect failed", for: id)
    if targets.contains(id) {
      central.connect(peripheral, options: nil)
    }
  }

  /// iOS relaunched us (e.g. after termination) due to a BLE event and is
  /// handing back the peripherals it had. Re-adopt every one so notifications
  /// resume for the whole session, not just one strap.
  func centralManager(
    _ central: CBCentralManager,
    willRestoreState dict: [String: Any]
  ) {
    let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] ?? []
    guard !peripherals.isEmpty else { return }
    for restored in peripherals {
      let id = restored.identifier
      targets.insert(id)
      self.peripherals[id] = restored
      restored.delegate = self
      appendEvent("reconnecting", "restored", for: id)
    }
    NativeAppLog.log("BTNative", "willRestoreState: relaunched into central with \(peripherals.count) peripheral(s)")
  }
}

// MARK: - CBPeripheralDelegate

extension HrBackgroundCentral: CBPeripheralDelegate {
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    guard let service = peripheral.services?.first(where: { $0.uuid == Self.hrService }) else {
      appendEvent("disconnected", "no heart-rate service", for: peripheral.identifier)
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
      appendEvent("disconnected", "no heart-rate characteristic", for: peripheral.identifier)
      return
    }
    peripheral.setNotifyValue(true, for: char)
    appendEvent("connected", nil, for: peripheral.identifier)
    NativeAppLog.log("BTNative", "notifications enabled for \(peripheral.identifier.uuidString) - ready")
  }

  func peripheral(
    _ peripheral: CBPeripheral,
    didUpdateValueFor characteristic: CBCharacteristic,
    error: Error?
  ) {
    guard characteristic.uuid == Self.hrMeasurement, let data = characteristic.value else { return }
    // Route strictly by which peripheral notified: this is what keeps two
    // straps' samples in separate buffers instead of merged into one stream.
    appendSample(bpm: parseHeartRate(data), for: peripheral.identifier)
  }
}
