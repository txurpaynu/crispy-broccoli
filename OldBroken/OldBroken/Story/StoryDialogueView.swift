import SwiftUI

/// Draws the story dialogue (Chapters 2–8). Used inline by the VX game window and as a
/// floating overlay everywhere else (desktop, apartment via phone, facility via laptop).
struct StoryDialoguePanel: View {
    enum Style { case vx, overlay, assistant, terminal }

    @ObservedObject var director = StoryDirector.shared
    var style: Style = .overlay
    @State private var appeared = false

    private var dm: DialogueManager { director.dialogue }

    var body: some View {
        if let node = dm.node {
            let isVex = node.speaker == "VEXLEY"
            VStack(alignment: .trailing, spacing: 6) {
                if !dm.typing && !dm.visibleChoices.isEmpty {
                    VStack(alignment: .trailing, spacing: 5) {
                        ForEach(Array(dm.visibleChoices.enumerated()), id: \.offset) { i, c in
                            Button { dm.choose(c) } label: {
                                Text(dm.substitute(c.text))
                                    .font(choiceFont)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(choiceBackground)
                            }
                            .buttonStyle(.plain)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                            .animation(.spring(response: 0.35, dampingFraction: 0.8).delay(Double(i) * 0.06), value: dm.visibleChoices.count)
                        }
                    }
                }
                HStack(alignment: .top, spacing: 10) {
                    if isVex {
                        VexleyFaceView(expression: dm.expression)
                            .frame(width: 70, height: 70)
                            .background(faceBackground)
                            .clipShape(RoundedRectangle(cornerRadius: style == .vx ? 14 : 8))
                            .overlay(RoundedRectangle(cornerRadius: style == .vx ? 14 : 8).stroke(accent, lineWidth: 2))
                            .shadow(color: accent.opacity(0.6), radius: 8)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        if !node.speaker.isEmpty {
                            Text(displaySpeaker(node.speaker))
                                .font(.system(size: 10, weight: .heavy, design: .rounded)).kerning(1.5)
                                .foregroundStyle(isVex ? accent : Color(white: 0.75))
                        }
                        Text(dm.shown)
                            .font(bodyFont)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, minHeight: 82, maxHeight: 112, alignment: .topLeading)
                .background(panelBackground)
                .overlay(alignment: .bottomTrailing) {
                    if !dm.typing && dm.visibleChoices.isEmpty {
                        BlinkingText(text: "▼", size: 10).padding(8)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { dm.advance() }
            }
            .scaleEffect(appeared ? 1 : 0.96, anchor: .bottom)
            .opacity(appeared ? 1 : 0)
            .onAppear { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { appeared = true } }
            .onDisappear { appeared = false }
        }
    }

    private func displaySpeaker(_ s: String) -> String {
        if style == .assistant && s == "VEXLEY" { return "LUMEN" }
        return s
    }

    private var accent: Color {
        switch style {
        case .assistant: return Color(red: 0.55, green: 0.85, blue: 1)
        case .terminal: return Color(red: 0.4, green: 1, blue: 0.55)
        default: return Color(red: 1, green: 0.42, blue: 0.74)
        }
    }

    private var bodyFont: Font {
        switch style {
        case .terminal: return .system(size: 12, design: .monospaced)
        case .vx: return .system(size: 13, weight: .medium, design: .rounded)
        default: return .system(size: 13, weight: .regular, design: .rounded)
        }
    }

    private var choiceFont: Font {
        style == .terminal ? .system(size: 11, weight: .semibold, design: .monospaced) : .system(size: 12, weight: .semibold, design: .rounded)
    }

    @ViewBuilder private var faceBackground: some View {
        LinearGradient(colors: [Color(red: 0.25, green: 0.04, blue: 0.16), Color(red: 0.05, green: 0.1, blue: 0.2)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    @ViewBuilder private var panelBackground: some View {
        switch style {
        case .vx:
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 16).fill(Color(red: 0.12, green: 0.03, blue: 0.12).opacity(0.55)))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(
                    LinearGradient(colors: [accent, Color(red: 0.3, green: 0.9, blue: 1)], startPoint: .leading, endPoint: .trailing),
                    lineWidth: 1.5))
        case .terminal:
            Rectangle().fill(Color.black.opacity(0.92)).overlay(Rectangle().stroke(accent.opacity(0.7), lineWidth: 1))
        case .assistant:
            RoundedRectangle(cornerRadius: 14).fill(Color(red: 0.06, green: 0.08, blue: 0.13).opacity(0.96))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(accent.opacity(0.5), lineWidth: 1))
        case .overlay:
            RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.06, green: 0.03, blue: 0.07).opacity(0.94))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(accent.opacity(0.75), lineWidth: 1.5))
        }
    }

    @ViewBuilder private var choiceBackground: some View {
        switch style {
        case .terminal:
            Rectangle().fill(Color.black.opacity(0.92)).overlay(Rectangle().stroke(accent, lineWidth: 1))
        default:
            Capsule().fill(Color(red: 0.1, green: 0.04, blue: 0.1).opacity(0.95)).overlay(Capsule().stroke(accent.opacity(0.8), lineWidth: 1.2))
        }
    }
}

/// Floating story dialogue for any screen where no view draws it inline.
struct StoryDialogueOverlay: View {
    @ObservedObject var director = StoryDirector.shared
    @EnvironmentObject var session: GameSession

    var body: some View {
        if director.showsOverlayDialogue {
            VStack {
                Spacer()
                StoryDialoguePanel(style: style)
                    .frame(maxWidth: 620)
                    .padding(.horizontal, 60)
                    .padding(.bottom, session.screen == .apartment ? 96 : 44)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var style: StoryDialoguePanel.Style {
        if session.has("lumen_fox") && !session.has("arrived_facility") { return .assistant }
        return .overlay
    }
}

/// Registers a view as drawing the story dialogue itself while it's on screen.
struct InlineDialogueHost: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear { StoryDirector.shared.inlineHosts += 1 }
            .onDisappear { StoryDirector.shared.inlineHosts = max(0, StoryDirector.shared.inlineHosts - 1) }
    }
}
