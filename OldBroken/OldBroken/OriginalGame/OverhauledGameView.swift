import SwiftUI

/// CHAPTER 2: the game after Vexley rewrote it overnight. Polished, animated, warm,
/// and much more interesting than the original. Every part of it was made for one player.
struct OverhauledGameView: View {
    @EnvironmentObject var comp: ComputerSimulationManager
    @EnvironmentObject var session: GameSession
    @ObservedObject private var director = StoryDirector.shared
    @State private var hover: String?
    @State private var shownMessages = 0

    var body: some View {
        ZStack {
            if director.vxMode == .playing && session.day == 2 {
                playing
            } else {
                menu
            }
            if director.messagesOpen { messages.transition(.opacity.combined(with: .scale(scale: 0.97))) }
            VStack {
                Spacer()
                StoryDialoguePanel(style: .vx)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 10)
            }
            .modifier(InlineDialogueHost())
            windowButtons.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .background(Color.black)
        .animation(.easeInOut(duration: 0.45), value: director.vxMode)
        .animation(.easeInOut(duration: 0.3), value: director.messagesOpen)
        .onAppear { AudioManager.shared.setScene(.retro) }
        .onDisappear { if session.screen == .desktop { AudioManager.shared.setScene(.desktop) } }
    }

    // MARK: Menu

