import SwiftUI

/// PAPERLIGHT: Reawakened — the low-effort remaster. It's meant to be disappointing:
/// popups, an energy meter, a season pass, and a generic tap-the-coins minigame
/// standing in for the game the protagonist remembers.
struct RemasterApp: View {
    @EnvironmentObject var session: GameSession
    @EnvironmentObject var comp: ComputerSimulationManager

    enum Phase { case splash, popups, menu, playing, results, outOfEnergy }

    @State private var phase: Phase = .splash
    @State private var popupIndex = 0
    @State private var energy = 3
    @State private var coins = 120
    @State private var gems = 0
    @State private var targets: [CoinTarget] = []
    @State private var timeLeft = 10.0
    @State private var score = 0
    @State private var rounds = 0

    struct CoinTarget: Identifiable { let id = UUID(); let x: CGFloat; let y: CGFloat; let gem: Bool }

    private let popups: [(String, String, String)] = [
        ("DAILY LOGIN!", "Day 1 of 30. Come back tomorrow for 5 💎!", "Claim"),
        ("SEASON PASS", "Unlock 100 tiers of exclusive cosmetics for just $19.99!", "Maybe later"),
        ("LIMITED BUNDLE", "Lantern Legends Pack — 72% OFF! Ends in 03:59:12", "No thanks"),
    ]

