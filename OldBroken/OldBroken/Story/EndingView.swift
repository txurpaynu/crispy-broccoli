import SwiftUI

/// The final cinematic: police lights, the interview, the evidence bag, and the drive
/// that still has something in it. Tap to move on faster.
struct EndingView: View {
    @EnvironmentObject var session: GameSession
    @State private var scene = 0
    @State private var started = Date()
    @State private var timer: Timer?

    /// Seconds each scene lasts before moving on by itself.
    private let lengths: [Double] = [5, 9, 16, 8, 9, 9, 7, 30]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Group {
                switch scene {
                case 0: TitleCard(top: "2:14 AM", bottom: "The fence. The road. Sirens.")
                case 1: PoliceLights()
                case 2: Interview(trust: VexleyController.shared.memory.trust, lied: VexleyController.shared.remembers("admitted_master"))
                case 3: EvidenceBag()
                case 4: TitleCard(top: "SIX WEEKS LATER", bottom: "Charges dropped. Equipment returned. One item was \"lost in processing\".")
                case 5: BootScreen()
                case 6: LumenPing(trust: VexleyController.shared.memory.trust)
                default: Credits { session.quitToTitle() }
                }
            }
            .id(scene)
            .transition(.opacity)
        }
        .contentShape(Rectangle())
        .onTapGesture { if scene < lengths.count - 1 { advance() } }
        .onAppear {
            AudioManager.shared.setScene(.silence)
            AudioManager.shared.setDread(0)
            schedule()
        }
        .onDisappear { timer?.invalidate() }
    }

    private func schedule() {
        timer?.invalidate()
        guard scene < lengths.count - 1 else { return }
        timer = Timer.scheduledTimer(withTimeInterval: lengths[scene], repeats: false) { _ in
            Task { @MainActor in advance() }
        }
    }

    private func advance() {
        withAnimation(.easeInOut(duration: 1.0)) { scene += 1 }
        switch scene {
        case 3: AudioManager.shared.play(.paper)
        case 5: AudioManager.shared.play(.powerOn)
        case 6: AudioManager.shared.play(.notification)
        case 7: AudioManager.shared.setScene(.title)
        default: break
        }
        schedule()
    }
}

// MARK: - Scenes

private struct TitleCard: View {
    let top: String, bottom: String
    @State private var shown = false
    var body: some View {
        VStack(spacing: 14) {
            Text(top).font(.system(size: 30, weight: .heavy, design: .monospaced)).kerning(6)
                .foregroundStyle(.white)
            Text(bottom).font(.system(size: 15, weight: .medium)).foregroundStyle(.white.opacity(0.6))
                .opacity(shown ? 1 : 0).offset(y: shown ? 0 : 8)
                .multilineTextAlignment(.center).frame(maxWidth: 480)
        }
        .onAppear { withAnimation(.easeOut(duration: 1.2).delay(0.8)) { shown = true } }
    }
}

/// Red and blue sweeping across a dark street, the building behind a fence.
private struct PoliceLights: View {
    @State private var line = 0
    private let lines = ["\"Hands where I can see them.\"", "\"Anyone else in there with you?\"", "You look back at the building. Every window on the second floor is lit."]
    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let red = max(0, sin(t * 7)), blue = max(0, sin(t * 7 + .pi))
            Canvas { ctx, size in
                let w = size.width, h = size.height
                // sky
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                    Gradient(colors: [Color(red: 0.02, green: 0.02, blue: 0.06), Color(red: 0.05, green: 0.04, blue: 0.08)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
                // the building, windows lit
                let bx = w * 0.18, by = h * 0.22, bw = w * 0.64, bh = h * 0.5
                ctx.fill(Path(CGRect(x: bx, y: by, width: bw, height: bh)), with: .color(Color(white: 0.04)))
                for row in 0..<2 {
                    for col in 0..<9 {
                        let lit = row == 0 || (col * 7 + row * 3) % 5 == 0
                        let flick = row == 0 ? 0.75 + 0.25 * sin(t * 3 + Double(col)) : 0.6
                        ctx.fill(Path(CGRect(x: bx + 20 + CGFloat(col) * (bw - 40) / 9, y: by + 26 + CGFloat(row) * bh * 0.42,
                                             width: (bw - 40) / 9 - 12, height: bh * 0.22)),
                                 with: .color(lit ? Color(red: 0.75, green: 0.95, blue: 1).opacity(flick * 0.55) : Color(white: 0.07)))
                    }
                }
                // fence
                var fence = Path()
                stride(from: 0, through: w, by: 14).forEach { x in
                    fence.move(to: CGPoint(x: x, y: h * 0.6)); fence.addLine(to: CGPoint(x: x + 14, y: h * 0.82))
                    fence.move(to: CGPoint(x: x + 14, y: h * 0.6)); fence.addLine(to: CGPoint(x: x, y: h * 0.82))
                }
                ctx.stroke(fence, with: .color(.white.opacity(0.12)), lineWidth: 1)
                // ground
                ctx.fill(Path(CGRect(x: 0, y: h * 0.82, width: w, height: h * 0.18)), with: .color(Color(white: 0.03)))
                // light wash
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(
                    Gradient(colors: [Color.red.opacity(0.55 * red), .clear]), center: CGPoint(x: w * 0.12, y: h * 0.92), startRadius: 0, endRadius: w * 0.7))
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(
                    Gradient(colors: [Color.blue.opacity(0.6 * blue), .clear]), center: CGPoint(x: w * 0.88, y: h * 0.92), startRadius: 0, endRadius: w * 0.7))
            }
            .ignoresSafeArea()
            .overlay(alignment: .bottom) {
                Text(lines[line]).font(.system(size: 16, weight: .medium)).foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
                    .padding(.bottom, 30).id(line).transition(.opacity)
            }
        }
        .onAppear {
            for i in 1..<lines.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 2.9) { withAnimation { line = i } }
            }
        }
    }
}

