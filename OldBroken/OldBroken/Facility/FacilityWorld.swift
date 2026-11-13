import SceneKit
import UIKit
import simd

struct FacilityMapData: Decodable {
    let ground: [String]
    let basement: [String]
    /// name -> [x0, z0, x1, z1, level]
    let rooms: [String: [Int]]
    /// id -> [x, z, level]
    let doors: [String: [Int]]
}

enum FacilityLevel: Int, Codable {
    case ground = 0, basement = 1
    /// The basement is built 100 m east of the ground floor, on the same plane.
    var offsetX: Float { self == .ground ? 0 : 100 }
}

/// A door in the facility: a hinged panel in a 1 m wall gap.
final class FacilityDoor {
    let id: String
    let level: FacilityLevel
    let cells: [(Int, Int)]
    let pivot: SCNNode
    var open = false
    var locked = false
    /// The panel runs along x (wall is horizontal) or along z.
    let alongX: Bool
    init(id: String, level: FacilityLevel, cells: [(Int, Int)], pivot: SCNNode, alongX: Bool) {
        self.id = id; self.level = level; self.cells = cells; self.pivot = pivot; self.alongX = alongX
    }
}

/// CHAPTERS 6–8: the abandoned Halden Softworks building. Two floors built from a
/// character grid (Data/facility_map.json), dressed with CC0 models, lit by a flashlight.
@MainActor
final class FacilityWorld: NSObject, PlayableWorld {
    let scene = SCNScene()
    let controller = FirstPersonController()
    let input = PlayerInput()
    let interaction = InteractionSystem()
    let hud = ApartmentHUD()
    let cameraNode = SCNNode()
    let flashlight = SCNNode()
    let ambient = SCNNode()
    var nodes: [String: SCNNode] = [:]
    var doors: [String: FacilityDoor] = [:]
    var cameras: [SCNNode] = []
    var robot: RobotRig?
    weak var session: GameSession?

    let map: FacilityMapData
    private(set) var level: FacilityLevel = .ground
    private var wallObstacles: [AABB2D] = []
    var propObstacles: [AABB2D] = []
    private var link: CADisplayLink?
    private var lastTime: CFTimeInterval = 0
    private var frame = 0
    private var currentTarget: (Interactable, SCNNode)?
    var cutscene = false
    private var wallMaterials: [String: SCNMaterial] = [:]
    var alarm = false
    private var alarmPhase: Float = 0

    static let wallHeight: Float = 3.0

    init(session: GameSession) {
        self.session = session
        map = DataLoader.load("facility_map", as: FacilityMapData.self)
            ?? FacilityMapData(ground: ["###", "#.#", "###"], basement: ["###", "#.#", "###"], rooms: [:], doors: [:])
        super.init()
        scene.background.contents = UIColor.black
        scene.lightingEnvironment.intensity = 0
        scene.fogStartDistance = 5
        scene.fogEndDistance = 22
        scene.fogColor = UIColor.black
        setupCamera()
        build(.ground)
        build(.basement)
        FacilityContent.populate(self)
        rebuildObstacles()
        controller.bounds = AABB2D(x: 60, z: 15, w: 200, d: 60)
        applyPower()
    }

    // MARK: Camera, flashlight

    private func setupCamera() {
        let cam = SCNCamera()
        cam.zNear = 0.03
        cam.zFar = 40
        cam.fieldOfView = 74
        cam.wantsHDR = true
        cam.wantsExposureAdaptation = false
        cam.exposureOffset = -0.2
        cam.bloomIntensity = 0.35
        cam.bloomThreshold = 0.9
        cam.bloomBlurRadius = 10
        cam.vignettingIntensity = 0.9
        cam.vignettingPower = 0.8
        cam.grainIntensity = 0.18
        cam.grainScale = 1.3
        cam.saturation = 0.8
        cam.contrast = 0.12
        cameraNode.camera = cam
        scene.rootNode.addChildNode(cameraNode)

        let spot = SCNLight()
        spot.type = .spot
        spot.color = UIColor(red: 1, green: 0.95, blue: 0.85, alpha: 1)
        spot.intensity = 520
        spot.spotInnerAngle = 16
        spot.spotOuterAngle = 46
        spot.attenuationStartDistance = 0.5
        spot.attenuationEndDistance = 16
        spot.castsShadow = true
        spot.shadowMode = .forward
        spot.shadowSampleCount = 4
        spot.shadowRadius = 2
        flashlight.light = spot
        flashlight.position = SCNVector3(0.18, -0.15, 0)
        cameraNode.addChildNode(flashlight)

        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        scene.rootNode.addChildNode(ambient)
    }

