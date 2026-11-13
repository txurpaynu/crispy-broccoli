import SwiftUI

struct TitleView: View {
    @EnvironmentObject var session: GameSession
    @State private var glitch = false
    @State private var confirmNew = false
    private let hasSave = SaveGameManager().latest() != nil
    private let timer = Timer.publish(every: 2.7, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            // faint monitor glow
            RadialGradient(colors: [Color(red: 0.12, green: 0.16, blue: 0.3).opacity(0.6), .clear],
                           center: .center, startRadius: 10, endRadius: 420)
                .ignoresSafeArea()
            Scanlines().opacity(0.25).ignoresSafeArea().allowsHitTesting(false)

            VStack(spacing: 34) {
                ZStack {
                    title.foregroundStyle(Color(red: 1, green: 0.2, blue: 0.55)).offset(x: glitch ? -4 : -1)
                    title.foregroundStyle(Color(red: 0.2, green: 0.9, blue: 1)).offset(x: glitch ? 4 : 1)
                    title.foregroundStyle(.white)
                }
                .blendMode(.screen)

                VStack(spacing: 14) {
                    if hasSave {
                        menuButton("Continue") { session.continueGame() }
                    }
                    menuButton("New Game") {
                        if hasSave { confirmNew = true } else { session.newGame() }
                    }
                }
                Text("Vertical slice · Prologue + Chapter 1 opening · headphones recommended")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .onReceive(timer) { _ in
            withAnimation(.linear(duration: 0.06)) { glitch = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { glitch = false }
        }
        .confirmationDialog("Start a new game? Your autosave will be overwritten.", isPresented: $confirmNew, titleVisibility: .visible) {
            Button("New Game", role: .destructive) { session.newGame() }
        }
    }

    private var title: some View {
        Text("OLD / BROKEN")
            .font(.system(size: 52, weight: .heavy, design: .monospaced))
            .kerning(4)
    }

    private func menuButton(_ t: String, action: @escaping () -> Void) -> some View {
        Button {
            AudioManager.shared.play(.uiClick)
            action()
        } label: {
            Text(t.uppercased())
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .kerning(3)
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 220, height: 40)
                .overlay(Rectangle().stroke(.white.opacity(0.3)))
        }
    }
}

struct Scanlines: View {
    var spacing: CGFloat = 3
    var body: some View {
        Canvas { ctx, size in
            var y: CGFloat = 0
            while y < size.height {
                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(.black))
                y += spacing
            }
        }
    }
}
