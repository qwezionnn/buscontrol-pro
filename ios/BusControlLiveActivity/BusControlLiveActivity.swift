import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@main
struct BusControlLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        BusControlOrderLiveActivity()
        BusControlHomeWidget()
    }
}

// MARK: - Live Activity

struct BusControlOrderLiveActivity: Widget {
    private func eventIcon(_ kind: String) -> String {
        switch kind {
        case "note": return "📌"
        default: return "🚌"
        }
    }

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BusOrderAttributes.self) { context in
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("\(eventIcon(context.state.kind)) BusControl PRO")
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
                    Text(eventIcon(context.state.kind))
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
                Text(eventIcon(context.state.kind))
            } compactTrailing: {
                Text(timerInterval: Date()...context.state.orderDate, countsDown: true)
                    .monospacedDigit()
                    .frame(width: 52)
            } minimal: {
                Text(eventIcon(context.state.kind))
            }
            .keylineTint(.white)
        }
    }
}

// MARK: - Home screen widget

private struct BusControlWidgetEntry: TimelineEntry {
    let date: Date
}

private struct BusControlWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> BusControlWidgetEntry {
        BusControlWidgetEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (BusControlWidgetEntry) -> Void) {
        completion(BusControlWidgetEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BusControlWidgetEntry>) -> Void) {
        let current = BusControlWidgetEntry(date: Date())
        let tomorrow = Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: Calendar.current.startOfDay(for: Date())
        ) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [current], policy: .after(tomorrow.addingTimeInterval(30))))
    }
}

struct BusControlHomeWidget: Widget {
    let kind = "BusControlHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BusControlWidgetProvider()) { entry in
            BusControlHomeWidgetView(entry: entry)
        }
        .configurationDisplayName("BusControl PRO")
        .description("Быстрый переход к рейсам, пробегу, заказам, заправке и календарю.")
        .supportedFamilies([.systemMedium])
    }
}

private struct BusControlHomeWidgetView: View {
    let entry: BusControlWidgetEntry

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(.white.opacity(0.16))
                    Image(systemName: "bus.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 31, height: 31)

                VStack(alignment: .leading, spacing: 2) {
                    Text("BusControl PRO")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    HStack(spacing: 6) {
                        Text(Self.dayLabel(entry.date))
                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(1)

                        Link(destination: URL(string: "buscontrol://calendar")!) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 20)
                                .background(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(.white.opacity(0.14))
                                )
                        }
                        .accessibilityLabel("Открыть календарь")
                    }
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Link(destination: URL(string: "buscontrol://trips")!) {
                    actionButton(
                        title: "Утро / вечер",
                        symbol: "sun.horizon.fill"
                    )
                }

                Link(destination: URL(string: "buscontrol://mileage")!) {
                    actionButton(
                        title: "Конечный пробег",
                        symbol: "road.lanes"
                    )
                }
            }

            HStack(spacing: 8) {
                Link(destination: URL(string: "buscontrol://order")!) {
                    actionButton(
                        title: "Новый заказ",
                        symbol: "shippingbox.fill"
                    )
                }

                Link(destination: URL(string: "buscontrol://fuel")!) {
                    actionButton(
                        title: "Заправка",
                        symbol: "fuelpump.fill"
                    )
                }
            }
        }
        .padding(11)
        .busControlWidgetBackground()
    }

    private func actionButton(title: String, symbol: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 18)

            Text(title)
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer(minLength: 1)

            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .opacity(0.62)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 39)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.11))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 0.8)
        )
        .contentShape(Rectangle())
    }

    private static func dayLabel(_ date: Date) -> String {
        let weekday = DateFormatter()
        weekday.locale = Locale(identifier: "ru_RU")
        weekday.dateFormat = "EEE"

        let datePart = DateFormatter()
        datePart.locale = Locale(identifier: "ru_RU")
        datePart.dateFormat = "d MMMM"

        let rawWeekday = weekday.string(from: date)
            .replacingOccurrences(of: ".", with: "")
        let prettyWeekday = rawWeekday.prefix(1).uppercased() + rawWeekday.dropFirst()
        return "Сегодня • \(prettyWeekday), \(datePart.string(from: date))"
    }
}

private extension View {
    @ViewBuilder
    func busControlWidgetBackground() -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(for: .widget) {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.14, blue: 0.29),
                        Color(red: 0.04, green: 0.08, blue: 0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        } else {
            self.background(
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.14, blue: 0.29),
                        Color(red: 0.04, green: 0.08, blue: 0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }
}
