import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let liveActivityChannelName = "cardiorounds/live_activity"
  private var didRegisterLiveActivityChannel = false

  @available(iOS 16.1, *)
  private var liveActivityController: LiveActivityController {
    LiveActivityController()
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    registerLiveActivityChannel(pluginRegistry: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerLiveActivityChannel(pluginRegistry: engineBridge.pluginRegistry)
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