    private var menu: some View {
        GeometryReader { geo in
            ZStack {
                LanternSky()
                HStack(alignment: .center, spacing: 0) {
                    VStack(alignment: .leading, spacing: 10) {
                        TitleShimmer()
                        Text(session.day == 2 ? "VX EDITION · rebuilt overnight" : "VX EDITION")
                            .font(.system(size: 10, weight: .semibold, design: .rounded)).kerning(2)
                            .foregroundStyle(.white.opacity(0.65))
                            .padding(.bottom, 8)
                        menuButton("continue", "Continue", icon: "play.fill") {
                            if session.day == 2 { director.vxMode = .playing } else { director.talkToVexley() }
                        }
                        menuButton("talk", "Talk to Vexley", icon: "bubble.left.and.bubble.right.fill") { director.talkToVexley() }
                        menuButton("gallery", "Gallery", icon: "photo.on.rectangle") { director.start(session.day == 2 ? "ch2_gallery" : "vx_absent") }
                        menuButton("classic", "Classic mode", icon: "clock.arrow.circlepath") { director.start(session.day == 2 ? "ch2_classic" : "vx_absent") }
                        menuButton("quit", "Quit", icon: "power") {
                            if let id = comp.windows.first(where: { $0.app == .oldgame })?.id { comp.close(id) }
                        }
                    }
                    .padding(.leading, 34)
                    .frame(width: geo.size.width * 0.5, alignment: .leading)
                    Spacer()
                    if session.day == 2 {
                        FloatingVexley(expression: director.dialogue.isActive ? director.dialogue.expression : .happy)
                            .frame(width: min(geo.size.height * 0.62, 230), height: min(geo.size.height * 0.62, 230))
                            .padding(.trailing, 40)
                            .padding(.bottom, 40)
                    }
                }
                if session.has("ate_dinner") && !session.has("ch2_read_log") && !director.messagesOpen && session.day == 2 {
                    Button { director.messagesOpen = true } label: {
                        Label("\(director.awayMessages().count) new messages", systemImage: "envelope.badge.fill")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Capsule().fill(Color(red: 1, green: 0.35, blue: 0.65)))
                            .shadow(color: .pink.opacity(0.7), radius: 10)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 14)
                }
            }
        }
    }

    private func menuButton(_ id: String, _ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button {
            AudioManager.shared.play(.retroSelect)
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { hover = id }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { hover = nil }
            action()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 12, weight: .bold)).frame(width: 18)
                Text(title).font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .frame(width: 220, alignment: .leading)
            .background(
                Capsule().fill(LinearGradient(colors: [Color(red: 1, green: 0.35, blue: 0.68).opacity(hover == id ? 0.9 : 0.38),
                                                       Color(red: 0.3, green: 0.85, blue: 1).opacity(hover == id ? 0.7 : 0.18)],
                                              startPoint: .leading, endPoint: .trailing))
            )
            .overlay(Capsule().stroke(.white.opacity(0.35), lineWidth: 1))
            .scaleEffect(hover == id ? 1.05 : 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: Playing (the original map, framed)

    private var playing: some View {
        ZStack(alignment: .top) {
            LanternSky(dim: 0.55)
            ClassicOldGameView(embedded: true)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(
                    LinearGradient(colors: [Color(red: 1, green: 0.4, blue: 0.72), Color(red: 0.3, green: 0.9, blue: 1)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 3))
                .shadow(color: Color(red: 1, green: 0.4, blue: 0.72).opacity(0.5), radius: 14)
                .padding(.horizontal, 46).padding(.top, 30).padding(.bottom, 8)
            HStack(spacing: 8) {
                Button { director.vxMode = .menu } label: {
                    Label("Menu", systemImage: "chevron.left").font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(.white.opacity(0.15)))
                }
                .buttonStyle(.plain)
                Text("PAPERLIGHT · VX").font(.system(size: 10, weight: .heavy, design: .rounded)).kerning(2)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.top, 5)
        }
    }

    // MARK: Messages he wrote while you were away

    private var messages: some View {
        let list = director.awayMessages()
        return ZStack {
            Color.black.opacity(0.55)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "envelope.open.fill").foregroundStyle(Color(red: 1, green: 0.45, blue: 0.75))
                    Text("While you were away").font(.system(size: 14, weight: .bold, design: .rounded))
                    Spacer()
                    Button("Close") { director.closeMessages() }
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .opacity(shownMessages >= list.count ? 1 : 0.3)
                        .disabled(shownMessages < list.count)
                }
                .foregroundStyle(.white)
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(0..<list.count, id: \.self) { i in
                                if i < shownMessages {
                                    HStack(alignment: .top, spacing: 8) {
                                        Text(list[i].0).font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.45))
                                            .frame(width: 52, alignment: .leading)
                                        Text(list[i].1).font(.system(size: 12, design: .rounded)).foregroundStyle(.white)
                                            .padding(.horizontal, 10).padding(.vertical, 6)
                                            .background(RoundedRectangle(cornerRadius: 10).fill(Color(red: 0.35, green: 0.08, blue: 0.25)))
                                    }
                                    .id(i)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                                }
                            }
                        }
                    }
                    .onChange(of: shownMessages) { _, n in withAnimation { proxy.scrollTo(n - 1, anchor: .bottom) } }
                }
            }
            .padding(14)
            .frame(maxWidth: 460, maxHeight: 270)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 0.08, green: 0.03, blue: 0.09)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(red: 1, green: 0.45, blue: 0.75).opacity(0.6)))
        }
        .onAppear {
            shownMessages = 0
            for i in 1...list.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.9) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { shownMessages = i }
                    AudioManager.shared.play(.notification)
                }
            }
        }
    }

    private var windowButtons: some View {
        HStack(spacing: 2) {
            Button {
                if let id = comp.windows.first(where: { $0.app == .oldgame })?.id { comp.minimize(id) }
            } label: { Image(systemName: "minus").frame(width: 30, height: 26) }
            Button {
                if let id = comp.windows.first(where: { $0.app == .oldgame })?.id { comp.close(id) }
            } label: { Image(systemName: "xmark").frame(width: 30, height: 26) }
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.white.opacity(0.7))
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
        .padding(4)
    }
}

