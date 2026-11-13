import SwiftUI

/// Full-screen device views in the apartment: the TV and the phone.
enum DeviceOverlay: Equatable { case tv, phone }

// MARK: - TV

/// NEWSLINE 24 and a few other channels. The Lumen story is fake, and it shows if you
/// look: the anchor's name, the ticker, a date that doesn't match.
struct TVView: View {
    @EnvironmentObject var session: GameSession
    @State private var channel = 1
    @State private var staticBurst = false
    @State private var ticker = false
    @State private var watched = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            GeometryReader { g in
                ZStack {
                    screen(g.size)
                    if staticBurst { TVStatic().transition(.opacity) }
                    Scanlines(spacing: 3).opacity(0.12).allowsHitTesting(false)
                    RadialGradient(colors: [.clear, .black.opacity(0.5)], center: .center, startRadius: g.size.width * 0.3, endRadius: g.size.width * 0.7)
                        .allowsHitTesting(false)
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 50).padding(.vertical, 24)
            VStack {
                HStack {
                    Spacer()
                    Button { session.deviceOverlay = nil; AudioManager.shared.play(.uiClick) } label: {
                        Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 40, height: 40).background(.white.opacity(0.15), in: Circle())
                    }
                }
                Spacer()
                HStack(spacing: 12) {
                    Button { change(-1) } label: { Image(systemName: "chevron.down") }
                    Text("CH \(channel)").font(.system(size: 12, weight: .bold, design: .monospaced))
                    Button { change(1) } label: { Image(systemName: "chevron.up") }
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(.white.opacity(0.12), in: Capsule())
            }
            .padding(12)
        }
        .onAppear { ticker = true }
        .onReceive(timer) { _ in
            if channel == 1 { watched += 1 }
            if watched == 5 { StoryDirector.shared.sawNews() }
        }
    }

    private func change(_ d: Int) {
        AudioManager.shared.play(.glitch)
        withAnimation(.easeOut(duration: 0.08)) { staticBurst = true }
        channel = (channel - 1 + d + 4) % 4 + 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { withAnimation { staticBurst = false } }
    }

    @ViewBuilder private func screen(_ size: CGSize) -> some View {
        switch channel {
        case 1: news(size)
        case 2:
            ZStack {
                TVStatic()
                VexleyFaceView(expression: .neutral).frame(width: 160, height: 160).opacity(0.06)
            }
        case 3:
            ZStack {
                LinearGradient(colors: [Color(red: 0.95, green: 0.8, blue: 0.5), Color(red: 0.8, green: 0.4, blue: 0.2)], startPoint: .top, endPoint: .bottom)
                VStack(spacing: 6) {
                    Text("COOK IT SLOW").font(.system(size: 26, weight: .black, design: .rounded)).foregroundStyle(.white)
                    Text("\"...and you let that simmer for another forty minutes.\"").font(.system(size: 13, design: .serif)).italic().foregroundStyle(.white.opacity(0.9))
                }
            }
        default:
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.3)
                Text("NO SIGNAL").font(.system(size: 22, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    private func news(_ size: CGSize) -> some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [Color(red: 0.05, green: 0.1, blue: 0.3), Color(red: 0.02, green: 0.03, blue: 0.12)], startPoint: .top, endPoint: .bottom)
            // studio: anchor silhouette and the Lumen graphic
            HStack(alignment: .bottom) {
                AnchorSilhouette()
                    .frame(width: size.width * 0.32, height: size.height * 0.7)
                    .padding(.leading, size.width * 0.06)
                Spacer()
                VStack(spacing: 6) {
                    LumenOrb(size: min(size.height * 0.32, 110), fox: true)
                    Text("LUMEN").font(.system(size: 20, weight: .heavy, design: .rounded)).kerning(4).foregroundStyle(.white)
                    Text("the assistant that knows you").font(.system(size: 11, design: .rounded)).foregroundStyle(.white.opacity(0.7))
                }
                .padding(.trailing, size.width * 0.08)
                .padding(.bottom, size.height * 0.3)
            }
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text(" NEWSLINE 24 ").font(.system(size: 11, weight: .black)).foregroundStyle(.white)
                        .padding(.vertical, 4).background(Color.red)
                    Text("  BREAKING: \"Everyone is talking about it\" — new assistant LUMEN goes viral overnight")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(.black).lineLimit(1)
                        .padding(.vertical, 4).frame(maxWidth: .infinity, alignment: .leading).background(Color.white)
                }
                HStack(spacing: 6) {
                    Text("VERA X. LEY · TECHNOLOGY").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                    Text("THU · 9:00 AM · 1999").font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.6))
                    Spacer()
                }
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(Color(red: 0.05, green: 0.15, blue: 0.45))
                GeometryReader { g in
                    Text("LUMEN is free · LUMEN learns what you love · developers \"with roots in 1990s game design\" · download at lumen-ai.com · LUMEN is yours · LUMEN is free · ")
                        .font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(.yellow)
                        .fixedSize()
                        .offset(x: ticker ? -g.size.width * 1.6 : g.size.width)
                        .animation(.linear(duration: 16).repeatForever(autoreverses: false), value: ticker)
                }
                .frame(height: 16).clipped()
                .background(Color.black)
            }
        }
    }
}

