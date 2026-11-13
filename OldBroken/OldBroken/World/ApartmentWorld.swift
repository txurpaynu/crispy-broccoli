import SceneKit
import UIKit
import Combine

/// Published state the SwiftUI HUD needs from the 3D world.
@MainActor
final class ApartmentHUD: ObservableObject {
    @Published var prompt: String?
    @Published var fade: Double = 0
    @Published var flicker = false
}

/// Owns the apartment scene, the player controller and the interaction system.
/// Long-lived: survives switching to the desktop and back.
@MainActor
final class ApartmentWorld: NSObject {
    let scene = SCNScene()
    let controller = FirstPersonController()
    let input = PlayerInput()
    let interaction = InteractionSystem()
    let hud = ApartmentHUD()
    let cameraNode = SCNNode()
    var nodes: [String: SCNNode] = [:]
    weak var session: GameSession?

    var player: FirstPersonController { controller }

    private var link: CADisplayLink?
    private var lastTime: CFTimeInterval = 0
    private var frame = 0
    private var currentTarget: (Interactable, SCNNode)?
    private var cutscene = false
    private var cancellables = Set<AnyCancellable>()
    private(set) var lampOn = true
    private(set) var monitorOn = true

    init(session: GameSession) {
        self.session = session
        super.init()
        scene.background.contents = UIColor.black
        scene.lightingEnvironment.intensity = 0.0
        setupCamera()
        ApartmentBuilder(world: self).build()
        ApartmentInteractables.register(in: self)
        controller.transform = session.data.player
        applyPersistentState()
        HorrorEventManager.shared.attach(world: self, session: session)
    }

    private func setupCamera() {
        let cam = SCNCamera()
        cam.zNear = 0.03
        cam.zFar = 60
        cam.fieldOfView = 72
        cam.wantsHDR = true
        cam.wantsExposureAdaptation = false
        cam.exposureOffset = Lighting.exposure
        cam.bloomIntensity = 0.2
        cam.bloomThreshold = 1.1
        cam.bloomBlurRadius = 10
        cam.vignettingIntensity = 0.7
        cam.vignettingPower = 0.7
        cam.colorFringeStrength = 0.35
        cam.colorFringeIntensity = 0.6
        cam.grainIntensity = 0.12
        cam.grainScale = 1.2
        cam.saturation = 0.88
        cam.contrast = 0.08
        cameraNode.camera = cam
        scene.rootNode.addChildNode(cameraNode)
    }

    /// Re-apply things like a picked-up item being gone after a load.
    func applyPersistentState() {
        guard let s = session else { return }
        for id in s.data.inventory {
            nodes["item_" + id]?.removeFromParentNode()
        }
        setLamp(!s.has("lamp_off"), sound: false)
        refreshMonitor()
    }

    // MARK: View attachment / frame loop

    func attach(to view: SCNView) {
        view.scene = scene
        view.pointOfView = cameraNode
        view.isPlaying = true
        view.rendersContinuously = true
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        view.backgroundColor = .black
        startLoop()
    }

