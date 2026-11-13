import SwiftUI

/// The game launcher: store page, purchase, install, play, uninstall.
struct KestrelApp: View {
    @EnvironmentObject var comp: ComputerSimulationManager
    @EnvironmentObject var session: GameSession
    @State private var tab = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Image(systemName: "bird.fill").foregroundStyle(Color(red: 0.6, green: 0.55, blue: 1))
                tabButton("STORE", 0)
                tabButton("LIBRARY", 1)
                Spacer()
                Text(String(format: "$%.2f", session.data.wallet)).font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 12).frame(height: 34)
            .background(Color(red: 0.07, green: 0.06, blue: 0.13))
            ScrollView {
                if tab == 0 { store } else { library }
            }
            .background(Color(red: 0.1, green: 0.09, blue: 0.17))
        }
        .onAppear { if session.has("remaster_purchased") { tab = 1 } }
    }

    private func tabButton(_ t: String, _ i: Int) -> some View {
        Button { tab = i; AudioManager.shared.play(.uiClick) } label: {
            Text(t).font(.system(size: 11, weight: .bold)).kerning(1)
                .foregroundStyle(.white.opacity(tab == i ? 1 : 0.45))
        }
        .buttonStyle(.plain)
    }

    private var store: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .bottomLeading) {
                RemasterKeyArt().frame(height: 130).clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text("NEW RELEASE").font(.system(size: 9, weight: .heavy)).padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.pink, in: Capsule())
                    Text("PAPERLIGHT: Reawakened").font(.system(size: 18, weight: .heavy)).shadow(radius: 4)
                }
                .padding(10)
            }
            Text("The classic you loved, REAWAKENED for a new generation! Stunning HD visuals, a 100-tier Season Pass, daily rewards and MORE.")
                .font(.system(size: 11)).foregroundStyle(.white.opacity(0.75))
            HStack {
                Text("Overwhelmingly Negative").font(.system(size: 10, weight: .semibold)).foregroundStyle(.red.opacity(0.8))
                Spacer()
                if session.has("remaster_purchased") {
                    Text("IN LIBRARY").font(.system(size: 11, weight: .bold)).foregroundStyle(.white.opacity(0.6))
                } else {
                    Button {
                        comp.confirm("Confirm purchase", "Buy PAPERLIGHT: Reawakened for $29.99?\nWallet balance: \(String(format: "$%.2f", session.data.wallet))", button: "Buy") {
                            comp.purchaseRemaster()
                            tab = 1
                        }
                    } label: {
                        Text("BUY  $29.99").font(.system(size: 12, weight: .heavy))
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Color(red: 0.45, green: 0.35, blue: 1), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
            Divider().background(.white.opacity(0.1))
            Text("ALSO ON KESTREL").font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(0.4))
            HStack(spacing: 10) {
                fakeGame("Battle Royale Tycoon", .orange)
                fakeGame("Farm Story Idle", .green)
                fakeGame("Gacha Knights", .purple)
            }
        }
        .foregroundStyle(.white)
        .padding(12)
    }

    private func fakeGame(_ name: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            RoundedRectangle(cornerRadius: 5).fill(c.opacity(0.5)).frame(height: 44)
            Text(name).font(.system(size: 9)).lineLimit(1)
            Text("Free to play").font(.system(size: 8)).foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .onTapGesture { session.say("No.") }
    }

    private var library: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !session.has("remaster_purchased") {
                Text("Your library is empty.").font(.system(size: 12)).foregroundStyle(.white.opacity(0.5)).padding(20)
            } else {
                HStack(spacing: 12) {
                    RemasterKeyArt().frame(width: 120, height: 68).clipShape(RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 6) {
                        Text("PAPERLIGHT: Reawakened").font(.system(size: 14, weight: .bold))
                        statusLine
                        HStack(spacing: 8) { actionButtons }
                    }
                }
            }
        }
        .foregroundStyle(.white)
        .padding(12)
    }

    @ViewBuilder private var statusLine: some View {
        if let p = comp.installProgress {
            VStack(alignment: .leading, spacing: 3) {
                ProgressView(value: p).tint(Color(red: 0.55, green: 0.5, blue: 1)).frame(width: 200)
                Text("Installing… \(Int(p * 100))%  ·  9.4 GB").font(.system(size: 10)).foregroundStyle(.white.opacity(0.6))
            }
        } else if let p = comp.uninstallProgress {
            VStack(alignment: .leading, spacing: 3) {
                ProgressView(value: p).tint(.red).frame(width: 200)
                Text("Uninstalling… \(Int(p * 100))%").font(.system(size: 10)).foregroundStyle(.white.opacity(0.6))
            }
        } else if session.has("remaster_installed") {
            Text("Installed · 9.4 GB · C:/Games/Kestrel").font(.system(size: 10)).foregroundStyle(.white.opacity(0.6))
        } else {
            Text("Not installed").font(.system(size: 10)).foregroundStyle(.white.opacity(0.6))
        }
    }

    @ViewBuilder private var actionButtons: some View {
        if comp.installProgress == nil && comp.uninstallProgress == nil {
            if session.has("remaster_installed") {
                pill("PLAY", Color(red: 0.3, green: 0.75, blue: 0.4)) { comp.launch(.remaster) }
                if session.has("remaster_played") {
                    pill("UNINSTALL", Color.white.opacity(0.15)) {
                        comp.confirm("Uninstall", "Remove PAPERLIGHT: Reawakened and all of its files?", button: "Uninstall") {
                            comp.uninstallRemaster()
                        }
                    }
                }
            } else {
                pill("INSTALL", Color(red: 0.45, green: 0.35, blue: 1)) { comp.installRemaster() }
            }
        }
    }

    private func pill(_ t: String, _ c: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t).font(.system(size: 11, weight: .heavy)).padding(.horizontal, 14).padding(.vertical, 6)
                .background(c, in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }
}

