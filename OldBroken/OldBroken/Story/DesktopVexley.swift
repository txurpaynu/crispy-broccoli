import SwiftUI

/// From Chapter 3 on, Vexley lives on the desktop: he wanders along the taskbar,
/// peeks at windows, and stops to talk when tapped.
struct DesktopVexley: View {
    let area: CGSize
    @ObservedObject private var director = StoryDirector.shared
    @EnvironmentObject var session: GameSession
    @State private var appeared = false
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSince(start)
            let talking = director.dialogue.isActive
            // walk back and forth across the bottom, pausing at each end
            let span = max(80, area.width - 120)
            let cycle = 26.0
            let ph = (t / cycle).truncatingRemainder(dividingBy: 1)
            let (xNorm, facingRight): (Double, Bool) = {
                switch ph {
                case ..<0.4: return (ph / 0.4, true)
                case ..<0.5: return (1, true)
                case ..<0.9: return (1 - (ph - 0.5) / 0.4, false)
                default: return (0, false)
                }
            }()
            let walking = !talking && ((ph > 0 && ph < 0.4) || (ph > 0.5 && ph < 0.9))
            let x = talking ? area.width - 90 : 60 + span * xNorm
            let hop = walking ? abs(sin(t * 7)) * 5 : sin(t * 2) * 1.5
            ZStack {
                Ellipse().fill(.black.opacity(0.35)).frame(width: 40, height: 8).offset(y: 30)
                VexleyFaceView(expression: talking ? director.dialogue.expression : (walking ? .happy : .curious))
                    .frame(width: talking ? 84 : 62, height: talking ? 84 : 62)
                    .scaleEffect(x: facingRight || talking ? 1 : -1, y: 1)
                    .shadow(color: Color(red: 1, green: 0.4, blue: 0.75).opacity(0.7), radius: 8)
                    .offset(y: -hop)
                    .contentShape(Circle())
                    .onTapGesture {
                        AudioManager.shared.play(.vexleyVoice(pitch: 340, rough: 0))
                        director.desktopTalk()
                    }
            }
            .position(x: x, y: area.height - (talking ? 150 : 40))
            .animation(.spring(response: 0.5, dampingFraction: 0.75), value: talking)
        }
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.2, anchor: .bottom)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.2)) { appeared = true }
        }
    }
}
