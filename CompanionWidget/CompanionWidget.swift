import WidgetKit
import SwiftUI
import ActivityKit

@main
struct CompanionWidgetBundle: WidgetBundle {
    var body: some Widget {
        CompanionLiveActivity()
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