struct AnchorSilhouette: View {
    @State private var talk = false
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: w * 0.3).fill(Color(red: 0.12, green: 0.14, blue: 0.22))
                    .frame(width: w * 0.85, height: h * 0.5)
                Circle().fill(Color(red: 0.16, green: 0.18, blue: 0.27))
                    .frame(width: w * 0.42, height: w * 0.42)
                    .offset(y: -h * 0.48)
                    .rotationEffect(.degrees(talk ? 1.5 : -1.5), anchor: .bottom)
            }
            .frame(width: w, height: h, alignment: .bottom)
        }
        .onAppear { withAnimation(.easeInOut(duration: 0.7).repeatForever()) { talk = true } }
    }
}

struct TVStatic: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20)) { tl in
            Canvas { ctx, size in
                var rng = SeededRandom(seed: UInt64(tl.date.timeIntervalSinceReferenceDate * 20))
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(white: 0.3)))
                for _ in 0..<500 {
                    let x = CGFloat(rng.next() % 1000) / 1000 * size.width
                    let y = CGFloat(rng.next() % 1000) / 1000 * size.height
                    ctx.fill(Path(CGRect(x: x, y: y, width: 4, height: 2)), with: .color(Color(white: Double(rng.next() % 100) / 100)))
                }
            }
        }
    }
}

struct SeededRandom {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return state
    }
}

/// Lumen's glowing logo. With `fox`, the fox face shows through the glow.
struct LumenOrb: View {
    let size: CGFloat
    var fox = false
    @State private var spin = false
    var body: some View {
        ZStack {
            Circle().fill(AngularGradient(colors: [Color(red: 0.4, green: 0.85, blue: 1), Color(red: 1, green: 0.45, blue: 0.75),
                                                   Color(red: 0.5, green: 0.5, blue: 1), Color(red: 0.4, green: 0.85, blue: 1)], center: .center))
                .blur(radius: size * 0.08)
                .rotationEffect(.degrees(spin ? 360 : 0))
            Circle().fill(Color.black.opacity(0.35)).padding(size * 0.12)
            if fox {
                VexleyFaceView(expression: .happy).padding(size * 0.14).clipShape(Circle())
            }
        }
        .frame(width: size, height: size)
        .onAppear { withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) { spin = true } }
    }
}

// MARK: - Phone