    private let tick = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: [Color(red: 0.95, green: 0.3, blue: 0.6), Color(red: 0.35, green: 0.15, blue: 0.9)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                switch phase {
                case .splash: splash
                case .popups, .menu: menu
                case .playing: playfield(geo.size)
                case .results: results
                case .outOfEnergy: outOfEnergy
                }
                if phase == .popups { popup }
                topBar.frame(maxHeight: .infinity, alignment: .top)
            }
            .foregroundStyle(.white)
        }
        .onAppear {
            AudioManager.shared.play(.fanfare)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                if phase == .splash { phase = .popups }
            }
            RemasterHooks.onClose = {
                let s = GameSession.shared
                if s.has("remaster_played") && !s.has("remaster_closed_once") {
                    s.set("remaster_closed_once")
                    s.say("That's not PAPERLIGHT. That's a slot machine wearing its skin.")
                    s.say("I'm uninstalling it.")
                }
            }
        }
        .onReceive(tick) { _ in update() }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Label("\(energy)/5", systemImage: "bolt.fill")
            Label("\(gems)", systemImage: "diamond.fill")
            Label("\(coins)", systemImage: "circle.fill").foregroundStyle(.yellow)
            Spacer()
            Text("+ BUY GEMS").font(.system(size: 9, weight: .heavy)).padding(.horizontal, 8).padding(.vertical, 3)
                .background(.yellow, in: Capsule()).foregroundStyle(.black)
                .onTapGesture { session.say("Absolutely not.") }
        }
        .font(.system(size: 11, weight: .bold))
        .padding(8)
        .background(.black.opacity(0.25))
    }

    private var splash: some View {
        VStack(spacing: 6) {
            Text("BRIGHTLOOP").font(.system(size: 12, weight: .heavy)).kerning(4)
            Text("PAPERLIGHT").font(.system(size: 34, weight: .black)).italic()
            Text("R E A W A K E N E D").font(.system(size: 13, weight: .heavy))
        }
        .shadow(color: .black.opacity(0.4), radius: 0, x: 3, y: 3)
    }

    private var menu: some View {
        VStack(spacing: 10) {
            Text("PAPERLIGHT").font(.system(size: 30, weight: .black)).italic()
                .shadow(color: .black.opacity(0.4), radius: 0, x: 3, y: 3)
            Button {
                guard energy > 0 else { phase = .outOfEnergy; return }
                startRound()
            } label: {
                Text("PLAY  ⚡1").font(.system(size: 18, weight: .black))
                    .padding(.horizontal, 40).padding(.vertical, 10)
                    .background(Color.yellow, in: Capsule())
                    .foregroundStyle(.black)
            }
            .buttonStyle(.plain)
            HStack(spacing: 10) {
                menuChip("SHOP"); menuChip("PASS"); menuChip("EVENTS"); menuChip("LANTERN ROYALE")
            }
        }
    }

    private func menuChip(_ t: String) -> some View {
        Text(t).font(.system(size: 9, weight: .heavy)).padding(.horizontal, 8).padding(.vertical, 5)
            .background(.white.opacity(0.2), in: Capsule())
            .onTapGesture {
                AudioManager.shared.play(.uiError)
                session.say(t == "LANTERN ROYALE" ? "A battle royale. In PAPERLIGHT." : "Locked. Of course it's locked.")
            }
    }

    private var popup: some View {
        let p = popups[min(popupIndex, popups.count - 1)]
        return ZStack {
            Color.black.opacity(0.45)
            VStack(spacing: 10) {
                Text(p.0).font(.system(size: 20, weight: .black))
                Text(p.1).font(.system(size: 12, weight: .semibold)).multilineTextAlignment(.center)
                Button {
                    AudioManager.shared.play(.coin)
                    if popupIndex == 0 { gems += 5 }
                    popupIndex += 1
                    if popupIndex == 1 { session.say("...Seriously?") }
                    if popupIndex >= popups.count { phase = .menu }
                } label: {
                    Text(p.2).font(.system(size: 13, weight: .heavy)).padding(.horizontal, 22).padding(.vertical, 7)
                        .background(Color.yellow, in: Capsule()).foregroundStyle(.black)
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .frame(width: 280)
            .background(LinearGradient(colors: [.orange, .pink], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white, lineWidth: 3))
        }
    }

    private func playfield(_ size: CGSize) -> some View {
        ZStack {
            Text("Tap the coins! \(Int(ceil(timeLeft)))s").font(.system(size: 13, weight: .heavy))
                .frame(maxHeight: .infinity, alignment: .top).padding(.top, 40)
            ForEach(targets) { t in
                Button {
                    targets.removeAll { $0.id == t.id }
                    score += t.gem ? 5 : 1
                    AudioManager.shared.play(.coin)
                } label: {
                    Image(systemName: t.gem ? "diamond.fill" : "circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(t.gem ? Color.cyan : Color.yellow)
                        .shadow(radius: 3)
                }
                .buttonStyle(.plain)
                .position(x: t.x * (size.width - 60) + 30, y: t.y * (size.height - 110) + 80)
            }
        }
    }

    private var results: some View {
        VStack(spacing: 10) {
            Text("LEVEL 1 COMPLETE!").font(.system(size: 22, weight: .black))
            Text("★ ★ ☆").font(.system(size: 26))
            Text("+\(score) coins").font(.system(size: 13, weight: .bold))
            Text("Level 2 unlocks in 4h — or skip now for 30 💎").font(.system(size: 11, weight: .semibold))
            Button {
                phase = energy > 0 ? .menu : .outOfEnergy
            } label: {
                Text("CONTINUE").font(.system(size: 13, weight: .heavy)).padding(.horizontal, 22).padding(.vertical, 7)
                    .background(Color.yellow, in: Capsule()).foregroundStyle(.black)
            }
            .buttonStyle(.plain)
        }
    }

    private var outOfEnergy: some View {
        VStack(spacing: 10) {
            Image(systemName: "bolt.slash.fill").font(.system(size: 40))
            Text("OUT OF ENERGY!").font(.system(size: 22, weight: .black))
            Text("Refill now for 50 💎 or wait 4 hours.").font(.system(size: 12, weight: .semibold))
            Text("You have \(gems) 💎").font(.system(size: 11))
        }
        .onAppear {
            if !session.has("remaster_energy_out") {
                session.set("remaster_energy_out")
                session.say("Yeah. I'm done.")
            }
        }
    }

    private func startRound() {
        energy -= 1
        score = 0
        timeLeft = 10
        targets = []
        phase = .playing
        AudioManager.shared.play(.uiConfirm)
    }

    private func update() {
        guard phase == .playing else { return }
        timeLeft -= 0.1
        if Int.random(in: 0..<4) == 0 && targets.count < 5 {
            targets.append(CoinTarget(x: .random(in: 0...1), y: .random(in: 0...1), gem: Int.random(in: 0..<12) == 0))
        }
        if targets.count > 3 && Int.random(in: 0..<6) == 0 { targets.removeFirst() }
        if timeLeft <= 0 {
            coins += score
            rounds += 1
            targets = []
            phase = .results
            AudioManager.shared.play(.fanfare)
            if !session.has("remaster_played") {
                session.set("remaster_played")
                session.say("Where's the lighthouse? Where's ANY of it?")
            }
        }
    }
}