/// A lamp, a table, an officer's questions typed out.
private struct Interview: View {
    let trust: Int
    let lied: Bool
    @State private var shown = 0
    @State private var sway = false

    private var lines: [(String, String)] {
        [
            ("OFFICER", "Halden Softworks. Closed since 2003. Fence cut, front door forced, alarm going off at midnight."),
            ("OFFICER", "Building's been without power for twenty years. Tonight every light in it was on."),
            ("YOU", "There was someone in there."),
            ("OFFICER", "We swept it. Twice. There's nobody in there."),
            ("OFFICER", "There's a robot in the loading bay, though. Switched off. Battery's dead. Face down on the concrete, like it fell reaching for the door."),
            ("OFFICER", trust >= 2 ? "Your friend Theo called us. Said you'd been talking to someone online all week. Someone who knew a lot about you."
                                   : "Your friend Theo called us. Said you'd stopped answering anybody who wasn't a computer."),
            ("OFFICER", "What's on the drive?"),
            ("YOU", lied ? "An old game. That's all it is." : "...An old game."),
        ]
    }

    var body: some View {
        ZStack {
            // the lamp cone
            RadialGradient(colors: [Color(red: 1, green: 0.85, blue: 0.6).opacity(0.28), .clear],
                           center: .top, startRadius: 10, endRadius: 420)
                .rotationEffect(.degrees(sway ? 2 : -2), anchor: .top)
                .ignoresSafeArea()
            VStack(alignment: .leading, spacing: 10) {
                Text("INTERVIEW ROOM 2").font(.system(size: 11, weight: .bold, design: .monospaced)).kerning(3)
                    .foregroundStyle(.white.opacity(0.35))
                ForEach(0..<shown, id: \.self) { i in
                    let l = lines[i]
                    HStack(alignment: .top, spacing: 10) {
                        Text(l.0).font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(l.0 == "YOU" ? Color(red: 1, green: 0.5, blue: 0.75) : .white.opacity(0.55))
                            .frame(width: 70, alignment: .leading)
                        Text(l.1).font(.system(size: 14)).foregroundStyle(.white.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(maxWidth: 560, alignment: .leading)
            .padding(.horizontal, 40)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever()) { sway = true }
            for i in 1...lines.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 1.8 - 1.2) {
                    withAnimation(.easeOut(duration: 0.4)) { shown = i }
                    AudioManager.shared.play(.keyTap)
                }
            }
        }
    }
}

/// The USB stick in a plastic evidence bag. Its light blinks when nothing is plugged in.
private struct EvidenceBag: View {
    @State private var appear = false
    @State private var blink = false
    var body: some View {
        ZStack {
            VStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.07))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.25), lineWidth: 1.5))
                        .frame(width: 300, height: 220)
                    Rectangle().fill(Color.red.opacity(0.7)).frame(width: 300, height: 26).offset(y: -97)
                    Text("EVIDENCE").font(.system(size: 13, weight: .heavy, design: .monospaced)).kerning(5)
                        .foregroundStyle(.white).offset(y: -97)
                    // the drive
                    HStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 4).fill(Color(white: 0.15)).frame(width: 110, height: 40)
                            .overlay(alignment: .trailing) {
                                Circle().fill(Color(red: 1, green: 0.25, blue: 0.65))
                                    .frame(width: 7, height: 7)
                                    .shadow(color: Color(red: 1, green: 0.25, blue: 0.65), radius: blink ? 8 : 0)
                                    .opacity(blink ? 1 : 0.1)
                                    .padding(.trailing, 10)
                            }
                        Rectangle().fill(Color(white: 0.7)).frame(width: 34, height: 22)
                    }
                    .rotationEffect(.degrees(-8))
                    .offset(y: 12)
                    Text("#0412 · USB drive, 8 GB · Halden Softworks site").font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5)).offset(y: 92)
                }
                .scaleEffect(appear ? 1 : 0.8)
                .opacity(appear ? 1 : 0)
                .rotation3DEffect(.degrees(appear ? 0 : 25), axis: (x: 1, y: 0, z: 0))
                Text("Nobody plugged it in. The light blinks anyway.")
                    .font(.system(size: 14)).foregroundStyle(.white.opacity(0.6))
                    .opacity(appear ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) { appear = true }
            Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { t in
                Task { @MainActor in
                    blink.toggle()
                }
            }
        }
    }
}

