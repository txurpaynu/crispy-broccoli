import SceneKit
import UIKit
import simd

/// WREN-4: the unfinished helper robot, built from primitives so every joint can move.
/// Vexley's colours show once he's inside: cyan eyes, a hot-pink chest light.
@MainActor
final class RobotRig {
    enum Mode { case asleep, waking, idle, stalk, hunt, frozen }

    let node = SCNNode()
    private let hips = SCNNode(), torso = SCNNode(), head = SCNNode()
    private let armL = SCNNode(), armR = SCNNode(), foreL = SCNNode(), foreR = SCNNode()
    private let legL = SCNNode(), legR = SCNNode(), shinL = SCNNode(), shinR = SCNNode()
    private let eyeMat = SK.material(.black, roughness: 0.2, emission: .black)
    private let chestMat = SK.material(.black, roughness: 0.2, emission: .black)
    private let eyeLight = SCNNode()

    private(set) var mode: Mode = .asleep
    private var walkPhase: Float = 0
    private var t: Float = 0
    private var path: [(Int, Int)] = []
    private var repath: Float = 0
    var level: FacilityLevel = .basement
    /// Seconds until the robot follows the player to another floor.
    private var floorDelay: Float = -1
    private var pendingLevel: FacilityLevel?
    var speed: Float = 0
    var onCatch: (@MainActor () -> Void)?

    init() {
        let shell = SK.material(UIColor(white: 0.82, alpha: 1), roughness: 0.35, metalness: 0.2)
        let dark = SK.material(UIColor(white: 0.14, alpha: 1), roughness: 0.5, metalness: 0.7)
        let pink = SK.material(UIColor(red: 1, green: 0.25, blue: 0.62, alpha: 1), roughness: 0.4)

        node.name = InteractionSystem.prefix + "robot"
        hips.position = SCNVector3(0, 0.95, 0)
        node.addChildNode(hips)
        SK.box(0.36, 0.14, 0.22, dark, at: SCNVector3Zero, in: hips, chamfer: 0.03)

        torso.position = SCNVector3(0, 0.08, 0)
        hips.addChildNode(torso)
        SK.box(0.12, 0.2, 0.12, dark, at: SCNVector3(0, 0.1, 0), in: torso, chamfer: 0.02)
        SK.box(0.46, 0.5, 0.28, shell, at: SCNVector3(0, 0.42, 0), in: torso, chamfer: 0.08)
        SK.box(0.3, 0.04, 0.29, pink, at: SCNVector3(0, 0.24, 0), in: torso, chamfer: 0.01)
        let chest = SK.cylinder(0.05, 0.02, chestMat, at: SCNVector3(0, 0.5, 0.145), in: torso)
        chest.eulerAngles.x = .pi / 2

        head.position = SCNVector3(0, 0.72, 0)
        torso.addChildNode(head)
        SK.cylinder(0.04, 0.1, dark, at: SCNVector3(0, 0.03, 0), in: head)
        SK.box(0.3, 0.22, 0.24, shell, at: SCNVector3(0, 0.17, 0), in: head, chamfer: 0.07)
        SK.box(0.24, 0.08, 0.02, SK.material(UIColor(white: 0.05, alpha: 1), roughness: 0.1, metalness: 0.4),
               at: SCNVector3(0, 0.18, 0.12), in: head, chamfer: 0.02)
        for x in [-0.06, 0.06] as [Float] {
            SK.box(0.05, 0.03, 0.01, eyeMat, at: SCNVector3(x, 0.18, 0.132), in: head, chamfer: 0.01)
        }
        // ear fins, a nod to the fox
        for x in [-0.11, 0.11] as [Float] {
            let ear = SK.box(0.05, 0.1, 0.04, pink, at: SCNVector3(x, 0.32, -0.02), in: head, chamfer: 0.01)
            ear.eulerAngles.z = x < 0 ? 0.35 : -0.35
        }
        eyeLight.light = SK.omni(UIColor(red: 0.3, green: 0.95, blue: 1, alpha: 1), intensity: 0, range: 4, shadows: false)
        eyeLight.position = SCNVector3(0, 0.18, 0.3)
        head.addChildNode(eyeLight)

        for (arm, fore, x) in [(armL, foreL, Float(-0.29)), (armR, foreR, Float(0.29))] {
            arm.position = SCNVector3(x, 0.6, 0)
            torso.addChildNode(arm)
            SK.box(0.12, 0.1, 0.12, dark, at: SCNVector3Zero, in: arm, chamfer: 0.04)
            SK.box(0.09, 0.3, 0.09, shell, at: SCNVector3(0, -0.18, 0), in: arm, chamfer: 0.03)
            fore.position = SCNVector3(0, -0.34, 0)
            arm.addChildNode(fore)
            SK.box(0.08, 0.28, 0.08, shell, at: SCNVector3(0, -0.14, 0), in: fore, chamfer: 0.03)
            SK.box(0.1, 0.08, 0.06, dark, at: SCNVector3(0, -0.31, 0), in: fore, chamfer: 0.02)
        }
        for (leg, shin, x) in [(legL, shinL, Float(-0.11)), (legR, shinR, Float(0.11))] {
            leg.position = SCNVector3(x, -0.06, 0)
            hips.addChildNode(leg)
            SK.box(0.12, 0.42, 0.13, shell, at: SCNVector3(0, -0.21, 0), in: leg, chamfer: 0.04)
            shin.position = SCNVector3(0, -0.44, 0)
            leg.addChildNode(shin)
            SK.box(0.1, 0.4, 0.11, dark, at: SCNVector3(0, -0.2, 0), in: shin, chamfer: 0.03)
            SK.box(0.12, 0.05, 0.22, dark, at: SCNVector3(0, -0.42, 0.04), in: shin, chamfer: 0.02)
        }
        node.enumerateHierarchy { n, _ in n.castsShadow = true }
        pose(slump: 1)
    }

