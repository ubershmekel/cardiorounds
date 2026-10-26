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
    // First line of a launch's timeline. `state: background` means iOS woke us
    // without the user (e.g. a BLE restore), so no Flutter frame is expected.
    let launchKeys = (launchOptions?.keys.map { $0.rawValue } ?? []).sorted()
    NativeAppLog.log(
      "AppNative",
      "didFinishLaunching state: \(describe(application.applicationState)) "
        + "options: \(launchKeys)",
      sync: true
    )
    observeLifecycleForDiagnostics()
    // Channels are registered only in `didInitializeImplicitFlutterEngine`.
    // Do NOT register through `self` here: with scenes there is no root
    // FlutterViewController yet, so FlutterAppDelegate.registrar(forPlugin:)
    // falls back to its launch engine, which creates *and runs* the engine on
    // the spot. Dart `main()` then starts before GeneratedPluginRegistrant has
    // run — every plugin call races registration (the intermittent
    // MissingPluginException), and on a background launch, where no scene
    // connects, it always loses: main() throws before runApp, and when the
    // user later opens that same process the view adopts a Dart isolate that
    // will never draw — stuck on the splash screen.
    //
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
    NativeAppLog.log("AppNative", "implicit engine initialized; registering plugins", sync: true)
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerLiveActivityChannel(pluginRegistry: engineBridge.pluginRegistry)
    registerHrCentral(pluginRegistry: engineBridge.pluginRegistry)
    NativeAppLog.log("AppNative", "plugins registered", sync: true)
  }

  /// Logs scene/app lifecycle transitions, so a launch that never reaches its
  /// first frame still shows how far it got (scene connected? foregrounded?).
  /// Uses notifications rather than SceneDelegate overrides so FlutterSceneDelegate
  /// behaviour is untouched.
  private func observeLifecycleForDiagnostics() {
    let events: [(Notification.Name, String)] = [
      (UIScene.willConnectNotification, "scene will connect"),
      (UIScene.willEnterForegroundNotification, "scene will enter foreground"),
      (UIScene.didActivateNotification, "scene did activate"),
      (UIScene.didEnterBackgroundNotification, "scene did enter background"),
      (UIScene.didDisconnectNotification, "scene did disconnect"),
      (UIApplication.willTerminateNotification, "app will terminate"),
    ]
    for (name, label) in events {
      NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
        NativeAppLog.log("AppNative", label, sync: true)
      }
    }
  }

  private func describe(_ state: UIApplication.State) -> String {
    switch state {
    case .active: return "active"
    case .inactive: return "inactive"
    case .background: return "background"
    @unknown default: return "unknown(\(state.rawValue))"
    }
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
