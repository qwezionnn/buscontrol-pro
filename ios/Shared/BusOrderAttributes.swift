import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct BusOrderAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String
        var time: String
        var note: String
        var orderDate: Date
    }

    var orderId: Int
}
