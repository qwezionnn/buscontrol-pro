import ActivityKit
import Foundation

@available(iOS 16.1, *)
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private init() {}

    func start(orderId: Int, title: String, time: String, note: String, orderDate: Date) async throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw NSError(domain: "BusControlLiveActivity", code: 1, userInfo: [NSLocalizedDescriptionKey: "Live Activities are disabled"])
        }

        for activity in Activity<BusOrderAttributes>.activities where activity.attributes.orderId == orderId {
            await activity.end(using: nil, dismissalPolicy: .immediate)
        }

        let attributes = BusOrderAttributes(orderId: orderId)
        let state = BusOrderAttributes.ContentState(title: title, time: time, note: note, orderDate: orderDate)
        _ = try Activity.request(attributes: attributes, contentState: state, pushType: nil)
    }

    func end(orderId: Int) async {
        for activity in Activity<BusOrderAttributes>.activities where activity.attributes.orderId == orderId {
            await activity.end(using: nil, dismissalPolicy: .immediate)
        }
    }
}
