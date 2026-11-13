import SwiftUI

/// Shown after the player goes to bed: the end of the vertical slice.
struct EndSliceView: View {
    @EnvironmentObject var session: GameSession
    @State private var visibleLines = 0
    @State private var showFace = false

    private var lines: [String] {
        let m = session.data.vexley
        var l = ["You sleep badly."]
        l.append("At some point you open your eyes. The room is lit pink.")
        l.append(m.remembered.contains("promised_return")
                 ? "On the monitor, something is waiting for tomorrow."
                 : "On the monitor, something is still awake.")
        l.append("The computer never went to sleep.")
        return l
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if showFace {
                VexleyFaceView(expression: session.data.vexley.trust >= 2 ? .happy : .worried)
                    .frame(width: 180, height: 180)
                    .opacity(0.18)
                    .blur(radius: 1.5)
                    .transition(.opacity)
            }
            VStack(spacing: 18) {
                ForEach(0..<lines.count, id: \.self) { i in
                    Text(lines[i])
                        .font(.system(size: 17, design: .serif))
                        .italic()
                        .foregroundStyle(.white.opacity(0.85))
                        .opacity(i < visibleLines ? 1 : 0)
                }
                if visibleLines > lines.count {
                    VStack(spacing: 8) {
                        Text("OLD / BROKEN").font(.system(size: 22, weight: .heavy, design: .monospaced)).kerning(3)
                        Text("End of the vertical slice. Chapter 1 continues in \"Still here?\"")
                            .font(.system(size: 12, design: .monospaced)).foregroundStyle(.white.opacity(0.55))
                        Button("Return to title") { session.quitToTitle() }
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .padding(.top, 10)
                    }
                    .foregroundStyle(.white)
                    .transition(.opacity)
                }
            }
            .padding(40)
        }
        .onAppear {
            for i in 1...(lines.count + 1) {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 2.4) {
                    withAnimation(.easeIn(duration: 1.2)) {
                        visibleLines = i
                        if i == 3 { showFace = true; AudioManager.shared.play(.vexleyVoice(pitch: 280, rough: 0.3)) }
                    }
                }
            }
        }
    }
}
