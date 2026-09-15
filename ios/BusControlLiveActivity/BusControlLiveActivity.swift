import ActivityKit
import SwiftUI
import WidgetKit

@main
struct BusControlLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        BusControlOrderLiveActivity()
    }
}

struct BusControlOrderLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BusOrderAttributes.self) { context in
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("🚌 BusControl PRO")
                        .font(.headline)
                    Spacer()
                    Text(context.state.time)
                        .font(.headline)
                }

                Text(timerInterval: Date()...context.state.orderDate, countsDown: true)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()

                Text(context.state.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                if !context.state.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(context.state.note)
                        .font(.caption)
                        .lineLimit(2)
                }
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.88))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("🚌")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.time).font(.headline)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(timerInterval: Date()...context.state.orderDate, countsDown: true)
                        .font(.title3.bold())
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 2) {
                        Text(context.state.title).lineLimit(1)
                        if !context.state.note.isEmpty {
                            Text(context.state.note).font(.caption).lineLimit(1)
                        }
                    }
                }
            } compactLeading: {
                Text("🚌")
            } compactTrailing: {
                Text(timerInterval: Date()...context.state.orderDate, countsDown: true)
                    .monospacedDigit()
                    .frame(width: 52)
            } minimal: {
                Text("🚌")
            }
            .keylineTint(.white)
        }
    }
}
