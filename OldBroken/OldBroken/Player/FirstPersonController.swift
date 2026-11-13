import Foundation
import simd

/// First-person movement: walk / sprint / crouch / jump, with circle-vs-box collision.
/// Kept independent of SceneKit so it can be reused in the facility levels.
final class FirstPersonController {
    var position = SIMD3<Float>(0, 0, 0)
    var yaw: Float = 0       // radians, 0 = looking toward -z
    var pitch: Float = 0
    private(set) var verticalVelocity: Float = 0
    private(set) var crouchAmount: Float = 0   // 0 standing, 1 crouched
    private(set) var bobPhase: Float = 0
    private var stepAccumulator: Float = 0

    let radius: Float = 0.26
    let standEye: Float = 1.62
    let crouchEye: Float = 1.02
    let walkSpeed: Float = 1.8
    let sprintSpeed: Float = 3.1
    let crouchSpeed: Float = 1.0
    let gravity: Float = -9.8
    let jumpVelocity: Float = 3.4

    var obstacles: [AABB2D] = []
    var bounds = AABB2D(x: 0, z: 0, w: 10, d: 10)
    var isGrounded: Bool { position.y <= 0.0001 }

    var transform: PlayerTransform {
        get { PlayerTransform(x: position.x, y: position.y, z: position.z, yaw: yaw, pitch: pitch) }
        set { position = SIMD3(newValue.x, newValue.y, newValue.z); yaw = newValue.yaw; pitch = newValue.pitch }
    }

    var eyeHeight: Float {
        standEye + (crouchEye - standEye) * crouchAmount + sin(bobPhase * 2) * 0.025 * (isGrounded ? 1 : 0)
    }

    var forward: SIMD3<Float> { SIMD3(-sin(yaw), 0, -cos(yaw)) }
    var right: SIMD3<Float> { SIMD3(cos(yaw), 0, -sin(yaw)) }

    /// Returns true when a footstep should play.
    func update(dt: Float, input: PlayerInput, lookScale: Float, invertY: Bool) -> Bool {
        let look = input.consumeLook()
        guard input.enabled else { return false }
        yaw -= look.x * lookScale
        pitch -= look.y * lookScale * (invertY ? -1 : 1)
        pitch = max(-1.35, min(1.35, pitch))

        // crouch blend
        let targetCrouch: Float = input.crouch ? 1 : 0
        crouchAmount += (targetCrouch - crouchAmount) * min(1, dt * 10)

        var speed = walkSpeed
        if input.crouch { speed = crouchSpeed } else if input.sprint && input.move.y > 0.3 { speed = sprintSpeed }

        var mv = input.move
        if simd_length(mv) > 1 { mv = simd_normalize(mv) }
        let wish = forward * mv.y + right * mv.x
        let delta = wish * speed * dt

        // axis-separated collision
        var p = position
        p.x += delta.x
        if collides(p.x, p.z) { p.x = position.x }
        p.z += delta.z
        if collides(p.x, p.z) { p.z = position.z }

        // jump / gravity
        if input.jumpRequested && isGrounded && !input.crouch {
            verticalVelocity = jumpVelocity
        }
        input.jumpRequested = false
        verticalVelocity += gravity * dt
        p.y += verticalVelocity * dt
        if p.y <= 0 { p.y = 0; verticalVelocity = 0 }

        let moved = simd_length(SIMD2(p.x - position.x, p.z - position.z))
        position = p

        if isGrounded && moved > 0.0001 {
            bobPhase += moved * 3.2
            stepAccumulator += moved
            let stride: Float = speed > walkSpeed ? 0.85 : 0.65
            if stepAccumulator > stride { stepAccumulator = 0; return true }
        }
        return false
    }

    private func collides(_ x: Float, _ z: Float) -> Bool {
        if x - radius < bounds.minX || x + radius > bounds.maxX || z - radius < bounds.minZ || z + radius > bounds.maxZ {
            return true
        }
        return obstacles.contains { $0.intersectsCircle(x: x, z: z, r: radius) }
    }
}