    /// Lights for the current story state: dark, powered (after master control), or alarm.
    func applyPower() {
        guard let s = session else { return }
        let a = ambient.light!
        if s.has("robot_awake") {
            alarm = true
            a.color = UIColor(red: 0.8, green: 0.12, blue: 0.15, alpha: 1)
            a.intensity = 30
        } else if s.has("master_open") {
            alarm = false
            a.color = UIColor(red: 0.8, green: 0.88, blue: 1, alpha: 1)
            a.intensity = 70
        } else {
            alarm = false
            a.color = UIColor(red: 0.25, green: 0.3, blue: 0.45, alpha: 1)
            a.intensity = 9
        }
        let powered = s.has("master_open")
        scene.rootNode.enumerateChildNodes { n, _ in
            if n.name == "fluoro" {
                n.geometry?.firstMaterial?.emission.contents = powered
                    ? (s.has("robot_awake") ? UIColor(red: 0.6, green: 0.05, blue: 0.08, alpha: 1) : UIColor(white: 0.95, alpha: 1))
                    : UIColor.black
            }
        }
    }

    // MARK: Building

    func grid(_ lvl: FacilityLevel) -> [[Character]] {
        (lvl == .ground ? map.ground : map.basement).map { Array($0) }
    }

    /// World position of a point in cell coordinates (cell (x, z) spans x...x+1, z...z+1).
    func pos(_ lvl: FacilityLevel, _ x: Float, _ z: Float, y: Float = 0) -> SCNVector3 {
        SCNVector3(lvl.offsetX + x, y, z)
    }

    private func wallMaterial(_ lvl: FacilityLevel, length: Int) -> SCNMaterial {
        let key = "\(lvl.rawValue)-\(length)"
        if let m = wallMaterials[key] { return m }
        let tex = lvl == .ground ? "peeling_painted_wall" : "concrete_wall_004"
        let m = ModelLibrary.texturedMaterial(tex, repeat: 1, tint: UIColor(white: 0.85, alpha: 1))
            ?? SK.material(UIColor(white: 0.45, alpha: 1), roughness: 0.9)
        let t = SCNMatrix4MakeScale(Float(max(1, length)) / 2.5, Self.wallHeight / 2.5, 1)
        for p in [m.diffuse, m.normal, m.roughness, m.multiply] { p.contentsTransform = t }
        wallMaterials[key] = m
        return m
    }

