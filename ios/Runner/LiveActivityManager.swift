import ActivityKit
import Foundation

@available(iOS 16.1, *)
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private init() {}

    private func endExisting(orderId: Int) async {
        for activity in Activity<BusOrderAttributes>.activities where activity.attributes.orderId == orderId {
            await activity.end(using: nil, dismissalPolicy: .immediate)
        }
    }

    func start(orderId: Int, title: String, time: String, note: String, orderDate: Date) async throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw NSError(
                domain: "BusControlLiveActivity",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Live Activities are disabled"]
            )
        }

        await endExisting(orderId: orderId)

        let attributes = BusOrderAttributes(orderId: orderId)
        let state = BusOrderAttributes.ContentState(
            title: title,
            time: time,
            note: note,
            orderDate: orderDate
        )
        _ = try Activity.request(
            attributes: attributes,
            contentState: state,
            pushType: nil
        )
    }

    /// iOS 26 can register a Live Activity now and let the system start it at
    /// `startDate`, even when BusControl PRO is no longer in the foreground.
    func schedule(
        orderId: Int,
        title: String,
        time: String,
        note: String,
        orderDate: Date,
        startDate: Date
    ) async throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw NSError(
                domain: "BusControlLiveActivity",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Live Activities are disabled"]
            )
        }

        await endExisting(orderId: orderId)

        if startDate <= Date() {
            try await start(
                orderId: orderId,
                title: title,
                time: time,
                note: note,
                orderDate: orderDate
            )
            return
        }

        guard #available(iOS 26.0, *) else {
            throw NSError(
                domain: "BusControlLiveActivity",
                code: 26,
                userInfo: [NSLocalizedDescriptionKey: "Scheduled Live Activities require iOS 26+"]
            )
        }

        let attributes = BusOrderAttributes(orderId: orderId)
        let state = BusOrderAttributes.ContentState(
            title: title,
            time: time,
            note: note,
            orderDate: orderDate
        )
        let content = ActivityContent(
            state: state,
            staleDate: orderDate
        )
        let alert = AlertConfiguration(
            title: "BusControl PRO",
            body: "Событие скоро начнётся",
            sound: .default
        )

        _ = try Activity.request(
            attributes: attributes,
            content: content,
            pushType: nil,
            style: .standard,
            alertConfiguration: alert,
            start: startDate
        )
    }

    func end(orderId: Int) async {
        await endExisting(orderId: orderId)
    }
}
