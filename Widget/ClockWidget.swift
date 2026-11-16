import WidgetKit
import SwiftUI

// Trick: WidgetKit can't redraw every second, but a `.timer` Text counts
// live. Counting up from local midnight = the current wall-clock time.
struct ClockEntry: TimelineEntry {
    let date: Date
    let midnight: Date   // reference point so the timer reads HH:MM:SS
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> ClockEntry { entry(at: .now) }

    func getSnapshot(in context: Context, completion: @escaping (ClockEntry) -> Void) {
        completion(entry(at: .now))
    }

    // Hourly entries recompute the reference (handles DST + time zone changes).
    func getTimeline(in context: Context, completion: @escaping (Timeline<ClockEntry>) -> Void) {
        let cal = Calendar.current
        let now = Date()
        let nextHour = cal.nextDate(after: now, matching: DateComponents(minute: 0, second: 0),
                                    matchingPolicy: .nextTime) ?? now.addingTimeInterval(3600)
        var entries = [entry(at: now)]
        for i in 0..<24 {
            entries.append(entry(at: nextHour.addingTimeInterval(Double(i) * 3600)))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(at date: Date) -> ClockEntry {
        let c = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        let secs = Double((c.hour ?? 0) * 3600 + (c.minute ?? 0) * 60 + (c.second ?? 0))
        return ClockEntry(date: date, midnight: date.addingTimeInterval(-secs))
    }
}

struct LiveTime: View {
    let entry: ClockEntry
    var body: some View {
        Text(entry.midnight, style: .timer)
            .monospacedDigit()
            .multilineTextAlignment(.center)
    }
}

struct ClockWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: ClockEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            LiveTime(entry: entry)
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                LiveTime(entry: entry)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .padding(4)
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 0) {
                LiveTime(entry: entry)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.leading)
                Text(entry.date, format: .dateTime.weekday(.abbreviated).month().day())
                    .font(.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            VStack(spacing: 4) {
                LiveTime(entry: entry)
                    .font(.system(size: family == .systemSmall ? 34 : 54,
                                  weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                Text(entry.date, format: .dateTime.weekday(.wide).month().day())
                    .font(.subheadline).foregroundStyle(.secondary)
                Text(TimeZone.current.identifier.replacingOccurrences(of: "_", with: " "))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}

struct ClockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SecondsClock", provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                ClockWidgetView(entry: entry).containerBackground(.fill.tertiary, for: .widget)
            } else {
                ClockWidgetView(entry: entry)
            }
        }
        .configurationDisplayName("Seconds Clock")
        .description("Local time with live seconds.")
        .supportedFamilies([.systemSmall, .systemMedium,
                            .accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

@main
struct ClockWidgetBundle: WidgetBundle {
    var body: some Widget { ClockWidget() }
}