    private func build(_ lvl: FacilityLevel) {
        let g = grid(lvl)
        let root = SCNNode()
        root.name = "level\(lvl.rawValue)"
        scene.rootNode.addChildNode(root)
        let h = g.count, w = g.first?.count ?? 0
        let H = Self.wallHeight

        // floor + ceiling slabs for the whole level
        let floorMat = ModelLibrary.texturedMaterial("concrete_floor_worn_001", repeat: Float(max(w, h)) / 3)
            ?? SK.material(UIColor(white: 0.3, alpha: 1), roughness: 0.9)
        SK.box(CGFloat(w), 0.1, CGFloat(h), floorMat, at: pos(lvl, Float(w) / 2, Float(h) / 2, y: -0.05), in: root)
        let ceilMat = ModelLibrary.texturedMaterial("ceiling_interior", repeat: Float(max(w, h)) / 2, tint: UIColor(white: 0.55, alpha: 1))
            ?? SK.material(UIColor(white: 0.4, alpha: 1), roughness: 0.95)
        SK.box(CGFloat(w), 0.1, CGFloat(h), ceilMat, at: pos(lvl, Float(w) / 2, Float(h) / 2, y: H + 0.05), in: root)

        // room floors
        for (name, r) in map.rooms where r[4] == lvl.rawValue {
            let tex: String
            switch name {
            case "lobby": tex = "dirty_tiles"
            case "office_b", "halden_office", "meeting", "dev", "corridor", "corridor2", "archive": tex = "old_linoleum_flooring_01"
            default: tex = ""
            }
            guard !tex.isEmpty else { continue }
            let rw = Float(r[2] - r[0] + 1), rd = Float(r[3] - r[1] + 1)
            if let m = ModelLibrary.texturedMaterial(tex, repeat: max(rw, rd) / 2) {
                let p = SCNNode(geometry: SCNPlane(width: CGFloat(rw), height: CGFloat(rd)))
                p.geometry!.materials = [m]
                p.eulerAngles.x = -.pi / 2
                p.position = pos(lvl, Float(r[0]) + rw / 2, Float(r[1]) + rd / 2, y: 0.004)
                root.addChildNode(p)
            }
            // a fluorescent fixture per few metres (emissive once the power is back)
            let fixMat = SK.material(UIColor(white: 0.8, alpha: 1), roughness: 0.4)
            fixMat.emission.contents = UIColor.black
            var fx = Float(r[0]) + 1.5
            while fx < Float(r[2]) + 0.5 {
                var fz = Float(r[1]) + 1.5
                while fz < Float(r[3]) + 0.5 {
                    let f = SCNNode(geometry: SCNBox(width: 1.1, height: 0.04, length: 0.25, chamferRadius: 0.01))
                    let m = fixMat.copy() as! SCNMaterial
                    f.geometry!.materials = [m]
                    f.name = "fluoro"
                    f.position = pos(lvl, fx, fz, y: H - 0.03)
                    root.addChildNode(f)
                    fz += 4
                }
                fx += 4
            }
        }

        // walls: merge horizontal runs of '#' into single boxes
        for z in 0..<h {
            var x = 0
            while x < w {
                guard g[z][x] == "#" else { x += 1; continue }
                var x1 = x
                while x1 + 1 < w && g[z][x1 + 1] == "#" { x1 += 1 }
                let len = x1 - x + 1
                // skip runs buried inside solid rock (no floor next to them)
                var exposed = false
                for cx in x...x1 {
                    for (dx, dz) in [(0, 1), (0, -1), (1, 0), (-1, 0)] {
                        let nx = cx + dx, nz = z + dz
                        if nx >= 0 && nz >= 0 && nx < w && nz < h && g[nz][nx] != "#" { exposed = true }
                    }
                }
                if exposed {
                    SK.box(CGFloat(len), CGFloat(H), 1, wallMaterial(lvl, length: len),
                           at: pos(lvl, Float(x) + Float(len) / 2, Float(z) + 0.5, y: H / 2), in: root, chamfer: 0)
                }
                wallObstacles.append(AABB2D(x: lvl.offsetX + Float(x) + Float(len) / 2, z: Float(z) + 0.5, w: Float(len), d: 1))
                x = x1 + 1
            }
        }

        // doors
        let doorMat = SK.material(UIColor(red: 0.42, green: 0.45, blue: 0.48, alpha: 1), roughness: 0.6, metalness: 0.4)
        let lintelMat = wallMaterial(lvl, length: 1)
        for (id, d) in map.doors where d[2] == lvl.rawValue {
            let x = d[0], z = d[1]
            let alongX = (x > 0 && g[z][x - 1] == "#") || (x + 1 < w && g[z][x + 1] == "#")
            var cells = [(x, z)]
            var width: Float = 1
            if id == "dock" { cells = [(34, z), (35, z), (36, z)]; width = 3 }
            let cx = id == "dock" ? Float(35) : Float(x)
            SK.box(CGFloat(width), CGFloat(H - 2.1), 1, lintelMat, at: pos(lvl, cx + 0.5, Float(z) + 0.5, y: 2.1 + (H - 2.1) / 2), in: root, chamfer: 0)
            let pivot = SCNNode()
            pivot.name = InteractionSystem.prefix + "door_" + id
            if id == "dock" {
                pivot.position = pos(lvl, cx + 0.5, Float(z) + 0.5)
                if let shutter = ModelLibrary.load("rollershutter_door") {
                    let hgt = max(0.1, ModelLibrary.height(shutter))
                    let k = 2.2 / hgt
                    shutter.scale = SCNVector3(3.0 / 3.08, k, k)
                    pivot.addChildNode(shutter)
                } else {
                    SK.box(3, 2.1, 0.08, SK.material(UIColor(white: 0.4, alpha: 1), roughness: 0.5, metalness: 0.7), at: SCNVector3(0, 1.05, 0), in: pivot)
                }
            } else if alongX {
                pivot.position = pos(lvl, Float(x) + 0.02, Float(z) + 0.5)
                SK.box(0.96, 2.06, 0.05, doorMat, at: SCNVector3(0.48, 1.03, 0), in: pivot, chamfer: 0.005)
                SK.box(0.12, 0.03, 0.04, SK.material(UIColor(white: 0.8, alpha: 1), roughness: 0.3, metalness: 0.9), at: SCNVector3(0.82, 1.0, 0.04), in: pivot)
            } else {
                pivot.position = pos(lvl, Float(x) + 0.5, Float(z) + 0.02)
                SK.box(0.05, 2.06, 0.96, doorMat, at: SCNVector3(0, 1.03, 0.48), in: pivot, chamfer: 0.005)
                SK.box(0.04, 0.03, 0.12, SK.material(UIColor(white: 0.8, alpha: 1), roughness: 0.3, metalness: 0.9), at: SCNVector3(0.04, 1.0, 0.82), in: pivot)
            }
            root.addChildNode(pivot)
            let door = FacilityDoor(id: id, level: lvl, cells: cells, pivot: pivot, alongX: alongX)
            doors[id] = door
            interaction.register(ActionInteractable(id: "door_" + id, prompt: { [weak self] _ in self?.doorPrompt(id) }) { [weak self] _ in
                self?.useDoor(id)
            })
        }
    }

