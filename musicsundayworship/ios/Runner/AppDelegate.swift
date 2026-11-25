import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "KeepAwakePlugin") {
      let channel = FlutterMethodChannel(
        name: "com.musicsundayworship/keep_awake",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { (call, result) in
        DispatchQueue.main.async {
          if call.method == "enable" {
            UIApplication.shared.isIdleTimerDisabled = true
            result(true)
          } else if call.method == "disable" {
            UIApplication.shared.isIdleTimerDisabled = false
            result(false)
          } else {
            result(FlutterMethodNotImplemented)
          }
        }
      }
    }
  }
}
