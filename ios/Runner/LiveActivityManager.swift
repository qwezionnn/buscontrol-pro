import ActivityKit
import Foundation

@available(iOS 16.1, *)
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private init() {}

    private func existing(eventId: Int) -> Activity<BusOrderAttributes>? {
        Activity<BusOrderAttributes>.activities.first {
            $0.attributes.orderId == eventId
        }
    }

    private func endExisting(eventId: Int) async {
        for activity in Activity<BusOrderAttributes>.activities where activity.attributes.orderId == eventId {
            await activity.end(using: nil, dismissalPolicy: .immediate)
        }
    }

    func start(
        eventId: Int,
        kind: String,
        title: String,
        time: String,
        note: String,
        eventDate: Date,
        replaceExisting: Bool = true
    ) async throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw NSError(
                domain: "BusControlLiveActivity",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Live Activities are disabled"]
            )
        }

        if replaceExisting {
            await endExisting(eventId: eventId)
        } else if existing(eventId: eventId) != nil {
            NSLog("BusControl Live Activity already registered: id=%d", eventId)
            return
        }

        let attributes = BusOrderAttributes(orderId: eventId)
        let state = BusOrderAttributes.ContentState(
            title: title,
            time: time,
            note: note,
            orderDate: eventDate,
            kind: kind
        )

        let activity = try Activity.request(
            attributes: attributes,
            contentState: state,
            pushType: nil
        )
        NSLog("BusControl Live Activity started: id=%d kind=%@ activity=%@", eventId, kind, activity.id)
    }

    /// iOS 26 can register a Live Activity in advance and let the system start
    /// it at `startDate`, even when BusControl PRO is no longer in foreground.
    func schedule(
        eventId: Int,
        kind: String,
        title: String,
        time: String,
        note: String,
        eventDate: Date,
        startDate: Date,
        replaceExisting: Bool = true
    ) async throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw NSError(
                domain: "BusControlLiveActivity",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Live Activities are disabled"]
            )
        }

        if replaceExisting {
            await endExisting(eventId: eventId)
        } else if existing(eventId: eventId) != nil {
            NSLog("BusControl scheduled Live Activity already registered: id=%d", eventId)
            return
        }

        if startDate <= Date() {
            try await start(
                eventId: eventId,
                kind: kind,
                title: title,
                time: time,
                note: note,
                eventDate: eventDate,
                replaceExisting: false
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

        let attributes = BusOrderAttributes(orderId: eventId)
        let state = BusOrderAttributes.ContentState(
            title: title,
            time: time,
            note: note,
            orderDate: eventDate,
            kind: kind
        )
        let content = ActivityContent(
            state: state,
            staleDate: eventDate,
            relevanceScore: 100
        )
        let alert = AlertConfiguration(
            title: "BusControl PRO",
            body: "Событие скоро начнётся",
            sound: .default
        )

        let activity = try Activity.request(
            attributes: attributes,
            content: content,
            pushType: nil,
            style: .standard,
            alertConfiguration: alert,
            start: startDate
        )
        NSLog(
            "BusControl Live Activity scheduled: id=%d kind=%@ start=%@ event=%@ activity=%@",
            eventId,
            kind,
            startDate.description,
            eventDate.description,
            activity.id
        )
    }

    func end(eventId: Int) async {
        await endExisting(eventId: eventId)
    }
}
