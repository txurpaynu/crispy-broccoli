import SwiftUI

/// Landscape touch scheme:
///  - left 45% of the screen: floating joystick (touch anywhere, drag)
///  - right side: drag to look
///  - buttons: Use (contextual), Jump, Crouch, Sprint
struct TouchControls: View {
    let world: any PlayableWorld
    @ObservedObject var hud: ApartmentHUD
    @State private var stickOrigin: CGPoint?
    @State private var stickPoint: CGPoint = .zero
    @State private var lastLook: CGPoint?
    @State private var crouch = false
    @State private var sprint = false

    private let radius: CGFloat = 56

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    // MOVE
                    Color.white.opacity(0.001)
                        .frame(width: geo.size.width * 0.45)
                        .gesture(moveGesture)
                    // LOOK
                    Color.white.opacity(0.001)
                        .gesture(lookGesture)
                }

                if let o = stickOrigin {
                    Circle().stroke(.white.opacity(0.35), lineWidth: 2)
                        .frame(width: radius * 2, height: radius * 2)
                        .position(o)
                        .allowsHitTesting(false)
                    Circle().fill(.white.opacity(0.45))
                        .frame(width: 44, height: 44)
                        .position(clamped(o, stickPoint))
                        .allowsHitTesting(false)
                } else {
                    Text("MOVE")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.25))
                        .frame(width: radius * 2, height: radius * 2)
                        .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1.5))
                        .position(x: 110, y: geo.size.height - 100)
                        .allowsHitTesting(false)
                }

                actionButtons
                    .position(x: geo.size.width - 120, y: geo.size.height - 110)

                if let p = hud.prompt {
                    Text(p)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(.black.opacity(0.55), in: Capsule())
                        .position(x: geo.size.width / 2, y: geo.size.height / 2 + 38)
                        .allowsHitTesting(false)
                }
            }
            .coordinateSpace(name: "controls")
        }
    }

    private var actionButtons: some View {
        ZStack {
            roundButton(icon: "hand.tap.fill", label: "USE", size: 74, active: hud.prompt != nil) {
                world.interact()
            }
            roundButton(icon: "arrow.up.to.line", label: "JUMP", size: 48, active: false) {
                world.input.jumpRequested = true
            }
            .offset(x: -82, y: 26)
            roundButton(icon: "figure.walk", label: crouch ? "STAND" : "CROUCH", size: 48, active: crouch) {
                crouch.toggle()
                world.input.crouch = crouch
                if crouch { sprint = false; world.input.sprint = false }
            }
            .offset(x: -62, y: -56)
            roundButton(icon: "hare.fill", label: "SPRINT", size: 48, active: sprint) {
                sprint.toggle()
                world.input.sprint = sprint
            }
            .offset(x: 10, y: -88)
        }
    }

    private func roundButton(icon: String, label: String, size: CGFloat, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Image(systemName: icon).font(.system(size: size * 0.32, weight: .semibold))
                Text(label).font(.system(size: 8, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(.white.opacity(active ? 1 : 0.75))
            .frame(width: size, height: size)
            .background(Circle().fill(active ? Color.white.opacity(0.28) : Color.black.opacity(0.35)))
            .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private func clamped(_ o: CGPoint, _ p: CGPoint) -> CGPoint {
        let dx = p.x - o.x, dy = p.y - o.y
        let len = max(1, sqrt(dx * dx + dy * dy))
        let k = min(1, radius / len)
        return CGPoint(x: o.x + dx * k, y: o.y + dy * k)
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("controls"))
            .onChanged { v in
                if stickOrigin == nil { stickOrigin = v.startLocation }
                stickPoint = v.location
                guard let o = stickOrigin else { return }
                var dx = Float((v.location.x - o.x) / radius)
                var dy = Float(-(v.location.y - o.y) / radius)
                let len = sqrt(dx * dx + dy * dy)
                if len > 1 { dx /= len; dy /= len }
                if len < 0.12 { dx = 0; dy = 0 }
                world.input.move = SIMD2(dx, dy)
            }
            .onEnded { _ in
                stickOrigin = nil
                world.input.move = .zero
            }
    }

    private var lookGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { v in
                if let last = lastLook {
                    world.input.look.x += Float(v.location.x - last.x)
                    world.input.look.y += Float(v.location.y - last.y)
                }
                lastLook = v.location
            }
            .onEnded { _ in lastLook = nil }
    }
}