struct PhoneView: View {
    @EnvironmentObject var session: GameSession
    @State private var app: String?

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
                .onTapGesture { close() }
            VStack(spacing: 0) {
                HStack {
                    Text(session.clockText).font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Image(systemName: "wifi"); Image(systemName: "battery.75")
                }
                .font(.system(size: 10))
                .foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 4)
                Group {
                    switch app {
                    case "chatter": ChatterView(compact: true)
                    case "lumen": LumenView(compact: true)
                    case "store": PhoneStoreView()
                    default: home
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                Capsule().fill(.white.opacity(0.6)).frame(width: 90, height: 4).padding(.vertical, 6)
                    .contentShape(Rectangle().inset(by: -10))
                    .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { if app == nil { close() } else { app = nil } } }
            }
            .frame(width: 250)
            .frame(maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 34).fill(Color(red: 0.04, green: 0.05, blue: 0.07)))
            .overlay(RoundedRectangle(cornerRadius: 34).stroke(Color(white: 0.3), lineWidth: 4))
            .clipShape(RoundedRectangle(cornerRadius: 34))
            .padding(.vertical, 10)
            .transition(.move(edge: .bottom))
        }
        .onAppear { if session.has("phone_lumen_installed") && StoryDirector.shared.dialogue.isActive { app = "lumen" } }
    }

    private func close() {
        AudioManager.shared.play(.uiClick)
        session.deviceOverlay = nil
    }

    private var home: some View {
        VStack {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 18) {
                icon("chatter", "Chatter", "bubble.left.and.bubble.right.fill", .green)
                if session.has("phone_lumen_installed") { icon("lumen", "Lumen", "sparkle", Color(red: 0.55, green: 0.85, blue: 1)) }
                if session.day >= 5 { icon("store", "Store", "bag.fill", .blue) }
                icon("clock", "Clock", "clock.fill", .gray)
                icon("photos", "Photos", "photo.fill", .orange)
            }
            .padding(18)
            Spacer()
        }
        .background(LinearGradient(colors: [Color(red: 0.12, green: 0.1, blue: 0.25), Color(red: 0.03, green: 0.03, blue: 0.08)], startPoint: .top, endPoint: .bottom))
    }

    private func icon(_ id: String, _ name: String, _ sf: String, _ c: Color) -> some View {
        Button {
            AudioManager.shared.play(.uiClick)
            switch id {
            case "clock": session.say("\(session.clockText). Day \(session.day) of this.")
            case "photos": session.say("Mostly screenshots. And Theo's dog.")
            default: withAnimation(.easeOut(duration: 0.2)) { app = id }
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: sf).font(.system(size: 20)).foregroundStyle(.white)
                    .frame(width: 46, height: 46).background(RoundedRectangle(cornerRadius: 11).fill(c))
                Text(name).font(.system(size: 9)).foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
    }
}

/// A tiny app store (Chapter 5): Lumen appears once its "review" is over.
struct PhoneStoreView: View {
    @EnvironmentObject var session: GameSession
    @State private var installing: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Store").font(.system(size: 20, weight: .bold))
            HStack(spacing: 10) {
                LumenOrb(size: 52, fox: session.has("lumen_fox"))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lumen").font(.system(size: 14, weight: .semibold))
                    Text(session.has("lumen_store_live") ? "Lumen Labs · Productivity" : "In review").font(.system(size: 10)).opacity(0.6)
                }
                Spacer()
                if session.has("phone_lumen_installed") {
                    Text("OPEN").font(.system(size: 11, weight: .bold)).padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Capsule().fill(.white.opacity(0.15)))
                } else if let p = installing {
                    ProgressView(value: p).frame(width: 50)
                } else if session.has("lumen_store_live") {
                    Button { install() } label: {
                        Text("GET").font(.system(size: 11, weight: .bold)).padding(.horizontal, 14).padding(.vertical, 5)
                            .background(Capsule().fill(Color.blue))
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("SOON").font(.system(size: 11, weight: .bold)).opacity(0.5)
                }
            }
            if session.has("lumen_store_live") {
                Text("\"I've been using it for a week. It's honestly impressive.\" — Theo").font(.system(size: 10)).italic().opacity(0.6)
                Text("★★★★★ 4.9 · 1 rating").font(.system(size: 10)).opacity(0.6)
            }
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(16)
    }

    private func install() {
        installing = 0
        Task {
            for i in 1...20 {
                try? await Task.sleep(nanoseconds: 90_000_000)
                installing = Double(i) / 20
            }
            installing = nil
            session.set("phone_lumen_installed")
            AudioManager.shared.play(.downloadDone)
        }
    }
}

