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

// MARK: - Home screen widget

private struct BusControlWidgetEntry: TimelineEntry {
    let date: Date
    let morningDone: Bool
    let eveningDone: Bool
}

private struct BusControlWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> BusControlWidgetEntry {
        BusControlWidgetEntry(date: Date(), morningDone: true, eveningDone: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (BusControlWidgetEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BusControlWidgetEntry>) -> Void) {
        let current = entry()
        let tomorrow = Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: Calendar.current.startOfDay(for: Date())
        ) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [current], policy: .after(tomorrow.addingTimeInterval(30))))
    }

    private func entry() -> BusControlWidgetEntry {
        let defaults = UserDefaults(suiteName: busControlAppGroup)
        let today = Self.dateKey(Date())
        let snapshotDate = defaults?.string(forKey: "snapshot_date")
        let isCurrent = snapshotDate == today

        return BusControlWidgetEntry(
            date: Date(),
            morningDone: isCurrent ? (defaults?.bool(forKey: "morning_done") ?? false) : false,
            eveningDone: isCurrent ? (defaults?.bool(forKey: "evening_done") ?? false) : false
        )
    }

    static func dateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

struct BusControlHomeWidget: Widget {
    let kind = "BusControlHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BusControlWidgetProvider()) { entry in
            BusControlHomeWidgetView(entry: entry)
        }
        .configurationDisplayName("BusControl PRO")
        .description("Утро, вечер, пробег и заправка прямо с домашнего экрана.")
        .supportedFamilies([.systemMedium])
    }
}

private struct BusControlHomeWidgetView: View {
    let entry: BusControlWidgetEntry

    var body: some View {
        VStack(spacing: 11) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(.white.opacity(0.16))
                    Image(systemName: "bus.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 31, height: 31)

                VStack(alignment: .leading, spacing: 1) {
                    Text("BusControl PRO")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(Self.dayLabel(entry.date))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
            }

            HStack(spacing: 9) {
                tripControl(
                    title: "Утро",
                    symbol: "sun.max.fill",
                    done: entry.morningDone,
                    kind: "morning"
                )
                tripControl(
                    title: "Вечер",
                    symbol: "moon.stars.fill",
                    done: entry.eveningDone,
                    kind: "evening"
                )
            }

            HStack(spacing: 9) {
                Link(destination: URL(string: "buscontrol://mileage")!) {
                    quickButton(title: "Конечный пробег", symbol: "road.lanes")
                }
                Link(destination: URL(string: "buscontrol://fuel")!) {
                    quickButton(title: "Заправка", symbol: "fuelpump.fill")
                }
            }
        }
        .padding(14)
        .busControlWidgetBackground()
    }

    @ViewBuilder
    private func tripControl(title: String, symbol: String, done: Bool, kind: String) -> some View {
        if #available(iOS 17.0, *) {
            // Use WidgetKit's intent-backed Toggle instead of a Button.
            // Toggle updates its visual state optimistically as soon as the
            // user taps it, while ToggleTripIntent keeps the app/database sync.
            Toggle(isOn: done, intent: ToggleTripIntent(kind: kind, currentState: done)) {
                HStack(spacing: 8) {
                    Image(systemName: symbol)
                        .font(.system(size: 14, weight: .semibold))
                    Text(title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Spacer(minLength: 2)
                }
            }
            .toggleStyle(BusControlTripToggleStyle())
        } else {
            tripButton(title: title, symbol: symbol, done: done)
        }
    }

    private func tripButton(title: String, symbol: String, done: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            Spacer(minLength: 2)
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 17, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 11)
        .frame(maxWidth: .infinity, minHeight: 42)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(done ? .white.opacity(0.20) : .white.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(.white.opacity(done ? 0.24 : 0.10), lineWidth: 0.8)
        )
    }

    private func quickButton(title: String, symbol: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .lineLimit(1)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .opacity(0.7)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 36)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(.black.opacity(0.18))
        )
    }

    private static func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM, EEEE"
        return formatter.string(from: date).capitalized
    }
}

@available(iOS 17.0, *)
private struct BusControlTripToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.label
            Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 17, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 11)
        .frame(maxWidth: .infinity, minHeight: 42)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(configuration.isOn ? .white.opacity(0.20) : .white.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(.white.opacity(configuration.isOn ? 0.24 : 0.10), lineWidth: 0.8)
        )
        .contentShape(Rectangle())
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
