import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let liveActivityChannelName = "cardiorounds/live_activity"
  private var didRegisterLiveActivityChannel = false
  private var didRegisterHrCentral = false

  @available(iOS 16.1, *)
  private var liveActivityController: LiveActivityController {
    LiveActivityController()
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    registerLiveActivityChannel(pluginRegistry: self)
    registerHrCentral(pluginRegistry: self)
    // The central is otherwise created lazily on the first scan (so the
    // Bluetooth permission prompt lands on the record screen, not at launch).
    // But when iOS relaunches us specifically to restore a BLE session, the
    // central must exist now for `willRestoreState:` to fire.
    if launchOptions?[.bluetoothCentrals] != nil {
      HrBackgroundCentral.shared.ensureCentral()
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerLiveActivityChannel(pluginRegistry: engineBridge.pluginRegistry)
    registerHrCentral(pluginRegistry: engineBridge.pluginRegistry)
  }

  private func registerHrCentral(pluginRegistry: FlutterPluginRegistry) {
    guard !didRegisterHrCentral else {
      return
    }
    guard let registrar = pluginRegistry.registrar(forPlugin: "HrBackgroundCentral") else {
      return
    }
    didRegisterHrCentral = true
    HrBackgroundCentral.shared.register(with: registrar)
  }

  private func registerLiveActivityChannel(pluginRegistry: FlutterPluginRegistry) {
    guard !didRegisterLiveActivityChannel else {
      return
    }
    guard let registrar = pluginRegistry.registrar(forPlugin: "LiveActivityBridge") else {
      return
    }
    didRegisterLiveActivityChannel = true
    let channel = FlutterMethodChannel(
      name: liveActivityChannelName,
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      if #available(iOS 16.1, *) {
        self.liveActivityController.handle(
          method: call.method,
          arguments: call.arguments,
          result: result
        )
      } else {
        result(nil)
      }
    }
  }
}
