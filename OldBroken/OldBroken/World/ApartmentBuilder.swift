import SceneKit
import UIKit

/// Builds the protagonist's apartment bedroom.
/// Layout (top view, -z is the desk wall):
///
///   z=-2.2  [ shelf ][ desk+PC ]      [   bed   ]
///                     chair            [   bed   ]
///   window(-x)                          nightstand+lamp
///           wardrobe                  door (z=+2.2)
@MainActor
struct ApartmentBuilder {
    static let halfW: Float = 2.6
    static let halfD: Float = 2.2
    static let height: Float = 2.6

    let world: ApartmentWorld
    var root: SCNNode { world.scene.rootNode }

    func build() {
        buildShell()
        buildLighting()
        buildDesk()
        buildBed()
        buildNightstandAndLamp()
        buildDoor()
        buildDressing()          // ApartmentDressing.swift
        world.controller.bounds = AABB2D(x: 0, z: 0, w: Self.halfW * 2, d: Self.halfD * 2)
    }

    // MARK: Shell

    private func buildShell() {
        let wallTex = ProcTex.noiseWall()
        let wall = SK.material(UIColor(red: 0.62, green: 0.60, blue: 0.56, alpha: 1), roughness: 0.92, image: wallTex, repeat: 3)
        let floor = SK.material(.white, roughness: 0.55, image: ProcTex.woodFloor(), repeat: 2)
        let ceiling = SK.material(UIColor(white: 0.7, alpha: 1), roughness: 0.95)
        let trim = SK.material(UIColor(white: 0.85, alpha: 1), roughness: 0.5)

        let w = CGFloat(Self.halfW * 2), d = CGFloat(Self.halfD * 2), h = CGFloat(Self.height)
        SK.box(w + 0.2, 0.1, d + 0.2, floor, at: SCNVector3(0, -0.05, 0), in: root)
        SK.box(w + 0.2, 0.1, d + 0.2, ceiling, at: SCNVector3(0, Self.height + 0.05, 0), in: root)
        // north / south walls
        SK.box(w + 0.2, h, 0.1, wall, at: SCNVector3(0, Self.height / 2, -Self.halfD - 0.05), in: root)
        SK.box(w + 0.2, h, 0.1, wall, at: SCNVector3(0, Self.height / 2, Self.halfD + 0.05), in: root)
        // east wall
        SK.box(0.1, h, d, wall, at: SCNVector3(Self.halfW + 0.05, Self.height / 2, 0), in: root)
        // west wall with a window hole (z 0.0 ... 1.2, y 0.95 ... 2.05)
        let wx = -Self.halfW - 0.05
        SK.box(0.1, h, CGFloat(Self.halfD), wall, at: SCNVector3(wx, Self.height / 2, -Self.halfD / 2), in: root)
        SK.box(0.1, h, CGFloat(Self.halfD - 1.2), wall, at: SCNVector3(wx, Self.height / 2, 1.2 + (Self.halfD - 1.2) / 2), in: root)
        SK.box(0.1, 0.95, 1.2, wall, at: SCNVector3(wx, 0.475, 0.6), in: root)
        SK.box(0.1, CGFloat(Self.height - 2.05), 1.2, wall, at: SCNVector3(wx, (2.05 + Self.height) / 2, 0.6), in: root)
        // skirting boards
        SK.box(w, 0.08, 0.02, trim, at: SCNVector3(0, 0.04, -Self.halfD + 0.01), in: root)
        SK.box(w, 0.08, 0.02, trim, at: SCNVector3(0, 0.04, Self.halfD - 0.01), in: root)
        SK.box(0.02, 0.08, d, trim, at: SCNVector3(Self.halfW - 0.01, 0.04, 0), in: root)
    }

    private func buildLighting() {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.color = UIColor(red: 0.30, green: 0.34, blue: 0.48, alpha: 1)
        ambient.light!.intensity = 55
        root.addChildNode(ambient)

        // moonlight spilling through the window onto the floor
        let moon = SCNNode()
        moon.light = SCNLight()
        moon.light!.type = .spot
        moon.light!.color = UIColor(red: 0.55, green: 0.65, blue: 1, alpha: 1)
        moon.light!.intensity = 260
        moon.light!.spotInnerAngle = 25
        moon.light!.spotOuterAngle = 70
        moon.light!.attenuationEndDistance = 7
        moon.position = SCNVector3(-2.4, 2.0, 0.6)
        moon.look(at: SCNVector3(0.2, 0, 0.9))
        root.addChildNode(moon)
        world.nodes["moonLight"] = moon
    }

    // MARK: Desk + computer