/// Garish placeholder key art for the remaster. REPLACEMENT POINT: swap for a real image.
struct RemasterKeyArt: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 1, green: 0.3, blue: 0.6), Color(red: 1, green: 0.65, blue: 0.1), Color(red: 0.3, green: 0.2, blue: 1)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            ForEach(0..<8, id: \.self) { i in
                Image(systemName: i % 2 == 0 ? "sparkle" : "star.fill")
                    .foregroundStyle(.white.opacity(0.5))
                    .offset(x: CGFloat((i * 53) % 220) - 110, y: CGFloat((i * 37) % 90) - 45)
            }
            Text("REAWAKENED").font(.system(size: 22, weight: .black)).italic()
                .foregroundStyle(.white).shadow(color: .purple, radius: 0, x: 3, y: 3)
        }
    }
}

struct TaskManagerApp: View {
    @EnvironmentObject var comp: ComputerSimulationManager
    @State private var tick = 0
    @State private var selected: String?
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        let procs = comp.processes(tick: tick)
        VStack(spacing: 0) {
            HStack {
                Text("Name").frame(maxWidth: .infinity, alignment: .leading)
                Text("Publisher").frame(width: 120, alignment: .leading)
                Text("CPU").frame(width: 45, alignment: .trailing)
                Text("Memory").frame(width: 75, alignment: .trailing)
            }
            .font(.system(size: 9, weight: .semibold)).foregroundStyle(.white.opacity(0.45))
            .padding(.horizontal, 10).padding(.vertical, 5)
            ScrollView {
                VStack(spacing: 1) {
                    ForEach(procs) { p in
                        HStack {
                            Text(p.name).frame(maxWidth: .infinity, alignment: .leading)
                            Text(p.publisher).frame(width: 120, alignment: .leading)
                                .foregroundStyle(p.publisher == "(unknown)" ? .orange : .white.opacity(0.6))
                            Text(p.cpu).frame(width: 45, alignment: .trailing)
                            Text(p.memory).frame(width: 75, alignment: .trailing)
                        }
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(selected == p.name ? Color.blue.opacity(0.35) : .clear)
                        .contentShape(Rectangle())
                        .onTapGesture { selected = p.name; AudioManager.shared.play(.mouseClick) }
                    }
                }
            }
            HStack {
                Spacer()
                Button("End task") {
                    if let s = selected, let p = procs.first(where: { $0.name == s }) { comp.endTask(p) }
                }
                .disabled(selected == nil)
                .font(.system(size: 11, weight: .medium))
                .padding(8)
            }
        }
        .onReceive(timer) { _ in tick += 1 }
        .onAppear { if GameSession.shared.has("update_installed") { GameSession.shared.set("saw_vxl_procs") } }
    }
}

/// Antivirus. Its scan honestly finds nothing: OLD isn't a known signature.
struct ShieldApp: View {
    @EnvironmentObject var comp: ComputerSimulationManager
    @EnvironmentObject var session: GameSession
    @State private var progress: Double?
    @State private var current = ""
    @State private var result: String?

    private var targets: [String] {
        var t = ["C:/Pane/system", "C:/Users/sam/Documents", "C:/Users/sam/Downloads", "C:/Games/Kestrel"]
        if session.has("remaster_installed") {
            t += [ComputerSimulationManager.remasterPath + "/data", ComputerSimulationManager.remasterPath + "/data/legacy"]
        }
        return t + ["memory: running processes", "startup items"]
    }

    var body: some View {
        let off = session.has("shield_rt_off")
        VStack(spacing: 12) {
            Image(systemName: off ? "xmark.shield.fill" : "checkmark.shield.fill").font(.system(size: 40))
                .foregroundStyle(off ? .red : .green)
            Text(off ? "Your device is at risk" : "You're protected").font(.system(size: 16, weight: .semibold))
            HStack(spacing: 10) {
                Text("Real-time protection").font(.system(size: 12))
                Toggle("", isOn: Binding(get: { !session.has("shield_rt_off") },
                                         set: { StoryDirector.shared.setRealtime($0) }))
                    .labelsHidden().tint(.green)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            Text(session.has("update_installed") && off ? "Some settings are managed by your administrator."
                 : "Definitions updated today").font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
            if let p = progress {
                ProgressView(value: p).tint(.green).frame(width: 260)
                Text("Scanning \(current)").font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
            } else {
                Button { scan() } label: {
                    Text("Quick scan").font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 20).padding(.vertical, 8)
                        .background(Color.green.opacity(0.7), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            if let r = result {
                Text(r).font(.system(size: 11)).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.85))
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func scan() {
        result = nil
        progress = 0
        let list = targets
        Task {
            for (i, t) in list.enumerated() {
                current = t
                for k in 0..<10 {
                    try? await Task.sleep(nanoseconds: 70_000_000)
                    progress = (Double(i) + Double(k) / 10) / Double(list.count)
                }
            }
            progress = nil
            let files = 48_000 + Int.random(in: 0...900)
            var r = "Scan complete. \(files.formatted()) files scanned.\nNo threats found."
            if session.has("old_decrypted") {
                r += "\n1 item skipped: paperlight_dev.exe (unknown format)"
            }
            result = r
            AudioManager.shared.play(.uiConfirm)
            if session.has("vexley_refused_exit") {
                if !session.has("av_scanned") {
                    session.set("av_scanned")
                    session.say("No threats. So it's just a buggy old game. Right?")
                    session.say("...I'm going to bed.")
                }
            } else {
                session.set("av_scanned_early")
            }
        }
    }
}