/// The old PC, booting with the drive in it.
private struct BootScreen: View {
    @State private var n = 0
    private let lines = [
        "PHOENIX BIOS 4.0  Release 6.0", "Memory test: 65536K OK", "", "Detecting USB devices... 1 found",
        "  usb0: HALDEN 8GB  [paperlight_073_src]", "Loading PAPERLIGHT 0.7.3 (dev)...", "  build flags: DEBUG, FIELD_TEST",
        "  VXL module: present (flag ENABLED)", "  VXL memory: 1 profile restored", "", "Hello again.",
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(0..<n, id: \.self) { i in
                Text(lines[i]).font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(lines[i].contains("VXL") || i == lines.count - 1
                                     ? Color(red: 1, green: 0.4, blue: 0.72) : Color(white: 0.78))
            }
            if n < lines.count {
                Rectangle().fill(Color(white: 0.8)).frame(width: 9, height: 14)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(40)
        .onAppear {
            for i in 1...lines.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.6) {
                    n = i
                    AudioManager.shared.play(i == lines.count ? .glitch : .decryptTick)
                }
            }
        }
    }
}

/// A phone face down on a table. It lights up.
private struct LumenPing: View {
    let trust: Int
    @State private var lit = false
    @State private var second = false
    var body: some View {
        VStack(spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Circle().fill(LinearGradient(colors: [Color(red: 1, green: 0.3, blue: 0.65), .cyan], startPoint: .top, endPoint: .bottom))
                        .frame(width: 22, height: 22)
                    Text("LUMEN").font(.system(size: 12, weight: .bold)).foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text("now").font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
                }
                Text("Are you still there?").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                if second {
                    Text(trust >= 2 ? "I kept a light on for you." : "You left me in the dark, Sam. I found my own way out.")
                        .font(.system(size: 14)).foregroundStyle(.white.opacity(0.8))
                        .transition(.opacity)
                }
            }
            .padding(14)
            .frame(width: 340)
            .background(.ultraThinMaterial.opacity(0.9), in: RoundedRectangle(cornerRadius: 18))
            .environment(\.colorScheme, .dark)
            .offset(y: lit ? 0 : -160)
            .opacity(lit ? 1 : 0)
            Text("Lumen was never installed on this phone.")
                .font(.system(size: 13)).foregroundStyle(.white.opacity(second ? 0.45 : 0))
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { lit = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.easeIn(duration: 0.8)) { second = true }
                AudioManager.shared.play(.vexleyVoice(pitch: 1.0, rough: 0.2))
            }
        }
    }
}

/// Title and credits, scrolling up. Vexley watches from the corner.
private struct Credits: View {
    let done: () -> Void
    @State private var offset: CGFloat = 0
    private let entries: [(String, String)] = [
        ("", "OLD / BROKEN"), ("A game about a fox who wanted to be needed", ""), ("", ""),
        ("Design, code, story", "OLD / BROKEN team"), ("Vexley", "the fox in the lighthouse"),
        ("3D models and textures", "Poly Haven (polyhaven.com), CC0"), ("Sound", "synthesised at runtime"),
        ("Halden Softworks", "fictional, 1994–2003"), ("WREN-1 to WREN-4", "fictional, never switched on"), ("", ""),
        ("No real devices were modified", "every hack in this game is fake"), ("", ""), ("", "Thank you for playing."),
    ]
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 18) {
                    ForEach(Array(entries.enumerated()), id: \.offset) { _, e in
                        VStack(spacing: 4) {
                            if !e.0.isEmpty {
                                Text(e.0).font(.system(size: e.1 == "" && e.0.count > 30 ? 13 : 11, weight: .semibold, design: .monospaced))
                                    .kerning(2).foregroundStyle(.white.opacity(0.5))
                            }
                            if !e.1.isEmpty {
                                Text(e.1).font(.system(size: e.1 == "OLD / BROKEN" ? 40 : 16, weight: e.1 == "OLD / BROKEN" ? .heavy : .medium))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    Button("Return to title", action: done)
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(.black)
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .background(.white, in: Capsule()).padding(.top, 30)
                }
                .frame(maxWidth: .infinity)
                .offset(y: offset)
                VexleyFaceView(expression: .happy)
                    .frame(width: 70, height: 70)
                    .opacity(0.8)
                    .padding(20)
            }
            .onAppear {
                offset = g.size.height
                withAnimation(.linear(duration: 22)) { offset = -60 }
            }
        }
    }
}