    private func buildDesk() {
        let wood = SK.material(UIColor(red: 0.18, green: 0.13, blue: 0.10, alpha: 1), roughness: 0.6)
        let black = SK.material(UIColor(white: 0.04, alpha: 1), roughness: 0.4, metalness: 0.2)
        let plastic = SK.material(UIColor(white: 0.10, alpha: 1), roughness: 0.55)

        let desk = SK.group("desk", at: SCNVector3(-0.9, 0, -1.82), in: root)
        SK.box(1.4, 0.04, 0.7, wood, at: SCNVector3(0, 0.74, 0), in: desk)
        for (x, z) in [(-0.66, -0.31), (0.66, -0.31), (-0.66, 0.31), (0.66, 0.31)] as [(Float, Float)] {
            SK.box(0.04, 0.72, 0.04, black, at: SCNVector3(x, 0.36, z), in: desk)
        }
        world.controller.obstacles.append(AABB2D(x: -0.9, z: -1.82, w: 1.44, d: 0.74))

        // the computer: monitor, keyboard, mouse, tower — one interactable
        let pc = SK.group(InteractionSystem.prefix + "computer", at: SCNVector3(-0.9, 0, -1.82), in: root)
        SK.box(0.07, 0.16, 0.06, black, at: SCNVector3(0, 0.84, -0.2), in: pc)
        SK.box(0.24, 0.012, 0.16, black, at: SCNVector3(0, 0.766, -0.2), in: pc)
        SK.box(0.66, 0.40, 0.035, black, at: SCNVector3(0, 1.10, -0.21), in: pc, chamfer: 0.01)
        let screenMat = SK.material(.black, roughness: 0.2, emission: nil)
        screenMat.lightingModel = .constant
        screenMat.diffuse.contents = ProcTex.monitorIdle()
        let screen = SK.plane(0.62, 0.36, screenMat, at: SCNVector3(0, 1.10, -0.191), in: pc, name: "monitorScreen")
        world.nodes["monitorScreen"] = screen
        let screenLight = SCNNode()
        screenLight.light = SK.omni(UIColor(red: 0.55, green: 0.7, blue: 1, alpha: 1), intensity: 140, range: 3.2, shadows: false)
        screenLight.position = SCNVector3(0, 1.1, 0.1)
        pc.addChildNode(screenLight)
        world.nodes["monitorLight"] = screenLight

        SK.box(0.44, 0.022, 0.14, plastic, at: SCNVector3(0, 0.771, 0.12), in: pc, chamfer: 0.006)
        let keysMat = SK.material(UIColor(white: 0.16, alpha: 1), roughness: 0.6)
        for row in 0..<4 {
            SK.box(0.40, 0.006, 0.022, keysMat, at: SCNVector3(0, 0.785, 0.07 + Float(row) * 0.03), in: pc)
        }
        SK.box(0.06, 0.02, 0.1, plastic, at: SCNVector3(0.32, 0.77, 0.12), in: pc, chamfer: 0.01)
        // tower under the desk with a faint power LED
        SK.box(0.2, 0.45, 0.45, black, at: SCNVector3(0.5, 0.225, 0), in: pc)
        let led = SK.material(.black, emission: UIColor(red: 0.3, green: 0.6, blue: 1, alpha: 1))
        SK.box(0.01, 0.01, 0.01, led, at: SCNVector3(0.4, 0.40, 0.226), in: pc)

        // office chair (pushed in a little)
        let chair = SK.group("chair", at: SCNVector3(-0.85, 0, -1.12), in: root)
        let fabric = SK.material(UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1), roughness: 0.9)
        SK.box(0.48, 0.07, 0.46, fabric, at: SCNVector3(0, 0.47, 0), in: chair, chamfer: 0.02)
        SK.box(0.46, 0.55, 0.06, fabric, at: SCNVector3(0, 0.8, 0.22), in: chair, chamfer: 0.02)
        SK.cylinder(0.025, 0.4, black, at: SCNVector3(0, 0.24, 0), in: chair)
        SK.box(0.5, 0.03, 0.06, black, at: SCNVector3(0, 0.05, 0), in: chair)
        SK.box(0.06, 0.03, 0.5, black, at: SCNVector3(0, 0.05, 0), in: chair)
        chair.eulerAngles.y = 0.25
        world.controller.obstacles.append(AABB2D(x: -0.85, z: -1.12, w: 0.42, d: 0.42))
    }

    // MARK: Bed

    private func buildBed() {
        let frame = SK.material(UIColor(red: 0.22, green: 0.16, blue: 0.12, alpha: 1), roughness: 0.7)
        let sheet = SK.material(UIColor(red: 0.62, green: 0.64, blue: 0.68, alpha: 1), roughness: 0.95)
        let blanket = SK.material(UIColor(red: 0.20, green: 0.26, blue: 0.36, alpha: 1), roughness: 0.95)
        let bed = SK.group(InteractionSystem.prefix + "bed", at: SCNVector3(2.05, 0, -1.2), in: root)
        SK.box(1.05, 0.3, 2.05, frame, at: SCNVector3(0, 0.15, 0), in: bed)
        SK.box(1.05, 0.7, 0.06, frame, at: SCNVector3(0, 0.35, -1.0), in: bed)
        SK.box(0.98, 0.2, 1.98, sheet, at: SCNVector3(0, 0.4, 0), in: bed, chamfer: 0.04)
        SK.box(1.0, 0.06, 1.3, blanket, at: SCNVector3(0, 0.52, 0.32), in: bed, chamfer: 0.03)
        SK.box(0.6, 0.12, 0.34, sheet, at: SCNVector3(0, 0.56, -0.72), in: bed, chamfer: 0.05)
        world.controller.obstacles.append(AABB2D(x: 2.05, z: -1.2, w: 1.1, d: 2.1))
    }

    private func buildNightstandAndLamp() {
        let wood = SK.material(UIColor(red: 0.25, green: 0.18, blue: 0.13, alpha: 1), roughness: 0.65)
        SK.box(0.45, 0.55, 0.42, wood, at: SCNVector3(2.3, 0.275, 0.12), in: root)
        world.controller.obstacles.append(AABB2D(x: 2.3, z: 0.12, w: 0.47, d: 0.44))

        let lamp = SK.group(InteractionSystem.prefix + "lamp", at: SCNVector3(2.3, 0.55, 0.12), in: root)
        let brass = SK.material(UIColor(red: 0.6, green: 0.48, blue: 0.3, alpha: 1), roughness: 0.35, metalness: 0.8)
        SK.cylinder(0.07, 0.02, brass, at: SCNVector3(0, 0.01, 0), in: lamp)
        SK.cylinder(0.012, 0.3, brass, at: SCNVector3(0, 0.16, 0), in: lamp)
        let shadeMat = SK.material(UIColor(red: 0.95, green: 0.85, blue: 0.7, alpha: 1), roughness: 0.9,
                                   emission: UIColor(red: 1, green: 0.7, blue: 0.4, alpha: 1))
        let shade = SCNNode(geometry: SCNCone(topRadius: 0.07, bottomRadius: 0.13, height: 0.16))
        shade.geometry!.materials = [shadeMat]
        shade.position = SCNVector3(0, 0.36, 0)
        lamp.addChildNode(shade)
        world.nodes["lampShade"] = shade

        let light = SCNNode()
        light.light = SK.omni(UIColor(red: 1, green: 0.72, blue: 0.45, alpha: 1), intensity: 520, range: 6.5, shadows: true)
        light.position = SCNVector3(0, 0.34, 0)
        lamp.addChildNode(light)
        world.nodes["lampLight"] = light
    }

    // MARK: Door

    private func buildDoor() {
        let doorMat = SK.material(UIColor(red: 0.78, green: 0.76, blue: 0.72, alpha: 1), roughness: 0.6)
        let metal = SK.material(UIColor(white: 0.7, alpha: 1), roughness: 0.3, metalness: 0.9)
        let trim = SK.material(UIColor(white: 0.85, alpha: 1), roughness: 0.5)
        // frame
        SK.box(1.02, 0.06, 0.06, trim, at: SCNVector3(1.4, 2.08, Self.halfD - 0.02), in: root)
        SK.box(0.06, 2.1, 0.06, trim, at: SCNVector3(0.92, 1.05, Self.halfD - 0.02), in: root)
        SK.box(0.06, 2.1, 0.06, trim, at: SCNVector3(1.88, 1.05, Self.halfD - 0.02), in: root)
        // hinge pivot so the door can rattle
        let pivot = SK.group(InteractionSystem.prefix + "door", at: SCNVector3(0.95, 0, Self.halfD - 0.03), in: root)
        SK.box(0.9, 2.04, 0.04, doorMat, at: SCNVector3(0.45, 1.02, 0), in: pivot)
        SK.cylinder(0.025, 0.02, metal, at: SCNVector3(0.8, 1.0, -0.03), in: pivot).eulerAngles.x = .pi / 2
        SK.box(0.1, 0.018, 0.018, metal, at: SCNVector3(0.76, 1.0, -0.05), in: pivot)
        world.nodes["door"] = pivot
    }
}