    // MARK: Poses

    /// 1 = slumped in its cradle, 0 = standing.
    private func pose(slump s: Float) {
        hips.position.y = 0.95 - 0.3 * s
        torso.eulerAngles.x = 0.45 * s
        head.eulerAngles.x = 0.5 * s
        legL.eulerAngles.x = -1.1 * s; legR.eulerAngles.x = -1.1 * s
        shinL.eulerAngles.x = 1.6 * s; shinR.eulerAngles.x = 1.6 * s
        armL.eulerAngles.x = 0.2 * s; armR.eulerAngles.x = 0.2 * s
        foreL.eulerAngles.x = -0.6 * s; foreR.eulerAngles.x = -0.6 * s
    }

    func setEyes(_ on: Bool) {
        eyeMat.emission.contents = on ? UIColor(red: 0.3, green: 0.95, blue: 1, alpha: 1) : UIColor.black
        chestMat.emission.contents = on ? UIColor(red: 1, green: 0.2, blue: 0.6, alpha: 1) : UIColor.black
        eyeLight.light?.intensity = on ? 160 : 0
    }

    /// The transfer: flicker, twitch, stand up.
    func wake(done: @escaping () -> Void) {
        mode = .waking
        var flick: [SCNAction] = []
        for i in 0..<9 {
            let on = i % 2 == 0
            flick.append(.run { _ in Task { @MainActor in self.setEyes(on) } })
            flick.append(.wait(duration: Double.random(in: 0.05...0.25)))
        }
        flick.append(.run { _ in Task { @MainActor in self.setEyes(true) } })
        let twitch = SCNAction.sequence([
            .rotateBy(x: 0, y: 0, z: 0.15, duration: 0.06), .rotateBy(x: 0, y: 0, z: -0.3, duration: 0.08),
            .rotateBy(x: 0, y: 0, z: 0.15, duration: 0.06),
        ])
        head.runAction(.sequence([.wait(duration: 0.8), twitch, .wait(duration: 0.4), twitch]))
        node.runAction(.sequence(flick + [.wait(duration: 0.4)])) {
            Task { @MainActor in
                var k: Float = 1
                let steps = 40
                for _ in 0..<steps {
                    try? await Task.sleep(nanoseconds: 45_000_000)
                    k -= 1 / Float(steps)
                    self.pose(slump: max(0, k * k))
                }
                self.pose(slump: 0)
                // look up, straight at the player
                self.head.runAction(.sequence([.rotateTo(x: -0.25, y: 0, z: 0, duration: 0.6), .wait(duration: 0.6),
                                               .rotateTo(x: 0, y: 0, z: 0, duration: 0.4)]))
                self.mode = .idle
                done()
            }
        }
    }

    /// Restores a robot that is already awake (loading a save).
    func standAwake() {
        mode = .idle
        pose(slump: 0)
        setEyes(true)
    }

    func start(_ m: Mode, speed: Float) {
        mode = m
        self.speed = speed
        path = []
        repath = 0
    }

    func teleport(_ lvl: FacilityLevel, x: Float, z: Float) {
        level = lvl
        node.position = SCNVector3(lvl.offsetX + x, 0, z)
        path = []
        pendingLevel = nil
        floorDelay = -1
    }

    func playerChangedLevel(to lvl: FacilityLevel) {
        guard mode == .stalk || mode == .hunt, lvl != level else { return }
        pendingLevel = lvl
        floorDelay = 6.5
    }

    // MARK: Update

