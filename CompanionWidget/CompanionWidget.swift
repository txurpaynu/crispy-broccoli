import WidgetKit
import SwiftUI
import ActivityKit

@main
struct CompanionWidgetBundle: WidgetBundle {
    var body: some Widget {
        CompanionLiveActivity()
        VexleyHomeWidget()
    }
}

/// The companion on the Lock Screen and in the Dynamic Island.
struct CompanionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CompanionAttributes.self) { context in
            LockScreenCompanion(name: context.attributes.name, state: context.state)
                .activityBackgroundTint(Color(red: 0.12, green: 0.02, blue: 0.12))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(URL(string: "shimeji://chat"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    FaceImage(face: context.state.face)
                        .frame(width: 52, height: 52)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.state.mood.emoji).font(.title3)
                        Label("\(context.state.happiness)%", systemImage: "heart.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.pink)
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.name)
                        .font(.system(.headline, design: .rounded))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.message)
                        .font(.system(.subheadline, design: .rounded))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            } compactLeading: {
                FaceImage(face: context.state.face)
                    .frame(width: 24, height: 24)
            } compactTrailing: {
                Text(context.state.mood.emoji)
            } minimal: {
                FaceImage(face: context.state.face)
                    .frame(width: 22, height: 22)
            }
            .widgetURL(URL(string: "shimeji://chat"))
            .keylineTint(Color(red: 1.0, green: 0.12, blue: 0.5))
        }
    }
}

/// Still frame of the mascot's current face (Live Activities can't play GIFs).
/// Images live in CompanionWidget/Assets.xcassets as face-<name>.
private struct FaceImage: View {
    var face: Face

    var body: some View {
        Image("face-\(face.rawValue)")
            .resizable()
            .scaledToFit()
    }
}

private struct LockScreenCompanion: View {
    var name: String
    var state: CompanionAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            FaceImage(face: state.face)
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(name).font(.system(.headline, design: .rounded))
                    Spacer()
                    Text("\(state.mood.emoji) \(state.happiness)%")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                }
                Text(state.message.isEmpty ? "..." : state.message)
                    .font(.system(.subheadline, design: .rounded))
                    .lineLimit(2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .foregroundStyle(Color(red: 0.3, green: 0.05, blue: 0.2))
                    .background(RoundedRectangle(cornerRadius: 12).fill(.white))
            }
            .foregroundStyle(.white)
        }
        .padding(14)
    }
}


private struct VexleyWidgetEntry: TimelineEntry {
    let date: Date
    let name: String
    let state: CompanionAttributes.ContentState
}

private struct VexleyWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> VexleyWidgetEntry {
        sampleEntry
    }

    func getSnapshot(in context: Context, completion: @escaping (VexleyWidgetEntry) -> Void) {
        completion(currentEntry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VexleyWidgetEntry>) -> Void) {
        let entry = currentEntry
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
    }

    private var currentEntry: VexleyWidgetEntry {
        if let activity = Activity<CompanionAttributes>.activities.first {
            return VexleyWidgetEntry(
                date: Date(),
                name: activity.attributes.name,
                state: activity.content.state
            )
        }
        return sampleEntry
    }

    private var sampleEntry: VexleyWidgetEntry {
        VexleyWidgetEntry(
            date: Date(),
            name: "Vexley",
            state: CompanionAttributes.ContentState(
                message: "Tap me and tell me something weird.",
                mood: .happy,
                happiness: 70,
                face: .happy
            )
        )
    }
}

private struct VexleyHomeWidget: Widget {
    static let kind = "VexleyHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: VexleyWidgetProvider()) { entry in
            VexleyHomeWidgetView(entry: entry)
        }
        .configurationDisplayName("Vexley")
        .description("See Vexley's current face, mood, heart, and last message.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct VexleyHomeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: VexleyWidgetEntry

    var body: some View {
        Group {
            if family == .systemSmall {
                smallLayout
            } else {
                mediumLayout
            }
        }
        .containerBackground(
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.01, blue: 0.10), Color(red: 0.20, green: 0.04, blue: 0.22)],
                startPoint: .top,
                endPoint: .bottom
            ),
            for: .widget
        )
        .widgetURL(URL(string: "shimeji://chat"))
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                FaceImage(face: entry.state.face)
                    .frame(width: 64, height: 64)
                Spacer(minLength: 0)
                Text(entry.state.mood.emoji)
                    .font(.title2)
            }
            Text(entry.name)
                .font(.system(.headline, design: .rounded))
                .lineLimit(1)
            Label("\(entry.state.happiness)%", systemImage: "heart.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.pink)
            Text(entry.state.message)
                .font(.caption2)
                .lineLimit(2)
                .foregroundStyle(.white.opacity(0.85))
            Spacer(minLength: 0)
        }
        .padding(12)
        .foregroundStyle(.white)
    }

    private var mediumLayout: some View {
        HStack(spacing: 12) {
            FaceImage(face: entry.state.face)
                .frame(width: 92, height: 92)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(entry.name)
                        .font(.system(.headline, design: .rounded))
                        .lineLimit(1)
                    Spacer()
                    Text(entry.state.mood.emoji)
                }
                Label("\(entry.state.happiness)%", systemImage: "heart.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.pink)
                Text(entry.state.message)
                    .font(.system(.subheadline, design: .rounded))
                    .lineLimit(3)
                    .foregroundStyle(.white.opacity(0.9))
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
        }
        .padding(14)
    }
}
