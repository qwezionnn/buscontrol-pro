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

    @Parameter(title: "Текущее состояние")
    var currentState: Bool

    init() {
        self.kind = "morning"
        self.currentState = false
    }

    init(kind: String, currentState: Bool) {
        self.kind = kind
        self.currentState = currentState
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
        let appPendingKey = isMorning
            ? "widget_pending_morning_state_app"
            : "widget_pending_evening_state_app"

        // IMPORTANT: derive the requested value from the timeline entry that the
        // user actually tapped, not from UserDefaults. WidgetKit may execute an
        // interactive intent more than once in some signing/runtime scenarios.
        // Writing an explicit target value makes the action idempotent: two
        // executions both set TRUE (or both set FALSE) instead of toggling twice.
        let targetValue = !currentState

        // Shared value drives the widget snapshot when App Groups are available.
        sharedDefaults?.set(targetValue, forKey: stateKey)
        sharedDefaults?.set(targetValue, forKey: pendingKey)
        sharedDefaults?.synchronize()

        // Host-app fallback. Store the desired state, never a toggle counter.
        // Repeated executions simply overwrite the same value.
        appDefaults.set(targetValue, forKey: appPendingKey)
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
