import SwiftUI

/// A full-screen story beat between scenes: a night, a meal, a bus ride.
/// Lines fade in one by one; the player taps to continue when they're done.
struct Interstitial: Identifiable {
    let id = UUID()
    var heading: String? = nil
    let lines: [String]
    /// Show a faint Vexley face from this line on (nil = never).
    var faceAt: Int? = nil
    var face: VexleyExpression = .worried
    var tint: Color = .white
    var then: @MainActor () -> Void
}

extension GameSession {
    func play(_ i: Interstitial) {
        interstitial = i
        AudioManager.shared.setScene(.silence)
        screen = .interstitial
    }
}

struct InterstitialView: View {
    @EnvironmentObject var session: GameSession
    let beat: Interstitial
    @State private var visible = 0
    @State private var done = false
    @State private var drift = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let f = beat.faceAt, visible > f {
                VexleyFaceView(expression: beat.face)
                    .frame(width: 200, height: 200)
                    .opacity(0.16)
                    .blur(radius: 1.5)
                    .scaleEffect(drift ? 1.06 : 0.98)
                    .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: drift)
                    .transition(.opacity)
                    .onAppear { drift = true }
            }
            VStack(spacing: 16) {
                if let h = beat.heading {
                    Text(h)
                        .font(.system(size: 12, weight: .bold, design: .monospaced)).kerning(4)
                        .foregroundStyle(beat.tint.opacity(0.55))
                        .opacity(visible > 0 ? 1 : 0)
                        .padding(.bottom, 6)
                }
                ForEach(0..<beat.lines.count, id: \.self) { i in
                    Text(beat.lines[i])
                        .font(.system(size: 17, design: .serif)).italic()
                        .multilineTextAlignment(.center)
                        .foregroundStyle(beat.tint.opacity(0.88))
                        .opacity(i < visible ? 1 : 0)
                        .offset(y: i < visible ? 0 : 8)
                }
                if done {
                    Text("Tap to continue")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(.top, 14)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 70)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if done {
                AudioManager.shared.play(.uiClick)
                let next = beat.then
                session.interstitial = nil
                next()
            } else {
                withAnimation(.easeOut(duration: 0.4)) { visible = beat.lines.count; done = true }
            }
        }
        .onAppear {
            for i in 1...beat.lines.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6 + Double(i - 1) * 2.3) {
                    guard visible < i else { return }
                    withAnimation(.easeOut(duration: 1.2)) { visible = i }
                    if let f = beat.faceAt, i == f + 1 { AudioManager.shared.play(.vexleyVoice(pitch: 280, rough: 0.3)) }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6 + Double(beat.lines.count) * 2.3) {
                withAnimation { done = true }
            }
        }
    }
}