/// Animated night sky over Lantern Town: drifting paper lanterns, a sweeping lighthouse beam.
struct LanternSky: View {
    var dim: Double = 0

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let sky = Gradient(colors: [Color(red: 0.04, green: 0.05, blue: 0.2), Color(red: 0.32, green: 0.1, blue: 0.36),
                                            Color(red: 0.95, green: 0.45, blue: 0.5)])
                ctx.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .linearGradient(sky, startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
                // stars
                for i in 0..<40 {
                    let x = CGFloat((i * 97) % 1000) / 1000 * size.width
                    let y = CGFloat((i * 53) % 470) / 1000 * size.height
                    let a = 0.35 + 0.35 * sin(t * 1.3 + Double(i))
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)), with: .color(.white.opacity(a)))
                }
                // sea
                let seaTop = size.height * 0.78
                ctx.fill(Path(CGRect(x: 0, y: seaTop, width: size.width, height: size.height - seaTop)),
                         with: .color(Color(red: 0.05, green: 0.06, blue: 0.2)))
                // lighthouse + beam
                let lx = size.width * 0.82, top = size.height * 0.42
                let beamAngle = sin(t * 0.6) * 0.9
                var beam = Path()
                beam.move(to: CGPoint(x: lx, y: top))
                beam.addLine(to: CGPoint(x: lx - cos(beamAngle) * size.width, y: top - 60 + sin(beamAngle) * 80))
                beam.addLine(to: CGPoint(x: lx - cos(beamAngle) * size.width, y: top + 40 + sin(beamAngle) * 80))
                beam.closeSubpath()
                ctx.fill(beam, with: .color(Color(red: 1, green: 0.95, blue: 0.7).opacity(0.12)))
                for i in 0..<6 {
                    let r = CGRect(x: lx - 10, y: top + CGFloat(i) * 16, width: 20, height: 16)
                    ctx.fill(Path(r), with: .color(i % 2 == 0 ? .white : Color(red: 0.9, green: 0.25, blue: 0.35)))
                }
                ctx.fill(Path(ellipseIn: CGRect(x: lx - 9, y: top - 12, width: 18, height: 14)),
                         with: .color(Color(red: 1, green: 0.92, blue: 0.55)))
                // lanterns rising
                for i in 0..<14 {
                    let speed = 0.025 + Double(i % 5) * 0.008
                    let phase = (t * speed + Double(i) * 0.137).truncatingRemainder(dividingBy: 1)
                    let x = CGFloat((i * 211) % 1000) / 1000 * size.width + CGFloat(sin(t * 0.7 + Double(i)) * 12)
                    let y = size.height * (1.05 - CGFloat(phase) * 1.1)
                    let s = CGFloat(6 + (i % 4) * 3)
                    let glow = Path(ellipseIn: CGRect(x: x - s * 1.6, y: y - s * 1.6, width: s * 3.2, height: s * 3.2))
                    ctx.fill(glow, with: .color(Color(red: 1, green: 0.6, blue: 0.3).opacity(0.18)))
                    ctx.fill(Path(roundedRect: CGRect(x: x - s / 2, y: y - s * 0.7, width: s, height: s * 1.4), cornerRadius: s / 3),
                             with: .color(Color(red: 1, green: 0.78, blue: 0.45).opacity(0.9)))
                }
                if dim > 0 {
                    ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black.opacity(dim)))
                }
            }
        }
    }
}

/// The PAPERLIGHT logo with a light sweep running across it.
struct TitleShimmer: View {
    @State private var sweep = false
    var body: some View {
        Text("PAPERLIGHT")
            .font(.system(size: 40, weight: .black, design: .rounded))
            .foregroundStyle(LinearGradient(colors: [Color(red: 1, green: 0.88, blue: 0.6), Color(red: 1, green: 0.5, blue: 0.75)],
                                            startPoint: .top, endPoint: .bottom))
            .overlay(
                LinearGradient(colors: [.clear, .white.opacity(0.8), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 60)
                    .offset(x: sweep ? 180 : -180)
                    .mask(Text("PAPERLIGHT").font(.system(size: 40, weight: .black, design: .rounded)))
            )
            .shadow(color: Color(red: 1, green: 0.4, blue: 0.7).opacity(0.7), radius: 12)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: false).delay(1)) { sweep = true }
            }
    }
}

/// Vexley, large, floating and breathing, with a soft halo.
struct FloatingVexley: View {
    let expression: VexleyExpression
    @State private var bob = false
    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(red: 1, green: 0.4, blue: 0.75).opacity(0.55), .clear], center: .center, startRadius: 10, endRadius: 140))
                .scaleEffect(bob ? 1.08 : 0.95)
            VexleyFaceView(expression: expression)
                .offset(y: bob ? -6 : 6)
                .rotationEffect(.degrees(bob ? 2 : -2))
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { bob = true }
        }
    }
}
