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
        guard let defaults = UserDefaults(suiteName: busControlAppGroup) else {
            return .result()
        }

        let today = Self.dateKey(Date())
        if defaults.string(forKey: "snapshot_date") != today {
            defaults.set(today, forKey: "snapshot_date")
            defaults.set(false, forKey: "morning_done")
            defaults.set(false, forKey: "evening_done")
        }

        let isMorning = kind == "morning"
        let stateKey = isMorning ? "morning_done" : "evening_done"
        let pendingKey = isMorning ? "pending_morning_state" : "pending_evening_state"
        let nextValue = !defaults.bool(forKey: stateKey)

        defaults.set(nextValue, forKey: stateKey)
        defaults.set(nextValue, forKey: pendingKey)
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