    // MARK: Doors

    func rebuildObstacles() {
        var o = wallObstacles
        for d in doors.values where !d.open {
            for c in d.cells {
                o.append(AABB2D(x: d.level.offsetX + Float(c.0) + 0.5, z: Float(c.1) + 0.5, w: 1, d: 1))
            }
        }
        o += propObstacles
        controller.obstacles = o
    }

    private func doorPrompt(_ id: String) -> String? {
        guard let d = doors[id] else { return nil }
        if let p = StoryDirector.shared.facilityDoorPrompt(id, door: d) { return p }
        return d.open ? "Close door" : "Open door"
    }

    private func useDoor(_ id: String) {
        guard let d = doors[id] else { return }
        if StoryDirector.shared.facilityDoorUsed(id, door: d) { return }
        if d.locked {
            AudioManager.shared.play(.doorRattle)
            return
        }
        setDoor(id, open: !d.open)
    }

    func setDoor(_ id: String, open: Bool, animated: Bool = true, slam: Bool = false) {
        guard let d = doors[id], d.open != open else { return }
        d.open = open
        if id == "dock" {
            d.pivot.runAction(.moveBy(x: 0, y: CGFloat(open ? 2.3 : -2.3), z: 0, duration: animated ? 2.5 : 0))
        } else {
            let angle: CGFloat = open ? (d.alongX ? -.pi / 2 * 0.95 : .pi / 2 * 0.95) : 0
            d.pivot.runAction(.rotateTo(x: 0, y: angle, z: 0, duration: animated ? (slam ? 0.18 : 0.45) : 0, usesShortestUnitArc: true))
        }
        AudioManager.shared.play(slam ? .errorBuzz : .doorRattle)
        rebuildObstacles()
    }

    func lockDoor(_ id: String, _ locked: Bool) {
        doors[id]?.locked = locked
    }

    /// True when the player stands in this door's cells (so it can't slam shut on them).
    func playerInDoor(_ id: String) -> Bool {
        guard let d = doors[id] else { return false }
        let p = controller.position
        return d.cells.contains { c in
            abs(p.x - (d.level.offsetX + Float(c.0) + 0.5)) < 0.8 && abs(p.z - (Float(c.1) + 0.5)) < 0.8
        }
    }

    // MARK: Levels

    func levelOf(x: Float) -> FacilityLevel { x > 60 ? .basement : .ground }

    func placePlayer(_ lvl: FacilityLevel, cellX: Float, cellZ: Float, yaw: Float) {
        level = lvl
        controller.transform = PlayerTransform(x: lvl.offsetX + cellX, y: 0, z: cellZ, yaw: yaw, pitch: 0)
        input.reset()
        syncCamera()
    }