    func update(dt: Float, world w: FacilityWorld) {
        t += dt
        switch mode {
        case .asleep, .waking, .frozen:
            return
        case .idle:
            torso.eulerAngles.y = sin(t * 0.7) * 0.15
            lookAt(w.controller.position, dt: dt, turnOnly: true)
            return
        case .stalk, .hunt:
            break
        }

        // following the player between floors (he controls the stairwell door)
        if let pl = pendingLevel {
            floorDelay -= dt
            if floorDelay <= 0 {
                if pl == .ground { teleport(.ground, x: 21.5, z: 23.2) } else { teleport(.basement, x: 3, z: 2.2) }
                AudioManager.shared.play(.doorRattle)
                StoryDirector.shared.robotArrived(on: pl)
            }
            animateWalk(dt: dt, moving: false)
            return
        }
        guard level == w.level else { animateWalk(dt: dt, moving: false); return }

        let p = w.controller.position
        let me = node.position
        let dx = p.x - me.x, dz = p.z - me.z
        let dist = (dx * dx + dz * dz).squareRoot()
        if dist < 0.9 {
            onCatch?()
            return
        }
        repath -= dt
        if repath <= 0 || path.isEmpty {
            repath = 0.35
            path = findPath(w, from: cell(me), to: cell(SCNVector3(p.x, 0, p.z)))
        }
        var target = SIMD2<Float>(p.x, p.z)
        while let next = path.first {
            let c = SIMD2<Float>(level.offsetX + Float(next.0) + 0.5, Float(next.1) + 0.5)
            if simd_distance(c, SIMD2(me.x, me.z)) < 0.25 { path.removeFirst(); continue }
            target = c
            // open doors in the way
            for d in w.doors.values where d.level == level && !d.open && d.cells.contains(where: { $0 == next }) {
                w.setDoor(d.id, open: true)
            }
            break
        }
        var dir = SIMD2<Float>(target.x - me.x, target.y - me.z)
        let len = simd_length(dir)
        if len > 0.001 { dir /= len }
        let step = min(len, speed * dt)
        node.position = SCNVector3(me.x + dir.x * step, 0, me.z + dir.y * step)
        let yaw = atan2(dir.x, dir.y)
        node.eulerAngles.y += (yaw - node.eulerAngles.y).wrappedAngle * min(1, dt * 8)
        animateWalk(dt: dt, moving: true)
        // heavy footsteps
        if Int((walkPhase + speed * dt * 3.3) / .pi) != Int(walkPhase / .pi) && dist < 14 {
            AudioManager.shared.play(.retroBump)
        }
    }

    private func lookAt(_ p: SIMD3<Float>, dt: Float, turnOnly: Bool) {
        let me = node.worldPosition
        let yaw = atan2(p.x - me.x, p.z - me.z) - node.eulerAngles.y
        head.eulerAngles.y += (yaw.wrappedAngle - head.eulerAngles.y) * min(1, dt * 3)
        head.eulerAngles.y = max(-1.2, min(1.2, head.eulerAngles.y))
    }

    private func animateWalk(dt: Float, moving: Bool) {
        if moving { walkPhase += dt * speed * 3.3 }
        let a: Float = moving ? 0.55 : 0
        let s = sin(walkPhase)
        legL.eulerAngles.x += (s * a - legL.eulerAngles.x) * 0.3
        legR.eulerAngles.x += (-s * a - legR.eulerAngles.x) * 0.3
        shinL.eulerAngles.x = max(0, -s) * a * 1.2
        shinR.eulerAngles.x = max(0, s) * a * 1.2
        armL.eulerAngles.x = -s * a * 0.8 - (mode == .hunt ? 0.7 : 0)
        armR.eulerAngles.x = s * a * 0.8 - (mode == .hunt ? 0.7 : 0)
        hips.position.y = 0.95 + abs(cos(walkPhase)) * 0.04 * (moving ? 1 : 0)
        torso.eulerAngles.x = mode == .hunt ? 0.18 : 0.05
        head.eulerAngles.y *= 0.9
    }

    // MARK: Path finding (BFS on the floor grid; doors are passable, he owns them)

    private func cell(_ v: SCNVector3) -> (Int, Int) {
        (Int(floor(v.x - level.offsetX)), Int(floor(v.z)))
    }

    private func findPath(_ w: FacilityWorld, from: (Int, Int), to: (Int, Int)) -> [(Int, Int)] {
        let g = w.grid(level)
        let h = g.count, wd = g.first?.count ?? 0
        func ok(_ c: (Int, Int)) -> Bool {
            c.0 >= 0 && c.1 >= 0 && c.0 < wd && c.1 < h && g[c.1][c.0] != "#"
        }
        guard ok(from), ok(to) else { return [] }
        var prev = [Int](repeating: -1, count: wd * h)
        var q = [from.1 * wd + from.0]
        prev[q[0]] = q[0]
        var i = 0
        let goal = to.1 * wd + to.0
        while i < q.count {
            let k = q[i]; i += 1
            if k == goal { break }
            let x = k % wd, z = k / wd
            for (dx, dz) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                let n = (x + dx, z + dz)
                guard ok(n) else { continue }
                let nk = n.1 * wd + n.0
                if prev[nk] == -1 { prev[nk] = k; q.append(nk) }
            }
        }
        guard prev[goal] != -1 else { return [] }
        var out: [(Int, Int)] = []
        var k = goal
        while k != prev[k] { out.append((k % wd, k / wd)); k = prev[k] }
        return out.reversed()
    }
}
