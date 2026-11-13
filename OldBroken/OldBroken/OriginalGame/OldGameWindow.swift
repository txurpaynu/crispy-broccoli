import SwiftUI
import SpriteKit

/// The OLD window. Day 1: the 1998 original. From Chapter 2 on: Vexley's overhaul.
struct OldGameWindow: View {
    @EnvironmentObject var session: GameSession
    var body: some View {
        if session.day >= 2 {
            OverhauledGameView()
        } else {
            ClassicOldGameView()
        }
    }
}

/// The 1998 original game, presented like a CRT inside the desktop.
struct ClassicOldGameView: View {
    @EnvironmentObject var comp: ComputerSimulationManager
    @EnvironmentObject var session: GameSession
    @ObservedObject private var game = RetroGameController.shared
    /// Embedded inside the VX overhaul: no window buttons of its own.
    var embedded = false

    var body: some View {
        GeometryReader { geo in
            let vh = geo.size.height
            let vw = min(geo.size.width, vh * 16 / 9)
            ZStack {
                Color.black
                ZStack {
                    SpriteView(scene: game.makeSceneIfNeeded(), preferredFramesPerSecond: 60)
                        .offset(x: CGFloat(game.glitch) * CGFloat.random(in: -6...6))
                    if game.glitch > 0 {
                        Rectangle()
                            .fill(Color(red: 1, green: 0.2, blue: 0.6))
                            .blendMode(.screen)
                            .opacity(0.25 * game.glitch)
                            .offset(x: 5 * CGFloat(game.glitch))
                            .allowsHitTesting(false)
                    }
                    if game.phase == .playing {
                        Text(game.debugText)
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(.green.opacity(0.85))
                            .padding(3)
                            .background(.black.opacity(0.5))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .allowsHitTesting(false)
                    }
                    if game.phase != .playing { titleOrBoot }
                    dialogueLayer
                    if game.menuOpen { pauseMenu }
                    if game.vexleyEntrance { entrance }
                    Scanlines(spacing: 3).opacity(0.18).allowsHitTesting(false)
                    RadialGradient(colors: [.clear, .black.opacity(0.55)], center: .center, startRadius: vw * 0.35, endRadius: vw * 0.75)
                        .allowsHitTesting(false)
                    controls
                }
                .frame(width: vw, height: vh)
                .clipped()
                if !embedded {
                    windowButtons.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
        }
        .onAppear { game.windowAppeared(); if embedded { game.skipToPlaying() } }
        .onDisappear { game.windowDisappeared() }
    }

    // MARK: Title / boot

    @ViewBuilder private var titleOrBoot: some View {
        if game.phase == .boot {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(game.bootLines.enumerated()), id: \.offset) { _, l in
                    Text(l).font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.black)
        } else {
            ZStack {
                LinearGradient(colors: [Color(red: 0.03, green: 0.05, blue: 0.2), Color(red: 0.3, green: 0.15, blue: 0.35)],
                               startPoint: .top, endPoint: .bottom)
                VStack(spacing: 8) {
                    Text("PAPERLIGHT")
                        .font(.system(size: 34, weight: .black, design: .monospaced))
                        .foregroundStyle(Color(red: 1, green: 0.9, blue: 0.55))
                        .shadow(color: .orange, radius: 0, x: 2, y: 2)
                    Text("DEV BUILD 0.7.3 · HALDEN SOFTWORKS · NOT FOR DISTRIBUTION")
                        .font(.system(size: 8, design: .monospaced)).foregroundStyle(.white.opacity(0.7))
                    BlinkingText(text: "PRESS START").padding(.top, 14)
                }
            }
            .onTapGesture { game.pressStart() }
        }
    }

    // MARK: Dialogue

    @ViewBuilder private var dialogueLayer: some View {
        if let node = game.dialogue.node {
            let isVex = node.speaker == "VEXLEY"
            VStack {
                Spacer()
                if !game.dialogue.typing && !game.dialogue.visibleChoices.isEmpty {
                    VStack(alignment: .trailing, spacing: 4) {
                        ForEach(Array(game.dialogue.visibleChoices.enumerated()), id: \.offset) { _, c in
                            Button { game.dialogue.choose(c) } label: {
                                Text("▶ " + substitute(c.text))
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(.black.opacity(0.88))
                                    .overlay(Rectangle().stroke(.white, lineWidth: 1.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 16)
                }
                HStack(alignment: .top, spacing: 8) {
                    if isVex {
                        VexleyFaceView(expression: game.dialogue.expression)
                            .frame(width: 72, height: 72)
                            .background(Color(red: 0.12, green: 0.02, blue: 0.08))
                            .overlay(Rectangle().stroke(Color(red: 1, green: 0.3, blue: 0.65), lineWidth: 2))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(node.speaker)
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .foregroundStyle(isVex ? Color(red: 1, green: 0.45, blue: 0.75) : .yellow)
                        Text(game.dialogue.shown)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, minHeight: 84, maxHeight: 96, alignment: .topLeading)
                .background(.black.opacity(0.9))
                .overlay(Rectangle().stroke(.white, lineWidth: 2))
                .overlay(alignment: .bottomTrailing) {
                    if !game.dialogue.typing && game.dialogue.visibleChoices.isEmpty {
                        BlinkingText(text: "▼", size: 10).padding(6)
                    }
                }
                .padding(.horizontal, 70)
                .padding(.bottom, 6)
                .contentShape(Rectangle())
                .onTapGesture { game.pressA() }
            }
        }
    }

    private func substitute(_ t: String) -> String {
        let f = DateFormatter(); f.dateFormat = "MMMM"
        return t.replacingOccurrences(of: "{year}", with: String(Calendar.current.component(.year, from: Date())))
            .replacingOccurrences(of: "{month}", with: f.string(from: Date()))
    }

    // MARK: Pause menu (Vexley rewrites and moves it)

    private var pauseMenu: some View {
        ZStack {
            Color.black.opacity(0.45).onTapGesture { game.pressB() }
            VStack(spacing: 8) {
                Text(session.has("vexley_met") ? "PAUSE (V)" : "PAUSE")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundStyle(session.has("vexley_met") ? Color(red: 1, green: 0.45, blue: 0.75) : .white)
                ForEach(game.menu) { item in
                    Button { game.selectMenu(item) } label: {
                        Text(item.label)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .frame(width: 150, height: 26)
                            .foregroundStyle(.white)
                            .background(.black)
                            .overlay(Rectangle().stroke(.white, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                    .offset(item.offset)
                }
            }
            .padding(16)
            .background(Color(red: 0.05, green: 0.05, blue: 0.15).opacity(0.95))
            .overlay(Rectangle().stroke(.white, lineWidth: 2))
        }
    }

    // MARK: Vexley's entrance

    private var entrance: some View {
        ZStack {
            Color.black.opacity(0.6)
            VexleyFaceView(expression: game.dialogue.node?.id == "vx_secret_1" ? .scared : .glitching)
                .frame(width: 190, height: 190)
                .shadow(color: Color(red: 1, green: 0.3, blue: 0.65).opacity(0.8), radius: 18)
            Text("VEXLEY").font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundStyle(Color(red: 0.3, green: 0.9, blue: 1))
                .offset(y: 110)
        }
        .transition(.opacity)
    }

    // MARK: Controls

    private var controls: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom) {
                DPad { d in game.held = d }
                    .frame(width: 104, height: 104)
                Spacer()
                VStack(spacing: 6) {
                    Button { game.pressStart() } label: {
                        Text(game.startLabel).font(.system(size: 8, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(.black.opacity(0.5), in: Capsule())
                            .overlay(Capsule().stroke(.white.opacity(0.4)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 4)
                Spacer()
                HStack(alignment: .bottom, spacing: 10) {
                    padButton("B") { game.pressB() }.padding(.bottom, 0)
                    padButton("A") { game.pressA() }.padding(.bottom, 26)
                }
            }
            .padding(8)
        }
        .opacity(game.dialogue.isActive && !game.dialogue.visibleChoices.isEmpty ? 0.35 : 1)
    }

    private func padButton(_ t: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t).font(.system(size: 16, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 46, height: 46)
                .background(Circle().fill(Color(red: 0.5, green: 0.1, blue: 0.2).opacity(0.65)))
                .overlay(Circle().stroke(.white.opacity(0.45), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
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
        .foregroundStyle(.white.opacity(0.6))
        .background(.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 5))
        .padding(4)
    }
}

struct BlinkingText: View {
    let text: String
    var size: CGFloat = 12
    @State private var on = true
    var body: some View {
        Text(text).font(.system(size: size, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .opacity(on ? 1 : 0.15)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever()) { on = false }
            }
    }
}

/// Hold-to-move directional pad.
struct DPad: View {
    let onChange: (Dir?) -> Void
    @State private var current: Dir?

    var body: some View {
        GeometryReader { geo in
            let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            ZStack {
                Circle().fill(.black.opacity(0.35)).overlay(Circle().stroke(.white.opacity(0.3)))
                ForEach([Dir.up, .down, .left, .right], id: \.self) { d in
                    Image(systemName: arrow(d))
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.white.opacity(current == d ? 1 : 0.55))
                        .offset(x: CGFloat(d.dx) * geo.size.width * 0.32, y: CGFloat(d.dy) * geo.size.height * 0.32)
                }
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        let dx = v.location.x - c.x, dy = v.location.y - c.y
                        let d: Dir? = hypot(dx, dy) < 8 ? nil : (abs(dx) > abs(dy) ? (dx > 0 ? .right : .left) : (dy > 0 ? .down : .up))
                        if d != current { current = d; onChange(d) }
                    }
                    .onEnded { _ in current = nil; onChange(nil) }
            )
        }
    }

    private func arrow(_ d: Dir) -> String {
        switch d {
        case .up: return "arrowtriangle.up.fill"
        case .down: return "arrowtriangle.down.fill"
        case .left: return "arrowtriangle.left.fill"
        case .right: return "arrowtriangle.right.fill"
        }
    }
}
