import SwiftUI
import SceneKit

/// Chapters 6–8: the Halden building.
struct FacilityView: View {
    @EnvironmentObject var session: GameSession
    var body: some View {
        let world = FacilityHolder.get(session)
        FacilityScreen(world: world, hud: world.hud)
    }
}

private struct FacilityScreen: View {
    @EnvironmentObject var session: GameSession
    let world: FacilityWorld
    @ObservedObject var hud: ApartmentHUD
    @ObservedObject var ui = FacilityUI.shared

    var body: some View {
        ZStack {
            FacilitySceneContainer(world: world).ignoresSafeArea()
            if ui.alarm { AlarmVignette().allowsHitTesting(false) }
            TouchControls(world: world, hud: hud)
            Circle().fill(.white.opacity(hud.prompt == nil ? 0.35 : 0.9))
                .frame(width: hud.prompt == nil ? 4 : 7, height: hud.prompt == nil ? 4 : 7)
                .allowsHitTesting(false)
            HUDTopBar()
            if let p = ui.progress { ProgressPanel(label: ui.progressLabel, value: p) }
            if hud.flicker { Color.white.opacity(0.08).ignoresSafeArea().allowsHitTesting(false) }
            Color.black.opacity(hud.fade).ignoresSafeArea().allowsHitTesting(false)
                .animation(.easeInOut(duration: 0.4), value: hud.fade)
            if ui.caught { CaughtFlash() }
            if ui.keypad { KeypadView().transition(.scale(scale: 0.9).combined(with: .opacity)) }
            if session.paused { PauseMenuView().transition(.opacity) }
        }
        .animation(.easeOut(duration: 0.15), value: hud.prompt)
        .animation(.easeOut(duration: 0.2), value: ui.keypad)
        .onAppear {
            AudioManager.shared.setScene(session.has("usb_copied") ? .chase : .facility)
        }
    }
}

struct FacilitySceneContainer: UIViewRepresentable {
    let world: FacilityWorld
    func makeUIView(context: Context) -> SCNView {
        let v = SCNView(frame: .zero)
        world.attach(to: v)
        return v
    }
    func updateUIView(_ uiView: SCNView, context: Context) {}
    static func dismantleUIView(_ uiView: SCNView, coordinator: ()) {
        uiView.isPlaying = false
        MainActor.assumeIsolated { FacilityHolder.world?.stopLoop() }
    }
}

/// Pulsing red edges while the building is in lockdown.
private struct AlarmVignette: View {
    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let k = 0.5 + 0.5 * sin(t * 4)
            RadialGradient(colors: [.clear, Color(red: 0.8, green: 0, blue: 0.05).opacity(0.18 + 0.22 * k)],
                           center: .center, startRadius: 160, endRadius: 520)
                .ignoresSafeArea()
        }
    }
}

/// A burst of static and Vexley's eyes when the robot catches you.
private struct CaughtFlash: View {
    @State private var on = false
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TVStatic().opacity(on ? 0.15 : 0.6).ignoresSafeArea()
            HStack(spacing: 46) {
                Capsule().fill(Color(red: 0.3, green: 0.95, blue: 1)).frame(width: 70, height: 22)
                Capsule().fill(Color(red: 0.3, green: 0.95, blue: 1)).frame(width: 70, height: 22)
            }
            .shadow(color: .cyan, radius: 24)
            .scaleEffect(on ? 1.25 : 0.6)
            .opacity(on ? 1 : 0)
        }
        .onAppear { withAnimation(.easeIn(duration: 0.35)) { on = true } }
    }
}

private struct ProgressPanel: View {
    let label: String
    let value: Double
    var body: some View {
        VStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(label).font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundStyle(.white.opacity(0.85))
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(.white.opacity(0.15))
                        Rectangle().fill(Color(red: 1, green: 0.3, blue: 0.65)).frame(width: g.size.width * value)
                    }
                }
                .frame(height: 8)
                Text("\(Int(value * 100))%  — keep moving if you can").font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
            }
            .padding(12)
            .frame(width: 330)
            .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
            .padding(.top, 60)
            Spacer()
        }
        .allowsHitTesting(false)
    }
}

/// The MASTER CONTROL keypad.
struct KeypadView: View {
    @ObservedObject var ui = FacilityUI.shared
    private let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "C", "0", "OK"]

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea().onTapGesture { ui.keypad = false }
            HStack(spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("HALDEN NET").font(.system(size: 11, weight: .bold, design: .monospaced)).kerning(3)
                        .foregroundStyle(Color(red: 0.4, green: 1, blue: 0.6).opacity(0.7))
                    Text("MASTER CONTROL").font(.system(size: 20, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Color(red: 0.4, green: 1, blue: 0.6))
                    Text("Enter developer access code").font(.system(size: 12, design: .monospaced)).foregroundStyle(.white.opacity(0.6))
                    HStack(spacing: 10) {
                        ForEach(0..<4, id: \.self) { i in
                            let ch = i < ui.entry.count ? String(Array(ui.entry)[i]) : "_"
                            Text(ch).font(.system(size: 30, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(red: 0.4, green: 1, blue: 0.6))
                                .frame(width: 40, height: 54)
                                .background(Color.black, in: RoundedRectangle(cornerRadius: 4))
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(red: 0.4, green: 1, blue: 0.6).opacity(0.4)))
                        }
                    }
                    .padding(.top, 8)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(58), spacing: 8), count: 3), spacing: 8) {
                    ForEach(keys, id: \.self) { k in
                        Button { press(k) } label: {
                            Text(k).font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundStyle(k == "OK" ? .black : .white)
                                .frame(width: 58, height: 48)
                                .background(k == "OK" ? Color(red: 0.4, green: 1, blue: 0.6) : Color(white: 0.18),
                                            in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
                .frame(width: 190)
            }
            .padding(24)
            .background(Color(red: 0.04, green: 0.07, blue: 0.06), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red: 0.4, green: 1, blue: 0.6).opacity(0.3)))
        }
    }

    private func press(_ k: String) {
        AudioManager.shared.play(.keyTap)
        switch k {
        case "C": ui.entry = ""
        case "OK": StoryDirector.shared.submitCode(ui.entry); ui.entry = ""
        default: if ui.entry.count < 4 { ui.entry += k }
        }
    }
}
