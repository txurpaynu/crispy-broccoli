import Foundation
import simd

/// Written by the touch controls, read once per frame by the controller.
final class PlayerInput {
    /// Joystick, x = right, y = forward. Length 0...1.
    var move = SIMD2<Float>(0, 0)
    /// Accumulated look delta in points since last frame.
    var look = SIMD2<Float>(0, 0)
    var sprint = false
    var crouch = false
    var jumpRequested = false
    var enabled = true

    func consumeLook() -> SIMD2<Float> {
        let l = look
        look = .zero
        return l
    }

    func reset() {
        move = .zero; look = .zero; jumpRequested = false; sprint = false
    }
}

/// Axis-aligned box on the floor plane (x/z), used for collision.
struct AABB2D {
    var minX: Float, maxX: Float, minZ: Float, maxZ: Float

    init(x: Float, z: Float, w: Float, d: Float) {
        minX = x - w / 2; maxX = x + w / 2; minZ = z - d / 2; maxZ = z + d / 2
    }

    func intersectsCircle(x: Float, z: Float, r: Float) -> Bool {
        let cx = max(minX, min(x, maxX))
        let cz = max(minZ, min(z, maxZ))
        let dx = x - cx, dz = z - cz
        return dx * dx + dz * dz < r * r
    }
}