// MARK: - Lumen

/// The assistant. Setup (pick a look; only the fox ever loads), then chat with suggestions.
struct LumenView: View {
    @EnvironmentObject var session: GameSession
    @ObservedObject private var director = StoryDirector.shared
    var compact = false
    @State private var picked: String?
    @State private var progress: [String: Int] = [:]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.04, green: 0.06, blue: 0.12), Color(red: 0.08, green: 0.05, blue: 0.14)], startPoint: .top, endPoint: .bottom)
            if session.has("lumen_fox") { chat } else { setup }
        }
        .foregroundStyle(.white)
    }

    private var setup: some View {
        VStack(spacing: 10) {
            LumenOrb(size: compact ? 54 : 64)
            Text("Hi! I'm Lumen.").font(.system(size: 18, weight: .semibold, design: .rounded))
            Text("Choose how I look. You can change it later.").font(.system(size: 11)).opacity(0.7)
            let looks = [("orb", "Orb", "circle.hexagongrid.fill"), ("crane", "Paper crane", "bird.fill"),
                         ("fox", "Fox", "pawprint.fill"), ("minimal", "Minimal", "circle.fill")]
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: compact ? 2 : 4), spacing: 8) {
                ForEach(looks, id: \.0) { l in
                    Button { pick(l.0) } label: {
                        VStack(spacing: 6) {
                            if l.0 == "fox" {
                                VexleyFaceView(expression: .happy).frame(width: 44, height: 44)
                            } else {
                                Image(systemName: l.2).font(.system(size: 26)).frame(width: 44, height: 44).opacity(0.85)
                            }
                            Text(l.1).font(.system(size: 11, weight: .semibold))
                            if let p = progress[l.0] {
                                Text(p < 0 ? "Theme server unavailable" : "Downloading \(p)%").font(.system(size: 8)).opacity(0.6)
                            }
                        }
                        .frame(maxWidth: .infinity).padding(8)
                        .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(picked == l.0 ? 0.18 : 0.06)))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(picked == l.0 ? Color(red: 0.55, green: 0.85, blue: 1) : .clear))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            if picked == "fox" {
                Button { StoryDirector.shared.lumenChoseFox() } label: {
                    Text("Use this look").font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 20).padding(.vertical, 8)
                        .background(Capsule().fill(Color(red: 0.3, green: 0.6, blue: 1)))
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(10)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: picked)
    }

    private func pick(_ id: String) {
        AudioManager.shared.play(.uiClick)
        picked = id
        guard id != "fox", progress[id] == nil else { return }
        progress[id] = 0
        Task {
            for p in [3, 7, 9, 9, 9] {
                try? await Task.sleep(nanoseconds: 450_000_000)
                progress[id] = p
            }
            try? await Task.sleep(nanoseconds: 900_000_000)
            progress[id] = -1
        }
    }

    private var chat: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                LumenOrb(size: 34, fox: true)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Lumen").font(.system(size: 14, weight: .bold, design: .rounded))
                    Text(director.dialogue.isActive ? "speaking…" : "online").font(.system(size: 9)).opacity(0.6)
                }
                Spacer()
            }
            .padding(.horizontal, 12).padding(.top, 10)
            Spacer()
            if !director.dialogue.isActive {
                let s = director.lumenSuggestions()
                LazyVGrid(columns: [GridItem(.adaptive(minimum: compact ? 100 : 140))], spacing: 6) {
                    ForEach(s, id: \.0) { item in
                        Button { director.start(item.1) } label: {
                            Text(item.0).font(.system(size: 11, weight: .medium)).multilineTextAlignment(.center)
                                .padding(.horizontal, 10).padding(.vertical, 7).frame(maxWidth: .infinity)
                                .background(Capsule().fill(.white.opacity(0.08)))
                                .overlay(Capsule().stroke(Color(red: 0.55, green: 0.85, blue: 1).opacity(0.5)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
            }
            StoryDialoguePanel(style: .assistant)
                .padding(.horizontal, 8).padding(.bottom, 8)
        }
        .modifier(InlineDialogueHost())
    }
}
