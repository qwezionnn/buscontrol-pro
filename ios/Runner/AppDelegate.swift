import ActivityKit
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

    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BusControlLiveActivity") else { return }
    let channel = FlutterMethodChannel(
      name: "buscontrol/live_activity",
      binaryMessenger: registrar.messenger()
    )

    channel.setMethodCallHandler { call, result in
      guard #available(iOS 16.1, *) else {
        result(FlutterError(code: "unsupported", message: "Live Activity requires iOS 16.1+", details: nil))
        return
      }

      guard let args = call.arguments as? [String: Any],
            let orderId = args["orderId"] as? Int else {
        result(FlutterError(code: "bad_args", message: "Missing orderId", details: nil))
        return
      }

      if call.method == "end" {
        Task {
          await LiveActivityManager.shared.end(orderId: orderId)
          result(nil)
        }
        return
      }

      guard call.method == "start",
            let title = args["title"] as? String,
            let time = args["time"] as? String,
            let note = args["note"] as? String,
            let timestampMs = args["orderTimestampMs"] as? NSNumber else {
        result(FlutterMethodNotImplemented)
        return
      }

      let orderDate = Date(timeIntervalSince1970: timestampMs.doubleValue / 1000.0)
      Task {
        do {
          try await LiveActivityManager.shared.start(
            orderId: orderId,
            title: title,
            time: time,
            note: note,
            orderDate: orderDate
          )
          result(nil)
        } catch {
          result(FlutterError(code: "live_activity", message: error.localizedDescription, details: nil))
        }
      }
    }
  }
}
