import SceneKit
import UIKit

/// Dresses the facility with the CC0 Poly Haven models and adds every interactable.
/// Coordinates are in cells (1 m), measured from each floor's top-left corner.
@MainActor
enum FacilityContent {
    static func populate(_ w: FacilityWorld) {
        let g = FacilityLevel.ground, b = FacilityLevel.basement
        let root = w.scene.rootNode

        /// Places a model; `block` adds a collision box of that footprint.
        @discardableResult
        func prop(_ name: String, _ lvl: FacilityLevel, _ x: Float, _ z: Float, yaw: Float = 0, y: Float = 0,
                  anchorTop: Bool = false, h: Float? = nil, block: (Float, Float)? = nil, node: String? = nil) -> SCNNode? {
            let n = ModelLibrary.place(name, at: w.pos(lvl, x, z, y: y), yaw: yaw, height: h, anchorTop: anchorTop,
                                       in: root, nodeName: node)
            if let (bw, bd) = block {
                let swap = abs(sin(yaw)) > 0.7
                w.propObstacles.append(AABB2D(x: lvl.offsetX + x, z: z, w: swap ? bd : bw, d: swap ? bw : bd))
            }
            return n
        }
        /// A sheet of paper (or a folder) on a surface that opens a document.
        func paper(_ doc: String, _ lvl: FacilityLevel, _ x: Float, _ z: Float, y: Float, yaw: Float = 0,
                   onRead: (@MainActor () -> Void)? = nil) {
            let n = SK.box(0.22, 0.006, 0.3, SK.material(UIColor(white: 0.88, alpha: 1), roughness: 0.9),
                           at: w.pos(lvl, x, z, y: y + 0.003), in: root, name: InteractionSystem.prefix + "doc_" + doc)
            n.eulerAngles.y = yaw
            w.register("doc_" + doc, prompt: { "Read" }) {
                AudioManager.shared.play(.paper)
                w.session?.inspect(doc)
                onRead?()
                StoryDirector.shared.facilityDocRead(doc)
            }
        }
        func desk(_ lvl: FacilityLevel, _ x: Float, _ z: Float, yaw: Float = 0, chair: Bool = true) {
            prop("metal_office_desk", lvl, x, z, yaw: yaw, h: 0.76, block: (1.6, 0.8))
            if chair {
                let cz: Float = cos(yaw) > 0 ? 0.75 : -0.75
                prop("SchoolChair_01", lvl, x + (abs(sin(yaw)) > 0.7 ? -cz * sin(yaw) : 0), z + (abs(sin(yaw)) > 0.7 ? 0 : cz),
                     yaw: yaw + .pi + Float.random(in: -0.4...0.4), h: 0.9)
            }
        }
        func camera(_ lvl: FacilityLevel, _ x: Float, _ z: Float) {
            if let c = prop("security_camera_01", lvl, x, z, y: 2.62, node: "seccam") {
                w.cameras.append(c)
                let led = SK.box(0.02, 0.02, 0.02, SK.material(.black, emission: UIColor(red: 1, green: 0.1, blue: 0.1, alpha: 1)),
                                 at: SCNVector3(0, 0.1, 0.1), in: c, name: "camled")
                led.isHidden = true
            }
        }

        // ---------- LOBBY ----------
        desk(g, 6, 20.6, yaw: 0, chair: false)
        prop("SchoolChair_01", g, 6, 19.5, yaw: .pi, h: 0.9)
        paper("visitor_log", g, 5.6, 20.6, y: 0.76) {
            StoryDirector.shared.startOnce("ch6_lobby_desk")
        }
        prop("Sofa_01", g, 12.5, 23.5, yaw: .pi, h: 0.8, block: (1.6, 0.7))
        prop("CoffeeTable_01", g, 12.5, 22.3, h: 0.45, block: (1.4, 0.8))
        prop("potted_plant_02", g, 14.4, 18.6, h: 1.1, block: (0.5, 0.5))
        prop("WetFloorSign_01", g, 9.2, 21.5, yaw: 0.6, h: 0.62)
        prop("trashbag", g, 2, 23.5, yaw: 1, h: 0.5)
        prop("wall_clock", g, 6, 18.05, y: 2.2, h: 0.3)
        camera(g, 14.5, 18.5)

        // ---------- CORRIDORS ----------
        prop("korean_fire_extinguisher_01", g, 1.3, 7.3, h: 0.55)
        prop("metal_trash_can", g, 22.6, 8.6, h: 0.6, block: (0.5, 0.5))
        prop("plastic_crate_01", g, 17.4, 15, yaw: 0.3, h: 0.3)
        prop("cardboard_box_01", g, 18.6, 22.5, yaw: 0.8, h: 0.4, block: (0.5, 0.5))
        camera(g, 1.5, 7.3)
        camera(g, 17.4, 23.5)
        camera(g, 22.5, 7.3)

        // ---------- HALDEN'S OFFICE ----------
        desk(g, 4, 2.2, yaw: .pi)
        prop("drawer_cabinet", g, 1.5, 4.5, yaw: .pi / 2, h: 1.0, block: (0.6, 0.6))
        prop("standing_chalkboard_01", g, 6.3, 4.6, yaw: -.pi / 2, h: 1.5, block: (0.4, 0.9))
        prop("desk_lamp_arm_01", g, 4.7, 2.0, y: 0.76, h: 0.45)
        paper("office_memo_close", g, 3.3, 2.3, y: 0.76, yaw: 0.2)
        paper("halden_code_memo", g, 1.6, 4.5, y: 1.0, yaw: -0.3)

        // ---------- OFFICE B (Eli, Dana, Marcus) ----------
        desk(g, 9.6, 2.0, yaw: .pi)
        desk(g, 12.6, 2.0, yaw: .pi)
        desk(g, 12.6, 4.6, yaw: 0)
        prop("binder_notebook", g, 12.3, 2.0, y: 0.76, h: 0.06)
        prop("office_notepads", g, 13, 4.6, y: 0.76, h: 0.04)
        paper("dana_lastday", g, 12.9, 2.1, y: 0.76, yaw: -0.2)
        // Eli's drawer: the spare key to Halden's office
        let drawer = SK.box(0.5, 0.16, 0.06, SK.material(UIColor(white: 0.35, alpha: 1), roughness: 0.5, metalness: 0.6),
                            at: w.pos(g, 9.6, 1.55, y: 0.55), in: root, name: InteractionSystem.prefix + "eli_drawer")
        drawer.eulerAngles.y = .pi
        w.register("eli_drawer", prompt: {
            w.session?.has("item_halden_key") == true ? nil : "Open drawer"
        }) {
            AudioManager.shared.play(.pickup)
            drawer.runAction(.moveBy(x: 0, y: 0, z: 0.25, duration: 0.3))
            w.session?.inspect("eli_note_key")
            w.session?.addItem("halden_key")
            w.lockDoor("halden", false)
        }

        // ---------- MEETING ROOM ----------
        prop("WoodenTable_03", g, 19.5, 3, yaw: .pi / 2, h: 0.75, block: (1.0, 2.0))
        for (dx, dz, yaw) in [(-0.9, -0.6, Float.pi / 2), (-0.9, 0.6, .pi / 2), (0.9, 0.3, -.pi / 2), (0.9, -0.7, -.pi / 2.4)] as [(Float, Float, Float)] {
            prop("SchoolChair_01", g, 19.5 + dx, 3 + dz, yaw: yaw, h: 0.9)
        }
        prop("standing_chalkboard_01", g, 23.4, 3, yaw: -.pi / 2, h: 1.5, block: (0.4, 0.9))
        paper("wren_proposal", g, 19.3, 3.3, y: 0.75, yaw: 0.4)

        // ---------- DEVELOPMENT FLOOR ----------
        for row in [3.0, 6.0] as [Float] {
            for col in [27.5, 30.5, 33.5] as [Float] {
                desk(g, col, row, yaw: 0)
                prop("classic_laptop", g, col - 0.2, row - 0.1, yaw: Float.random(in: -0.3...0.3), y: 0.76, h: 0.22)
            }
        }
        prop("hanging_industrial_lamp", g, 30.5, 4.5, y: 3.0, anchorTop: true, h: 1.0)
        prop("steel_frame_shelves_02", g, 37.6, 2, yaw: -.pi / 2, h: 2.0, block: (0.5, 0.7))
        prop("cardboard_box_01", g, 26, 11.4, h: 0.4, block: (0.5, 0.5))
        prop("cardboard_box_01", g, 26.6, 11.5, yaw: 0.5, h: 0.35, block: (0.5, 0.5))
        paper("vxl_port", g, 33.2, 6.1, y: 0.76, yaw: 0.25)
        camera(g, 37.5, 1.4)
        // the remaster workstation (the remaster team brought new machines in)
        desk(g, 35.5, 10, yaw: .pi)
        let monitorMat = SK.material(.black, roughness: 0.3, emission: .black)
        let screen = SK.box(0.62, 0.38, 0.03, monitorMat, at: w.pos(g, 35.5, 9.75, y: 1.02), in: root,
                            name: InteractionSystem.prefix + "workstation")
        SK.box(0.66, 0.42, 0.02, SK.material(UIColor(white: 0.12, alpha: 1), roughness: 0.4), at: SCNVector3(0, 0, -0.025), in: screen)
        SK.box(0.06, 0.16, 0.06, SK.material(UIColor(white: 0.12, alpha: 1)), at: w.pos(g, 35.5, 9.72, y: 0.84), in: root)
        w.nodes["workstation"] = screen
        let glow = SCNNode()
        glow.light = SK.omni(UIColor(red: 0.5, green: 0.6, blue: 1, alpha: 1), intensity: 0, range: 3, shadows: false)
        glow.position = w.pos(g, 35.5, 10.3, y: 1.2)
        root.addChildNode(glow)
        w.nodes["workstationGlow"] = glow
        w.register("workstation", prompt: { StoryDirector.shared.workstationPrompt() }) {
            StoryDirector.shared.useWorkstation()
        }
        // the generator
        prop("portable_generator", g, 37.4, 11.4, yaw: -.pi / 2, h: 0.6, block: (0.8, 0.6), node: InteractionSystem.prefix + "generator")
        w.register("generator", prompt: { StoryDirector.shared.generatorPrompt() }) {
            StoryDirector.shared.useGenerator()
        }
        paper("generator_tag", g, 36.6, 11.6, y: 0.0, yaw: 0.3)

        // ---------- SERVER ROOM ----------
        for z in [11.5, 13.5] as [Float] {
            for x in [2.5, 4.0, 5.5] as [Float] {
                prop("worn_metal_rack", g, x, z, yaw: 0, h: 1.9, block: (0.9, 0.6))
                let led = SK.box(0.5, 0.02, 0.02, SK.material(.black, emission: UIColor(red: 0.2, green: 1, blue: 0.4, alpha: 1)),
                                 at: w.pos(g, x, z + 0.31, y: 1.2), in: root, name: "rackled")
                led.isHidden = true
            }
        }
        prop("modular_industrial_pipes_01", g, 1.2, 15.0, yaw: .pi / 2, h: 2.6)
        camera(g, 6.6, 10.4)
        // master control terminal
        desk(g, 4.5, 15.8, yaw: .pi, chair: false)
        let term = SK.box(0.55, 0.36, 0.03, SK.material(.black, roughness: 0.3, emission: UIColor(red: 0.05, green: 0.25, blue: 0.1, alpha: 1)),
                          at: w.pos(g, 4.5, 16.1, y: 1.0), in: root, name: InteractionSystem.prefix + "master")
        term.eulerAngles.y = .pi
        w.nodes["master"] = term
        w.register("master", prompt: { StoryDirector.shared.masterPrompt() }) {
            StoryDirector.shared.useMaster()
        }

        // ---------- LAB ----------
        prop("tool_cart", g, 10.5, 11, yaw: 0.2, h: 0.95, block: (1.2, 0.7))
        desk(g, 13, 13, yaw: .pi / 2)
        prop("circuit_board", g, 13, 12.7, y: 0.76, h: 0.05)
        prop("circuit_board", g, 12.8, 13.4, yaw: 0.8, y: 0.76, h: 0.05)
        prop("metal_stool_01", g, 10, 15, h: 0.65)
        prop("standing_chalkboard_01", g, 9.5, 13, yaw: .pi / 2, h: 1.5, block: (0.4, 0.9))
        prop("hanging_industrial_lamp", g, 12, 13, y: 3.0, anchorTop: true, h: 1.0)
        paper("wren_log_1", g, 10.4, 11.1, y: 0.95, yaw: -0.4)
        paper("wren_log_3", g, 13.2, 13.5, y: 0.76, yaw: 0.6)
        camera(g, 15.4, 10.4)

        // ---------- STORAGE ----------
        prop("steel_frame_shelves_02", g, 20.4, 11, yaw: .pi / 2, h: 2.0, block: (0.5, 0.7))
        prop("steel_frame_shelves_02", g, 20.4, 14, yaw: .pi / 2, h: 2.0, block: (0.5, 0.7))
        prop("wooden_crate_01", g, 22.6, 15.6, yaw: 0.2, h: 0.5, block: (0.9, 0.5))
        prop("wooden_crate_01", g, 22.7, 15.4, yaw: -0.1, y: 0.5, h: 0.5)
        prop("plastic_crate_01", g, 23, 11, h: 0.3, block: (0.5, 0.4))
        prop("metal_tool_chest", g, 22.8, 13, yaw: -.pi / 2, h: 1.0, block: (0.5, 0.8))
        let card = SK.box(0.085, 0.004, 0.055, SK.material(UIColor(red: 0.9, green: 0.85, blue: 0.3, alpha: 1), roughness: 0.4),
                          at: w.pos(g, 22.8, 13, y: 1.005), in: root, name: InteractionSystem.prefix + "keycard")
        w.register("keycard", prompt: { w.session?.hasItem("keycard") == true ? nil : "Take keycard" }) {
            AudioManager.shared.play(.pickup)
            card.isHidden = true
            w.session?.addItem("keycard")
        }

        // ---------- STAIRWELL ----------
        let stairMat = ModelLibrary.texturedMaterial("concrete_floor_worn_001", repeat: 1) ?? SK.material(UIColor(white: 0.3, alpha: 1))
        for i in 0..<6 {
            SK.box(2.6, 0.18, 0.4, stairMat, at: w.pos(g, 22, 23.8 - Float(i) * 0.02, y: -0.09 - Float(i) * 0.18 + 0.18), in: root)
        }
        let down = SK.box(2.6, 2.0, 0.1, SK.material(.black), at: w.pos(g, 22, 24.95, y: 1.0), in: root,
                          name: InteractionSystem.prefix + "stairs_down")
        down.opacity = 0.98
        w.register("stairs_down", prompt: { "Go down" }) {
            w.travel(to: .basement, cellX: 3, cellZ: 2.2, yaw: .pi) { StoryDirector.shared.arrivedBasement() }
        }
        camera(g, 20.5, 18.5)

        // ---------- RESTRICTED LAB ----------
        prop("industrial_storage_cart", g, 27, 16, yaw: 0.3, h: 1.3, block: (1.5, 1.0))
        prop("hanging_industrial_lamp", g, 31, 19, y: 3.0, anchorTop: true, h: 1.0)
        prop("hanging_industrial_lamp", g, 35, 19, y: 3.0, anchorTop: true, h: 1.0)
        desk(g, 37, 16, yaw: -.pi / 2)
        paper("priya_ethics", g, 37, 16.2, y: 0.76)
        paper("board_cancel", g, 37.1, 15.6, y: 0.76, yaw: 0.6)
        paper("marcus_incident", g, 27.3, 15.9, y: 1.3)
        // the old WREN-3 cradle: a frame with nothing in it
        let frameMat = SK.material(UIColor(white: 0.25, alpha: 1), roughness: 0.4, metalness: 0.8)
        SK.box(1.2, 0.1, 1.0, frameMat, at: w.pos(g, 31, 22.5, y: 0.05), in: root)
        SK.box(0.1, 2.1, 0.1, frameMat, at: w.pos(g, 30.45, 22.5, y: 1.05), in: root)
        SK.box(0.1, 2.1, 0.1, frameMat, at: w.pos(g, 31.55, 22.5, y: 1.05), in: root)
        SK.box(1.2, 0.1, 0.1, frameMat, at: w.pos(g, 31, 22.5, y: 2.1), in: root)
        w.propObstacles.append(AABB2D(x: 31, z: 22.5, w: 1.2, d: 1.0))
        prop("WetFloorSign_01", g, 33.5, 23.6, h: 0.62)
        prop("worn_metal_rack", g, 38, 21, yaw: -.pi / 2, h: 1.9, block: (0.6, 0.9))
        camera(g, 25.5, 14.4)
        // dock crank
        let crank = SK.cylinder(0.12, 0.05, SK.material(UIColor(red: 0.6, green: 0.15, blue: 0.1, alpha: 1), roughness: 0.5, metalness: 0.7),
                                at: w.pos(g, 37.75, 24.4, y: 1.1), in: root, name: InteractionSystem.prefix + "crank")
        crank.eulerAngles.z = .pi / 2
        w.nodes["crank"] = crank
        w.register("crank", prompt: { StoryDirector.shared.crankPrompt() }) {
            StoryDirector.shared.useCrank()
        }

        // ---------- BASEMENT ----------
        let up = SK.box(2.0, 2.0, 0.1, SK.material(.black), at: w.pos(b, 3, 1.05, y: 1.0), in: root,
                        name: InteractionSystem.prefix + "stairs_up")
        up.opacity = 0.98
        w.register("stairs_up", prompt: { "Go up" }) {
            w.travel(to: .ground, cellX: 21.5, cellZ: 23.2, yaw: 0) { StoryDirector.shared.arrivedGround() }
        }
        prop("korean_fire_extinguisher_01", b, 5.6, 3.6, h: 0.55)
        prop("modular_industrial_pipes_01", b, 12, 6.2, yaw: 0, h: 2.7)
        prop("modular_industrial_pipes_01", b, 24, 6.2, yaw: 0, h: 2.7)
        camera(b, 1.5, 6.3)
        camera(b, 27.5, 6.3)
        // archive
        for x in [8.0, 10.0, 12.0] as [Float] {
            prop("steel_frame_shelves_02", b, x, 1.4, h: 2.0, block: (0.7, 0.5))
            prop("binder_notebook", b, x, 1.4, y: 1.05, h: 0.06)
        }
        desk(b, 13.5, 3.4, yaw: -.pi / 2, chair: false)
        let arch = SK.box(0.5, 0.33, 0.03, SK.material(.black, roughness: 0.3, emission: UIColor(red: 0.05, green: 0.08, blue: 0.2, alpha: 1)),
                          at: w.pos(b, 13.85, 3.4, y: 0.98), in: root, name: InteractionSystem.prefix + "archive")
        arch.eulerAngles.y = -.pi / 2
        w.nodes["archive"] = arch
        w.register("archive", prompt: { StoryDirector.shared.archivePrompt() }) {
            StoryDirector.shared.useArchive()
        }
        // generator room
        prop("power_box_01", b, 1.3, 12, yaw: .pi / 2, y: 0.9, h: 0.7)
        prop("utility_box_01", b, 1.3, 14, yaw: .pi / 2, y: 0.9, h: 0.5)
        prop("portable_generator", b, 5, 15, yaw: 0.4, h: 0.6, block: (0.8, 0.6))
        prop("metal_tool_chest", b, 7.6, 10, yaw: -.pi / 2, h: 1.0, block: (0.5, 0.8))
        prop("modular_industrial_pipes_01", b, 4, 18.75, yaw: .pi, h: 2.7)
        // robot lab
        prop("tool_cart", b, 12, 10.5, h: 0.95, block: (1.2, 0.7))
        prop("metal_tool_chest", b, 27.6, 12, yaw: -.pi / 2, h: 1.0, block: (0.5, 0.8))
        prop("industrial_storage_cart", b, 25, 17.3, yaw: .pi, h: 1.3, block: (1.5, 1.0))
        prop("hanging_industrial_lamp", b, 19, 14, y: 3.0, anchorTop: true, h: 1.0)
        prop("circuit_board", b, 18, 15.3, y: 0.76, h: 0.05)
        desk(b, 18.5, 15.6, yaw: 0, chair: false)
        paper("rosa_last", b, 18.9, 15.6, y: 0.76, yaw: -0.3)
        let bench = SK.box(0.4, 0.06, 0.3, SK.material(UIColor(white: 0.2, alpha: 1), roughness: 0.5, metalness: 0.6),
                           at: w.pos(b, 18.0, 15.6, y: 0.79), in: root, name: InteractionSystem.prefix + "bench")
        w.nodes["bench"] = bench
        w.register("bench", prompt: { StoryDirector.shared.benchPrompt() }) {
            StoryDirector.shared.useBench()
        }
        camera(b, 10.5, 9.4)
        // the robot
        let robot = RobotRig()
        robot.node.position = w.pos(b, 20.5, 16.4)
        robot.node.eulerAngles.y = .pi
        root.addChildNode(robot.node)
        w.robot = robot
        w.register("robot", prompt: { StoryDirector.shared.robotPrompt() }) {
            StoryDirector.shared.useRobot()
        }

        // a little dust in the flashlight beam
        let dust = SCNParticleSystem()
        dust.birthRate = 30
        dust.particleLifeSpan = 8
        dust.particleSize = 0.006
        dust.particleColor = UIColor(white: 1, alpha: 0.35)
        dust.emitterShape = SCNBox(width: 6, height: 2.5, length: 6, chamferRadius: 0)
        dust.particleVelocity = 0.03
        dust.particleVelocityVariation = 0.03
        dust.spreadingAngle = 180
        dust.blendMode = .additive
        dust.isAffectedByGravity = false
        let dn = SCNNode()
        dn.position = SCNVector3(0, 1.4, -2)
        dn.addParticleSystem(dust)
        w.cameraNode.addChildNode(dn)
    }
}
