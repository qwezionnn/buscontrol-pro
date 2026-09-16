import AppIntents
import Foundation
import WidgetKit

let busControlAppGroup = "group.com.example.busControlPro.shared"

@available(iOS 17.0, *)
struct ToggleTripIntent: AppIntent {
    static var title: LocalizedStringResource = "Отметить рейс"
    static var description = IntentDescription("Отмечает утренний или вечерний рейс в BusControl PRO.")

    // iOS 26 replacement for ForegroundContinuableIntent.
    // This lets the intent start in the BusControl app process in the
    // background without forcing the app UI to open. Keeping it gated to
    // iOS 26 preserves the project's iOS 15 deployment target.
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes {
        [.background, .foreground(.dynamic)]
    }

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

        // App Group keeps the widget UI in sync when the signing environment
        // supports it. UserDefaults.standard provides the host-app fallback
        // when the intent is executed in the BusControl process on iOS 26.
        sharedDefaults?.set(nextValue, forKey: stateKey)
        sharedDefaults?.set(nextValue, forKey: pendingKey)
        // Flush the shared snapshot before the interaction finishes.
        // Do not force an immediate WidgetKit timeline reload here: the SwiftUI
        // Toggle already updates optimistically, while an immediate reload can
        // redraw an older timeline entry and make the checkmark jump back.
        sharedDefaults?.synchronize()

        appDefaults.set(appDefaults.integer(forKey: counterKey) + 1, forKey: counterKey)
        appDefaults.synchronize()

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