    func startLoop() {
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

    func teardown() {
        stopLoop()
        cancellables.removeAll()
    }

    @objc private func step(_ l: CADisplayLink) {
        let now = l.timestamp
        let dt = lastTime == 0 ? 1.0 / 60 : min(0.05, now - lastTime)
        lastTime = now
        tick(Float(dt))
    }

    private func tick(_ dt: Float) {
        guard let s = session else { return }
        let paused = s.paused || s.screen != .apartment || s.inspecting != nil
        input.enabled = !paused && !cutscene
        if !cutscene {
            let settings = GameSettings.shared
            let footstep = controller.update(dt: paused ? 0 : dt, input: input,
                                             lookScale: Float(0.0055 * settings.lookSensitivity),
                                             invertY: settings.invertY)
            if footstep { AudioManager.shared.play(.footstep) }
            syncCamera()
        }
        HorrorEventManager.shared.tick(dt: dt)

        frame += 1
        if frame % 5 == 0 && !cutscene {
            updateTarget()
        }
    }

    func syncCamera() {
        let p = controller.position
        cameraNode.position = SCNVector3(p.x, p.y + controller.eyeHeight, p.z)
        cameraNode.eulerAngles = SCNVector3(controller.pitch, controller.yaw, 0)
    }

    private func updateTarget() {
        guard let s = session else { return }
        if let t = interaction.target(root: scene.rootNode, camera: cameraNode) {
            let ctx = InteractionContext(session: s, world: self, node: t.1)
            if let p = t.0.prompt(ctx) {
                currentTarget = t
                if hud.prompt != p { hud.prompt = p }
                return
            }
        }
        currentTarget = nil
        if hud.prompt != nil { hud.prompt = nil }
    }

    /// Called by the Use button.
    func interact() {
        guard let s = session, let t = currentTarget, input.enabled else { return }
        let ctx = InteractionContext(session: s, world: self, node: t.1)
        guard t.0.prompt(ctx) != nil else { return }
        t.0.interact(ctx)
        updateTarget()
    }

    // MARK: World reactions (used by interactables and horror events)

    func setLamp(_ on: Bool, sound: Bool = true) {
        lampOn = on
        nodes["lampLight"]?.light?.intensity = on ? Lighting.lamp : 0
        nodes["lampShade"]?.geometry?.firstMaterial?.emission.contents =
            on ? UIColor(red: 1, green: 0.7, blue: 0.4, alpha: 1) : UIColor.black
        if sound { AudioManager.shared.play(.lampSwitch) }
    }

    func flickerLamp(times: Int = 6) {
        guard lampOn, let light = nodes["lampLight"] else { return }
        var actions: [SCNAction] = []
        for i in 0..<times {
            let off = SCNAction.run { _ in light.light?.intensity = (i % 2 == 0 ? Lighting.lamp * 0.1 : Lighting.lamp * 0.7) }
            actions.append(off)
            actions.append(.wait(duration: Double.random(in: 0.04...0.16)))
        }
        actions.append(.run { [weak self] _ in Task { @MainActor in self?.setLamp(self?.lampOn ?? true, sound: false) } })
        light.runAction(.sequence(actions))
        AudioManager.shared.play(.glitch)
    }

    /// Updates the monitor texture based on story state.
    func refreshMonitor() {
        guard let s = session, let screen = nodes["monitorScreen"] else { return }
        let image: UIImage
        if s.has("vexley_refused_exit") {
            image = MonitorImages.vexleyWatching(expression: s.data.vexley.trust >= 2 ? .happy : .worried)
        } else if s.has("old_launched") {
            image = MonitorImages.retroRunning()
        } else {
            image = ProcTex.monitorIdle()
        }
        screen.geometry?.firstMaterial?.diffuse.contents = image
        let tint: UIColor = s.has("old_launched")
            ? UIColor(red: 1, green: 0.45, blue: 0.75, alpha: 1)
            : UIColor(red: 0.55, green: 0.7, blue: 1, alpha: 1)
        nodes["monitorLight"]?.light?.color = tint
    }

    func rattleDoor() {
        guard let door = nodes["door"] else { return }
        AudioManager.shared.play(.doorRattle)
        door.runAction(.sequence([
            .rotateBy(x: 0, y: 0.02, z: 0, duration: 0.05), .rotateBy(x: 0, y: -0.04, z: 0, duration: 0.08),
            .rotateBy(x: 0, y: 0.03, z: 0, duration: 0.06), .rotateBy(x: 0, y: -0.01, z: 0, duration: 0.05),
        ]))
    }

    /// Smoothly moves the camera to sit in front of the monitor, then calls `done`.
    func sitAtComputer(done: @escaping () -> Void) {
        cutscene = true
        hud.prompt = nil
        controller.transform = PlayerTransform(x: -0.9, y: 0, z: -0.95, yaw: 0, pitch: -0.12)
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.9
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        cameraNode.position = SCNVector3(-0.9, 1.12, -1.42)
        cameraNode.eulerAngles = SCNVector3(-0.02, 0, 0)
        SCNTransaction.completionBlock = { DispatchQueue.main.async { done() } }
        SCNTransaction.commit()
        hud.fade = 0
    }

    /// Back to first-person after standing up from the desk.
    func standUp() {
        controller.transform = PlayerTransform(x: -0.9, y: 0, z: -0.55, yaw: 0, pitch: -0.15)
        syncCamera()
        cutscene = false
        input.reset()
        refreshMonitor()
    }

    func runCutscene(_ on: Bool) { cutscene = on }
}
