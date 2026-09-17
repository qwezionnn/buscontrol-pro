import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct BusOrderAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String
        var time: String
        var note: String
        var orderDate: Date
        var kind: String

        init(
            title: String,
            time: String,
            note: String,
            orderDate: Date,
            kind: String = "order"
        ) {
            self.title = title
            self.time = time
            self.note = note
            self.orderDate = orderDate
            self.kind = kind
        }

        private enum CodingKeys: String, CodingKey {
            case title
            case time
            case note
            case orderDate
            case kind
        }

        // Keep old pending/active Live Activities decodable after this update.
        // Builds before this patch did not store `kind` in ContentState.
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            title = try container.decode(String.self, forKey: .title)
            time = try container.decode(String.self, forKey: .time)
            note = try container.decode(String.self, forKey: .note)
            orderDate = try container.decode(Date.self, forKey: .orderDate)
            kind = try container.decodeIfPresent(String.self, forKey: .kind) ?? "order"
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(title, forKey: .title)
            try container.encode(time, forKey: .time)
            try container.encode(note, forKey: .note)
            try container.encode(orderDate, forKey: .orderDate)
            try container.encode(kind, forKey: .kind)
        }
    }

    // The property keeps its historical name for compatibility with already
    // persisted activities, but it is now a generic BusControl event id.
    var orderId: Int
}
