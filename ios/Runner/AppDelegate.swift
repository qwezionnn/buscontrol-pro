import ActivityKit
import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  static let widgetAppGroup = "group.com.example.busControlPro.shared"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    Self.storeQuickAction(from: url)
    return super.application(app, open: url, options: options)
  }

  static func storeQuickAction(from url: URL) {
    guard url.scheme?.lowercased() == "buscontrol" else { return }
    let action = (url.host ?? url.path.replacingOccurrences(of: "/", with: "")).lowercased()
    let supportedActions: Set<String> = ["trips", "mileage", "order", "fuel", "calendar"]
    guard supportedActions.contains(action) else { return }
    UserDefaults.standard.set(action, forKey: "quick_action")
    UserDefaults(suiteName: widgetAppGroup)?.set(action, forKey: "quick_action")
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BusControlNativeBridge") else { return }

    let liveChannel = FlutterMethodChannel(
      name: "buscontrol/live_activity",
      binaryMessenger: registrar.messenger()
    )

    liveChannel.setMethodCallHandler { call, result in
      guard #available(iOS 16.1, *) else {
        result(FlutterError(code: "unsupported", message: "Live Activity requires iOS 16.1+", details: nil))
        return
      }

      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "bad_args", message: "Missing arguments", details: nil))
        return
      }

      let rawEventId = args["eventId"] ?? args["orderId"]
      let eventId: Int?
      if let number = rawEventId as? NSNumber {
        eventId = number.intValue
      } else {
        eventId = rawEventId as? Int
      }

      guard let eventId else {
        result(FlutterError(code: "bad_args", message: "Missing eventId", details: nil))
        return
      }

      if call.method == "end" {
        Task {
          await LiveActivityManager.shared.end(eventId: eventId)
          result(nil)
        }
        return
      }

      guard (call.method == "start" || call.method == "schedule"),
            let title = args["title"] as? String,
            let time = args["time"] as? String,
            let timestampMs = args["orderTimestampMs"] as? NSNumber else {
        result(FlutterMethodNotImplemented)
        return
      }

      let note = args["note"] as? String ?? ""
      let kind = args["kind"] as? String ?? "order"
      let replaceExisting = args["replaceExisting"] as? Bool ?? true
      let eventDate = Date(timeIntervalSince1970: timestampMs.doubleValue / 1000.0)
      let startTimestampMs = args["startTimestampMs"] as? NSNumber
      let startDate = startTimestampMs.map {
        Date(timeIntervalSince1970: $0.doubleValue / 1000.0)
      }

      Task {
        do {
          if call.method == "schedule", let startDate {
            try await LiveActivityManager.shared.schedule(
              eventId: eventId,
              kind: kind,
              title: title,
              time: time,
              note: note,
              eventDate: eventDate,
              startDate: startDate,
              replaceExisting: replaceExisting
            )
          } else {
            try await LiveActivityManager.shared.start(
              eventId: eventId,
              kind: kind,
              title: title,
              time: time,
              note: note,
              eventDate: eventDate,
              replaceExisting: replaceExisting
            )
          }
          result(nil)
        } catch {
          NSLog("BusControl Live Activity error: id=%d kind=%@ error=%@", eventId, kind, error.localizedDescription)
          result(FlutterError(code: "live_activity", message: error.localizedDescription, details: nil))
        }
      }
    }

    let widgetChannel = FlutterMethodChannel(
      name: "buscontrol/widget",
      binaryMessenger: registrar.messenger()
    )

    widgetChannel.setMethodCallHandler { call, result in
      let defaults = UserDefaults(suiteName: Self.widgetAppGroup)

      switch call.method {
      case "consumePendingTripActions":
        var response: [String: Any] = [:]
        let appDefaults = UserDefaults.standard

        // New idempotent bridge: the widget stores the exact desired state.
        // If WidgetKit invokes the intent more than once, duplicate executions
        // still resolve to the same final value instead of toggling back.
        if let value = appDefaults.object(forKey: "widget_pending_morning_state_app") as? NSNumber {
          response["morning"] = value.boolValue
          // Keep the shared pending value until Flutter has committed the
          // state to SQLite and updateSnapshot confirms it. The widget provider
          // uses this value during the short transition, preventing the
          // optimistic toggle from snapping back to the old timeline entry.
          appDefaults.removeObject(forKey: "widget_pending_morning_state_app")
        } else if let value = defaults?.object(forKey: "pending_morning_state") as? NSNumber {
          response["morning"] = value.boolValue
          // Do not clear pending here; updateSnapshot clears it only after the
          // real database state matches the requested widget state.
        }

        if let value = appDefaults.object(forKey: "widget_pending_evening_state_app") as? NSNumber {
          response["evening"] = value.boolValue
          appDefaults.removeObject(forKey: "widget_pending_evening_state_app")
        } else if let value = defaults?.object(forKey: "pending_evening_state") as? NSNumber {
          response["evening"] = value.boolValue
        }

        // Clear legacy counter keys from previous builds so an old pending value
        // can never flip the state again after this update.
        appDefaults.removeObject(forKey: "widget_pending_morning_toggle_count")
        appDefaults.removeObject(forKey: "widget_pending_evening_toggle_count")

        result(response)

      case "updateSnapshot":
        guard let args = call.arguments as? [String: Any],
              let date = args["date"] as? String,
              let morningDone = args["morningDone"] as? Bool,
              let eveningDone = args["eveningDone"] as? Bool else {
          result(FlutterError(code: "bad_args", message: "Missing widget snapshot fields", details: nil))
          return
        }
        // Commit the authoritative app/database snapshot first.
        defaults?.set(date, forKey: "snapshot_date")
        defaults?.set(morningDone, forKey: "morning_done")
        defaults?.set(eveningDone, forKey: "evening_done")

        // A widget interaction is two-phase: the intent writes a pending target
        // immediately, then Flutter commits it to SQLite. Only clear pending
        // after this snapshot confirms the exact requested value. This prevents
        // WidgetKit's automatic timeline reload from restoring stale state.
        if let pending = defaults?.object(forKey: "pending_morning_state") as? NSNumber,
           pending.boolValue == morningDone {
          defaults?.removeObject(forKey: "pending_morning_state")
        }
        if let pending = defaults?.object(forKey: "pending_evening_state") as? NSNumber,
           pending.boolValue == eveningDone {
          defaults?.removeObject(forKey: "pending_evening_state")
        }
        defaults?.synchronize()

        if #available(iOS 14.0, *) {
          WidgetCenter.shared.reloadTimelines(ofKind: "BusControlHomeWidget")
        }
        result(nil)

      case "consumeQuickAction":
        let appDefaults = UserDefaults.standard
        let action = appDefaults.string(forKey: "quick_action")
          ?? defaults?.string(forKey: "quick_action")
        appDefaults.removeObject(forKey: "quick_action")
        defaults?.removeObject(forKey: "quick_action")
        result(action)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
