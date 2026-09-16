import AppIntents
import Foundation
import WidgetKit

let busControlAppGroup = "group.com.example.busControlPro.shared"

@available(iOS 17.0, *)
struct ToggleTripIntent: AppIntent {
    static var title: LocalizedStringResource = "Отметить рейс"
    static var description = IntentDescription("Отмечает утренний или вечерний рейс в BusControl PRO.")

    @Parameter(title: "Тип рейса")
    var kind: String

    init() {}

    init(kind: String) {
        self.kind = kind
    }

    func perform() async throws -> some IntentResult {
        let sharedDefaults = UserDefaults(suiteName: busControlAppGroup)
        let appDefaults = UserDefaults.standard

        let today = Self.dateKey(Date())
        if sharedDefaults?.string(forKey: "snapshot_date") != today {
            sharedDefaults?.set(today, forKey: "snapshot_date")
            sharedDefaults?.set(false, forKey: "morning_done")
            sharedDefaults?.set(false, forKey: "evening_done")
        }

        let isMorning = kind == "morning"
        let stateKey = isMorning ? "morning_done" : "evening_done"
        let pendingKey = isMorning ? "pending_morning_state" : "pending_evening_state"
        let counterKey = isMorning
            ? "widget_pending_morning_toggle_count"
            : "widget_pending_evening_toggle_count"
        let nextValue = !(sharedDefaults?.bool(forKey: stateKey) ?? false)

        // Keep the widget UI responsive through the App Group when the signing
        // environment supports it. SideStore can currently break App Group
        // sharing between the host app and its widget extension, so the host
        // app also receives an idempotent toggle counter through its own
        // UserDefaults. ForegroundContinuableIntent makes WidgetKit execute
        // perform() in the application process without forcing the UI open.
        sharedDefaults?.set(nextValue, forKey: stateKey)
        sharedDefaults?.set(nextValue, forKey: pendingKey)

        appDefaults.set(appDefaults.integer(forKey: counterKey) + 1, forKey: counterKey)

        WidgetCenter.shared.reloadTimelines(ofKind: "BusControlHomeWidget")

        return .result()
    }

    private static func dateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// The same intent source is compiled into both Runner and the WidgetKit
// extension. ForegroundContinuableIntent must only be visible to the host
// application; otherwise Xcode rejects it for an application extension.
// This keeps widget taps executing in the BusControl app process without
// forcing the UI to open, while the widget target still compiles normally.
@available(iOS 17.0, *)
@available(iOSApplicationExtension, unavailable)
extension ToggleTripIntent: ForegroundContinuableIntent {}
