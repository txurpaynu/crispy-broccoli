import SwiftUI
import SceneKit

/// Facility-only UI state: the keypad, progress bars, the catch flash.
@MainActor
final class FacilityUI: ObservableObject {
    static let shared = FacilityUI()
    @Published var keypad = false
    @Published var entry = ""
    @Published var progress: Double?
    @Published var progressLabel = ""
    @Published var caught = false
    @Published var alarm = false
}

/// CHAPTERS 6–8 — THE FACILITY, THE LAST DEVELOPER, OUT OF BOUNDS
extension StoryDirector {
    var fw: FacilityWorld? { FacilityHolder.world }
    var fui: FacilityUI { FacilityUI.shared }

    func startOnce(_ id: String) {
        let k = "seen_" + id
        guard !session.has(k) else { return }
        session.set(k)
        whenQuiet { [weak self] in self?.start(id) }
    }

    // MARK: Set-up from flags (new arrival or loading a save)

    func facilityCreated(_ w: FacilityWorld) {
        let s = session
        w.lockDoor("entrance", true)
        w.lockDoor("dock", true)
        w.lockDoor("halden", !s.has("item_halden_key"))
        w.lockDoor("server", true)
        w.lockDoor("restricted", true)
        w.lockDoor("stair", !s.has("master_open"))
        if s.has("dev_power") { workstationOn(w, net: s.has("ch6_connected")) }
        if s.has("master_open") { powerOn(w) }
        if s.has("laptop_on_bench") { putLaptopOnBench(w) }
        if s.has("robot_awake") {
            w.robot?.standAwake()
            lockdown(w)
        }
        w.robot?.onCatch = { [weak self] in self?.caught() }
        if s.has("item_keycard") { w.scene.rootNode.childNode(withName: InteractionSystem.prefix + "keycard", recursively: true)?.isHidden = true }
        let cranks = s.counter("dock_cranks")
        if cranks > 0 { w.doors["dock"]?.pivot.position.y = Float(cranks) * 0.32 }

        // where to stand
        if s.has("robot_awake") {
            respawn(w)
        } else if s.has("robot_seen") {
            w.placePlayer(.basement, cellX: 19, cellZ: 12.5, yaw: .pi)
        } else if s.has("master_open") {
            w.placePlayer(.ground, cellX: 4.5, cellZ: 14.6, yaw: 0)
        } else if s.has("ch6_connected") {
            w.placePlayer(.ground, cellX: 35.5, cellZ: 11.2, yaw: 0)
        } else {
            w.placePlayer(.ground, cellX: 8.5, cellZ: 23.6, yaw: 0)
        }
        if !s.has("seen_ch6_arrive") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in self?.startOnce("ch6_arrive") }
        }
    }

    // MARK: Flags

    func facilityFlag(_ f: String) {
        guard let w = fw else { return }
        switch f {
        case "dev_power":
            workstationOn(w, net: false)
        case "ch6_connected":
            workstationOn(w, net: true)
        case "ch7_code_needed", "doc_halden_code_memo", "doc_wren_log_3":
            if session.has("ch7_code_needed") && session.has("doc_halden_code_memo") && session.has("doc_wren_log_3")
                && !session.has("ch7_code_known") {
                session.set("ch7_code_known")
                whenQuiet { [weak self] in self?.start("ch7_found_code") }
            }
        case "master_open":
            powerOn(w)
            w.lockDoor("stair", false)
            AudioManager.shared.play(.powerOn)
            start("ch7_master_open")
            session.autosave()
        case "robot_awake":
            lockdown(w)
            w.robot?.start(.stalk, speed: 0.7)
            session.autosave()
        case "usb_copied":
            w.robot?.start(.hunt, speed: 2.35)
            AudioManager.shared.setScene(.chase)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.start("ch8_pa_copy") }
            session.autosave()
        default: break
        }
    }

    private func workstationOn(_ w: FacilityWorld, net: Bool) {
        guard let screen = w.nodes["workstation"] else { return }
        let img = SK.render(CGSize(width: 512, height: 316)) { c, s in
            c.setFillColor(UIColor(red: 0.02, green: 0.04, blue: 0.1, alpha: 1).cgColor)
            c.fill(CGRect(origin: .zero, size: s))
            let lines = net
                ? ["HALDEN NET  v3.1", "", "> VXL connected (laptop, usb0)", "> mail archive ........ OPEN", "> build server ........ OPEN",
                   "> /projects/WREN ...... LOCKED", "> MASTER CONTROL ...... LOCKED", "", "  developer access code required"]
                : ["REAWAKENED // build workstation", "", "booting from UPS...", "network: halden.local", "", "waiting for device on usb0_"]
            for (i, l) in lines.enumerated() {
                (l as NSString).draw(at: CGPoint(x: 18, y: 18 + CGFloat(i) * 30), withAttributes: [
                    .font: UIFont.monospacedSystemFont(ofSize: 20, weight: .medium),
                    .foregroundColor: net && l.contains("VXL") ? UIColor(red: 1, green: 0.4, blue: 0.75, alpha: 1)
                        : UIColor(red: 0.6, green: 0.8, blue: 1, alpha: 1),
                ])
            }
        }
        let m = screen.geometry!.firstMaterial!
        m.diffuse.contents = UIColor.black
        m.emission.contents = img
        w.nodes["workstationGlow"]?.light?.intensity = 120
    }

    private func powerOn(_ w: FacilityWorld) {
        w.applyPower()
        w.scene.rootNode.enumerateChildNodes { n, _ in
            if n.name == "rackled" || n.name == "camled" { n.isHidden = false }
        }
        w.nodes["master"]?.geometry?.firstMaterial?.emission.contents = UIColor(red: 0.1, green: 0.6, blue: 0.3, alpha: 1)
    }

    private func lockdown(_ w: FacilityWorld) {
        w.applyPower()
        fui.alarm = true
        w.setDoor("lobby_inner", open: false, animated: false)
        w.lockDoor("lobby_inner", true)
        w.lockDoor("entrance", true)
        w.lockDoor("restricted", false)
        w.lockDoor("server", false)
        AudioManager.shared.setScene(session.has("usb_copied") ? .chase : .facility)
        AudioManager.shared.setDread(0.6)
        if session.has("usb_copied") { w.robot?.start(.hunt, speed: 2.35) } else if w.robot?.mode != .waking { w.robot?.start(.stalk, speed: 0.7) }
    }

    // MARK: Doors

    func facilityDoorPrompt(_ id: String, door: FacilityDoor) -> String? {
        switch id {
        case "entrance": return session.has("robot_awake") ? "Locked. He did this." : "Front door (jammed)"
        case "dock": return session.has("robot_awake") ? "Loading dock shutter (use the crank)" : "Loading dock (rusted shut)"
        case "stair" where door.locked: return "Stairwell (locked electronically)"
        case "server", "restricted":
            if door.locked { return session.hasItem("keycard") ? "Swipe keycard" : "Locked. Needs a keycard." }
        case "halden" where door.locked: return "T. Halden (locked)"
        case "lobby_inner" where door.locked: return "Locked"
        default: break
        }
        return nil
    }

    func facilityDoorUsed(_ id: String, door: FacilityDoor) -> Bool {
        guard let w = fw else { return false }
        switch id {
        case "entrance", "dock":
            AudioManager.shared.play(.doorRattle)
            if id == "entrance" && !session.has("robot_awake") { session.say("It jammed behind me. The way out is the loading dock at the back.") }
            return true
        case "server", "restricted":
            if door.locked && session.hasItem("keycard") {
                AudioManager.shared.play(.uiConfirm)
                w.lockDoor(id, false)
                w.setDoor(id, open: true)
                return true
            }
        case "halden":
            if door.locked {
                AudioManager.shared.play(.doorRattle)
                if session.has("ch7_code_needed") { startOnce("ch7_halden_locked") }
                else { session.say("Locked. \"T. HALDEN\" on the glass.") }
                return true
            }
        case "stair":
            if door.locked {
                AudioManager.shared.play(.errorBuzz)
                session.say("A red light on the lock. Something controls it.")
                return true
            }
        default: break
        }
        return false
    }

    // MARK: Documents

    func facilityDocRead(_ doc: String) {
        switch doc {
        case "wren_proposal", "wren_log_1", "wren_log_3", "marcus_incident", "board_cancel", "priya_ethics":
            if session.has("ch6_connected") { startOnce("ch7_wren_first") }
        case "vxl_port":
            if session.has("ch6_connected") { startOnce("ch7_vxl_doc") }
        case "rosa_last":
            session.say("\"Please leave it asleep.\"")
        default: break
        }
    }

    // MARK: The development floor

    func workstationPrompt() -> String? {
        if !session.has("dev_power") { return "Workstation (no power)" }
        if !session.has("ch6_connected") { return "Connect laptop" }
        return "HALDEN NET"
    }

    func useWorkstation() {
        if !session.has("dev_power") {
            AudioManager.shared.play(.mouseClick)
            startOnce("ch6_dark_dev")
            session.set("dev_seen")
        } else if !session.has("ch6_connected") {
            AudioManager.shared.play(.pickup)
            session.set("ch6_connected")
            start("ch6_connect")
        } else {
            AudioManager.shared.play(.keyTap)
            session.say(session.has("master_open") ? "Every line on the screen says OPEN now." : "MASTER CONTROL: LOCKED. Developer access code required.")
        }
    }

    func generatorPrompt() -> String? {
        if session.has("dev_power") { return "Generator (running)" }
        return session.has("dev_seen") ? "Pull starter cord" : "Generator"
    }

    func useGenerator() {
        guard session.has("dev_seen"), !session.has("dev_power") else {
            if !session.has("dev_power") { session.say("A portable generator. The tank sloshes. Someone filled it.") }
            return
        }
        let n = session.increment("gen_pulls")
        if n < 3 {
            AudioManager.shared.play(.powerOff)
            if n == 1 { start("ch6_gen_fail") } else { session.say("It coughs. Almost.") }
        } else {
            AudioManager.shared.play(.powerOn)
            session.set("dev_power")
            start("ch6_gen_ok")
        }
    }

    // MARK: Master control

    func masterPrompt() -> String? {
        if session.has("master_open") { return "MASTER CONTROL" }
        return session.has("ch6_connected") ? "Enter access code" : "Terminal (locked)"
    }

    func useMaster() {
        if session.has("master_open") {
            session.say("DOORS: VXL. CAMERAS: VXL. LIGHTS: VXL. B1 LAB: VXL.")
            return
        }
        guard session.has("ch6_connected") else {
            session.say("A green cursor blinks. ENTER DEVELOPER ACCESS CODE.")
            return
        }
        if session.has("ch7_code_known") && !session.has("ch7_asked") {
            session.set("ch7_asked")
            start("ch7_ask_source")
            afterDialogue.append { [weak self] in self?.fui.keypad = true }
            return
        }
        fui.entry = ""
        fui.keypad = true
    }

    func submitCode(_ code: String) {
        fui.keypad = false
        if code == "0412" {
            AudioManager.shared.play(.decryptSuccess)
            session.set("master_open")
        } else {
            AudioManager.shared.play(.errorBuzz)
            start("ch7_keypad_wrong")
        }
    }

    // MARK: The basement

    func arrivedBasement() {
        if session.has("robot_awake") { return }
        if session.has("master_open") && !session.has("seen_b1") {
            session.set("seen_b1")
            session.say("It's warm down here. The lights came on as I walked in.")
        }
    }

    func arrivedGround() {
        guard session.has("usb_copied") else { return }
        if !session.has("cp_ground") {
            session.set("cp_ground")
            start("ch8_pa_stairs")
        }
    }

    func robotPrompt() -> String? {
        if session.has("robot_awake") { return nil }
        if session.has("robot_seen") && !session.has("laptop_on_bench") { return "WREN-4" }
        return "Robot (switched off)"
    }

    func useRobot() {
        if session.has("robot_seen") && !session.has("laptop_on_bench") {
            whenQuiet { [weak self] in self?.start("ch8_robot_ask") }
        } else {
            session.say("It's cold. There's dust on its shoulders, but not on its face.")
        }
    }

    func benchPrompt() -> String? { nil }
    func useBench() {}

    private func putLaptopOnBench(_ w: FacilityWorld) {
        guard w.nodes["benchLaptop"] == nil, let bench = w.nodes["bench"] else { return }
        if let lap = ModelLibrary.place("classic_laptop", at: SCNVector3(bench.position.x, 0.82, bench.position.z), yaw: 0.4, height: 0.22, in: w.scene.rootNode) {
            w.nodes["benchLaptop"] = lap
        }
    }

    /// Vexley moves into WREN-4.
    func transferCutscene() {
        guard let w = fw, let robot = w.robot else { return }
        session.set("laptop_on_bench")
        session.removeItem("laptop")
        putLaptopOnBench(w)
        w.cutscene = true
        AudioManager.shared.play(.glitchLong)
        var flick: [SCNAction] = []
        for i in 0..<8 {
            flick.append(.run { _ in Task { @MainActor in
                w.ambient.light?.intensity = i % 2 == 0 ? 2 : 90
                w.hud.flicker = i % 2 == 0
            } })
            flick.append(.wait(duration: 0.12 + Double(i) * 0.03))
        }
        w.scene.rootNode.runAction(.sequence(flick)) {
            Task { @MainActor in
                w.applyPower()
                w.hud.flicker = false
                // face the robot
                let rp = robot.node.position, p = w.controller.position
                w.controller.yaw = atan2(-(rp.x - p.x), -(rp.z - p.z))
                w.controller.pitch = -0.1
                w.syncCamera()
                AudioManager.shared.play(.heartbeat)
                robot.wake { [weak self] in
                    w.cutscene = false
                    self?.start("ch8_awake")
                }
            }
        }
    }

    func archivePrompt() -> String? {
        if session.has("usb_copied") { return nil }
        if session.has("robot_awake") { return fui.progress == nil ? "Copy PAPERLIGHT to a USB drive" : nil }
        return session.has("master_open") ? "Archive terminal" : "Archive terminal (no power)"
    }

    func useArchive() {
        guard session.has("robot_awake") else {
            session.say(session.has("master_open") ? "/archive/paperlight/0.7.3_src. The real thing. It was never locked." : "Dead.")
            if session.has("master_open") { vexley.remember("sam_saw_unlocked_source") }
            return
        }
        AudioManager.shared.play(.pickup)
        session.addItem("usb")
        fui.progressLabel = "Copying paperlight_073_src.zip to USB"
        fui.progress = 0
        Task { @MainActor in
            for i in 1...40 {
                try? await Task.sleep(nanoseconds: 150_000_000)
                fui.progress = Double(i) / 40
                if i % 4 == 0 { AudioManager.shared.play(.decryptTick) }
            }
            fui.progress = nil
            AudioManager.shared.play(.downloadDone)
            session.set("usb_copied")
        }
    }

    // MARK: Escape

    func crankPrompt() -> String? {
        guard session.has("robot_awake") else { return "Shutter crank (seized)" }
        return session.has("usb_copied") ? "Turn the crank" : "Shutter crank"
    }

    func useCrank() {
        guard let w = fw, session.has("usb_copied") else {
            session.say(session.has("robot_awake") ? "Not without the game. Not after all this." : "Rusted. It would take forever.")
            return
        }
        let n = session.increment("dock_cranks")
        AudioManager.shared.play(.doorRattle)
        w.nodes["crank"]?.runAction(.rotateBy(x: .pi, y: 0, z: 0, duration: 0.4))
        w.doors["dock"]?.pivot.runAction(.moveBy(x: 0, y: 0.32, z: 0, duration: 0.4))
        if n == 2 { start("ch8_pa_dock") }
        if n >= 6 { escape() }
    }

    private func escape() {
        guard let w = fw else { return }
        w.cutscene = true
        w.robot?.start(.frozen, speed: 0)
        session.set("escaped")
        w.hud.fade = 1
        AudioManager.shared.setScene(.silence)
        AudioManager.shared.setDread(0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            guard let self else { return }
            self.fui.alarm = false
            self.session.screen = .ending
            self.session.autosave()
            FacilityHolder.reset()
        }
    }

    // MARK: The chase

    func caught() {
        guard let w = fw, !fui.caught else { return }
        fui.caught = true
        w.cutscene = true
        w.robot?.start(.frozen, speed: 0)
        AudioManager.shared.play(.glitchLong)
        AudioManager.shared.play(.heartbeat)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            guard let self, let w = self.fw else { return }
            self.respawn(w)
            self.fui.caught = false
            w.cutscene = false
            self.start("ch8_pa_caught")
        }
    }

    /// Back to the last checkpoint, with the robot a fair distance away.
    func respawn(_ w: FacilityWorld) {
        guard let robot = w.robot else { return }
        if session.has("cp_ground") {
            w.placePlayer(.ground, cellX: 21.5, cellZ: 20.5, yaw: .pi / 2)
            robot.teleport(.basement, x: 3, z: 3)
            robot.start(.hunt, speed: 2.35)
            robot.playerChangedLevel(to: .ground)
        } else if session.has("usb_copied") {
            w.placePlayer(.basement, cellX: 11, cellZ: 3, yaw: .pi)
            robot.teleport(.basement, x: 26, z: 16.5)
            robot.start(.hunt, speed: 2.35)
        } else {
            w.placePlayer(.basement, cellX: 14, cellZ: 6.5, yaw: .pi / 2)
            robot.teleport(.basement, x: 22, z: 16.5)
            robot.start(.stalk, speed: 0.7)
        }
        w.hud.fade = 0
    }

    func robotArrived(on lvl: FacilityLevel) {
        if lvl == .ground && !session.has("pa_stairs_arrive") {
            session.set("pa_stairs_arrive")
            session.say("Heavy steps on the stairs.")
        }
    }

    // MARK: Per-frame

    func facilityTick(dt: Float, world w: FacilityWorld) {
        let p = w.controller.position
        guard let room = w.room(at: p) else { return }
        switch room {
        case "dev":
            if !session.has("dev_seen") {
                session.set("dev_seen")
                startOnce("ch6_dark_dev")
            }
        case "robolab":
            if session.has("master_open") && !session.has("robot_seen") {
                session.set("robot_seen")
                start("ch8_robot_seen")
            }
        case "corridor2":
            // he slams the lab door as the player runs past
            if session.has("usb_copied") && !session.has("slam1") && p.z < 14.5 && p.z > 12 {
                session.set("slam1")
                w.setDoor("lab_e", open: false, slam: true)
                w.lockDoor("lab_e", true)
                start("ch8_pa_slam")
            }
        default: break
        }
    }

    func facilityEvent(_ e: String) -> Bool {
        switch e {
        case "vx_transfer":
            transferCutscene()
            return true
        default:
            return false
        }
    }
}

extension FacilityWorld {
    /// The named room containing a world position, if any.
    func room(at p: SIMD3<Float>) -> String? {
        let lvl = levelOf(x: p.x)
        let x = Int(floor(p.x - lvl.offsetX)), z = Int(floor(p.z))
        for (name, r) in map.rooms where r[4] == lvl.rawValue {
            if x >= r[0] && x <= r[2] && z >= r[1] && z <= r[3] { return name }
        }
        return nil
    }
}
