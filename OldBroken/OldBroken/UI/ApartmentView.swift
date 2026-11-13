import SwiftUI
import SceneKit

struct ApartmentView: View {
    @EnvironmentObject var session: GameSession
    var body: some View {
        let world = session.apartmentWorld()
        ApartmentScreen(world: world, hud: world.hud)
    }
}

private struct ApartmentScreen: View {
    @EnvironmentObject var session: GameSession
    let world: ApartmentWorld
    @ObservedObject var hud: ApartmentHUD

    var body: some View {
        ZStack {
            SceneKitContainer(world: world).ignoresSafeArea()
            TouchControls(world: world, hud: hud)
            Circle().fill(.white.opacity(hud.prompt == nil ? 0.35 : 0.9))
                .frame(width: hud.prompt == nil ? 4 : 7, height: hud.prompt == nil ? 4 : 7)
                .allowsHitTesting(false)
            HUDTopBar()
            Color.black.opacity(hud.fade).ignoresSafeArea().allowsHitTesting(false)
            if session.paused {
                PauseMenuView().transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: hud.prompt)
    }
}

struct SceneKitContainer: UIViewRepresentable {
    let world: ApartmentWorld

    func makeUIView(context: Context) -> SCNView {
        let v = SCNView(frame: .zero)
        world.attach(to: v)
        return v
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    static func dismantleUIView(_ uiView: SCNView, coordinator: ()) {
        uiView.isPlaying = false
        MainActor.assumeIsolated {
            GameSession.shared.apartment?.stopLoop()
        }
    }
}

/// Objective + clock + menu button.
struct HUDTopBar: View {
    @EnvironmentObject var session: GameSession

    var body: some View {
        VStack {
            HStack(alignment: .top) {
                if let o = session.currentObjective {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("OBJECTIVE").font(.system(size: 9, weight: .semibold, design: .monospaced)).kerning(2)
                            .foregroundStyle(.white.opacity(0.5))
                        Text(o.text).font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.9))
                            .frame(maxWidth: 300, alignment: .leading)
                    }
                    .padding(8)
                    .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
                }
                Spacer()
                Text(session.clockText)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 8)
                Button {
                    AudioManager.shared.play(.uiClick)
                    session.paused = true
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.35), in: Circle())
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }
}