    /// Fade, move, fade back.
    func travel(to lvl: FacilityLevel, cellX: Float, cellZ: Float, yaw: Float, then: (() -> Void)? = nil) {
        cutscene = true
        withAnimationFade(1) { [weak self] in
            guard let self else { return }
            AudioManager.shared.play(.footstep)
            self.placePlayer(lvl, cellX: cellX, cellZ: cellZ, yaw: yaw)
            self.robot?.playerChangedLevel(to: lvl)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                self.hud.fade = 0
                self.cutscene = false
                then?()
            }
        }
    }

    private func withAnimationFade(_ to: Double, _ done: @escaping () -> Void) {
        hud.fade = to
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: done)
    }

    // MARK: Loop

    func attach(to view: SCNView) {
        view.scene = scene
        view.pointOfView = cameraNode
        view.isPlaying = true
        view.rendersContinuously = true
        view.antialiasingMode = .multisampling2X
        view.preferredFramesPerSecond = 60
        view.backgroundColor = .black
        link?.invalidate()
        let l = CADisplayLink(target: self, selector: #selector(step(_:)))
        l.add(to: .main, forMode: .common)
        link = l
        lastTime = 0
    }

    func stopLoop() {
        link?.invalidate()
        link = nil
    }

    @objc private func step(_ l: CADisplayLink) {
        let now = l.timestamp
        let dt = lastTime == 0 ? 1.0 / 60 : min(0.05, now - lastTime)
        lastTime = now
        tick(Float(dt))
    }

    private func tick(_ dt: Float) {
        guard let s = session else { return }
        let paused = s.paused || s.screen != .facility || s.inspecting != nil || s.deviceOverlay != nil
        input.enabled = !paused && !cutscene
        if !cutscene {
            let settings = GameSettings.shared
            let footstep = controller.update(dt: paused ? 0 : dt, input: input,
                                             lookScale: Float(0.0055 * settings.lookSensitivity), invertY: settings.invertY)
            if footstep { AudioManager.shared.play(.footstep) }
            syncCamera()
            level = levelOf(x: controller.position.x)
        }
        if !paused {
            robot?.update(dt: dt, world: self)
            StoryDirector.shared.facilityTick(dt: dt, world: self)
        }
        if alarm {
            alarmPhase += dt
            ambient.light?.intensity = CGFloat(22 + 18 * (0.5 + 0.5 * sin(alarmPhase * 4)))
        }
        frame += 1
        if frame % 5 == 0 && !cutscene { updateTarget() }
        if frame % 3 == 0 { trackCameras() }
    }

    func syncCamera() {
        let p = controller.position
        cameraNode.position = SCNVector3(p.x, p.y + controller.eyeHeight, p.z)
        cameraNode.eulerAngles = SCNVector3(controller.pitch, controller.yaw, 0)
    }

    /// After master control opens, every security camera follows the player.
    private func trackCameras() {
        guard session?.has("master_open") == true else { return }
        let p = controller.position
        for c in cameras {
            let cp = c.worldPosition
            guard abs(cp.x - p.x) < 30 else { continue }
            let yaw = atan2(p.x - cp.x, p.z - cp.z)
            c.eulerAngles.y += (yaw - c.eulerAngles.y).wrappedAngle * 0.15
        }
    }

    private func updateTarget() {
        guard let s = session else { return }
        if let t = interaction.target(root: scene.rootNode, camera: cameraNode) {
            let ctx = InteractionContext(session: s, world: nil, node: t.1)
            if let p = t.0.prompt(ctx) {
                currentTarget = t
                if hud.prompt != p { hud.prompt = p }
                return
            }
        }
        currentTarget = nil
        if hud.prompt != nil { hud.prompt = nil }
    }

    func interact() {
        guard let s = session, let t = currentTarget, input.enabled else { return }
        let ctx = InteractionContext(session: s, world: nil, node: t.1)
        guard t.0.prompt(ctx) != nil else { return }
        t.0.interact(ctx)
        updateTarget()
    }

    // MARK: Helpers for content

    func register(_ id: String, prompt: @escaping () -> String?, action: @escaping () -> Void) {
        interaction.register(ActionInteractable(id: id, prompt: { _ in prompt() }, action: { _ in action() }))
    }
}

extension Float {
    /// Wraps an angle to -pi...pi.
    var wrappedAngle: Float {
        var a = self
        while a > .pi { a -= 2 * .pi }
        while a < -.pi { a += 2 * .pi }
        return a
    }
}

/// Keeps the facility alive while the screen is showing it.
@MainActor
enum FacilityHolder {
    static var world: FacilityWorld?
    static func get(_ s: GameSession) -> FacilityWorld {
        if let w = world { return w }
        let w = FacilityWorld(session: s)
        world = w
        StoryDirector.shared.facilityCreated(w)
        return w
    }
    static func reset() {
        world?.stopLoop()
        world = nil
    }
}
