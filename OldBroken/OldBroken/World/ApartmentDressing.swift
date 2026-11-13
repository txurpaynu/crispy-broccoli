import SceneKit
import UIKit

/// The lived-in details: window, shelf, poster, wardrobe, rug, clutter.
/// Everything the player can pick up or read is named "ia:<id>".
extension ApartmentBuilder {
    func buildDressing() {
        buildWindow()
        buildShelf()
        buildPoster()
        buildWardrobe()
        buildClutter()
    }

    private func buildWindow() {
        let frameMat = SK.material(UIColor(white: 0.88, alpha: 1), roughness: 0.4)
        let viewMat = SK.material(.black)
        viewMat.lightingModel = .constant
        viewMat.diffuse.contents = ProcTex.nightCity()
        let win = SK.group(InteractionSystem.prefix + "window", at: SCNVector3(-2.68, 1.5, 0.6), in: root)
        world.nodes["windowView"] = SK.plane(1.2, 1.1, viewMat, at: SCNVector3(-0.05, 0, 0), yaw: .pi / 2, in: win)
        SK.box(0.08, 0.05, 1.24, frameMat, at: SCNVector3(0.06, 0.55, 0), in: win)
        SK.box(0.08, 0.05, 1.24, frameMat, at: SCNVector3(0.06, -0.55, 0), in: win)
        SK.box(0.08, 1.1, 0.05, frameMat, at: SCNVector3(0.06, 0, -0.6), in: win)
        SK.box(0.08, 1.1, 0.05, frameMat, at: SCNVector3(0.06, 0, 0.6), in: win)
        SK.box(0.05, 1.1, 0.03, frameMat, at: SCNVector3(0.06, 0, 0), in: win)
        // glass with a faint reflection
        let glass = SK.material(UIColor(white: 1, alpha: 0.06), roughness: 0.05, metalness: 0.0)
        glass.transparency = 0.12
        SK.plane(1.2, 1.1, glass, at: SCNVector3(0.04, 0, 0), yaw: .pi / 2, in: win)
        // sill
        SK.box(0.22, 0.04, 1.35, frameMat, at: SCNVector3(0.1, -0.58, 0), in: win)
        // curtains
        let curtain = SK.material(UIColor(red: 0.28, green: 0.18, blue: 0.2, alpha: 1), roughness: 1)
        SK.box(0.05, 1.7, 0.4, curtain, at: SCNVector3(0.16, 0.2, -0.82), in: win, chamfer: 0.02)
        SK.box(0.05, 1.7, 0.4, curtain, at: SCNVector3(0.16, 0.2, 0.82), in: win, chamfer: 0.02)
    }

    private func buildShelf() {
        let wood = SK.material(UIColor(red: 0.3, green: 0.22, blue: 0.15, alpha: 1), roughness: 0.6)
        let shelf = SK.group("shelf", at: SCNVector3(-2.42, 0, -1.1), in: root)
        SK.box(0.3, 0.03, 0.9, wood, at: SCNVector3(0, 1.25, 0), in: shelf)
        SK.box(0.3, 0.03, 0.9, wood, at: SCNVector3(0, 1.65, 0), in: shelf)
        // books (one interactable group)
        let books = SK.group(InteractionSystem.prefix + "books", at: SCNVector3(0, 1.27, -0.15), in: shelf)
        let colors: [UIColor] = [.init(red: 0.5, green: 0.1, blue: 0.1, alpha: 1), .init(red: 0.1, green: 0.25, blue: 0.4, alpha: 1),
                                 .init(red: 0.2, green: 0.35, blue: 0.2, alpha: 1), .init(red: 0.6, green: 0.5, blue: 0.3, alpha: 1),
                                 .init(white: 0.15, alpha: 1)]
        var z: Float = -0.25
        for (i, c) in colors.enumerated() {
            let h = CGFloat(0.2 + Double(i % 3) * 0.03)
            SK.box(0.18, h, 0.045, SK.material(c, roughness: 0.8), at: SCNVector3(0, Float(h) / 2, z), in: books)
            z += 0.05
        }
        // the PAPERLIGHT game box (pickup)
        let boxMat = SK.material(.white, roughness: 0.4)
        boxMat.diffuse.contents = ArtTex.gameBoxCover()
        let side = SK.material(UIColor(red: 0.08, green: 0.1, blue: 0.25, alpha: 1), roughness: 0.4)
        let g = SCNBox(width: 0.03, height: 0.19, length: 0.14, chamferRadius: 0.003)
        g.materials = [side, boxMat, side, side, side, side]  // order: +z, +x (cover faces into the room), -z, -x, top, bottom
        let gameBox = SCNNode(geometry: g)
        gameBox.name = InteractionSystem.prefix + "gamebox"
        gameBox.position = SCNVector3(0.02, 1.67 + 0.095, 0.15)
        shelf.addChildNode(gameBox)
        world.nodes["item_gamebox"] = gameBox
        // a couple of old cartridges / figures
        SK.box(0.12, 0.08, 0.06, SK.material(UIColor(white: 0.5, alpha: 1)), at: SCNVector3(0, 1.67 + 0.04, -0.2), in: shelf)
    }

    private func buildPoster() {
        let mat = SK.material(.white, roughness: 0.6)
        mat.diffuse.contents = ArtTex.poster()
        let poster = SK.plane(0.62, 0.88, mat, at: SCNVector3(Self.halfW - 0.005, 1.55, 0.6), yaw: -.pi / 2, in: root,
                              name: InteractionSystem.prefix + "poster")
        _ = poster
    }

    private func buildWardrobe() {
        let wood = SK.material(UIColor(red: 0.35, green: 0.27, blue: 0.2, alpha: 1), roughness: 0.6)
        let metal = SK.material(UIColor(white: 0.6, alpha: 1), roughness: 0.3, metalness: 0.9)
        let name = InteractionSystem.prefix + "wardrobe"
        if ModelLibrary.place("drawer_cabinet", at: SCNVector3(-1.95, 0, Self.halfD - 0.27), yaw: .pi, in: root, nodeName: name) != nil {
            world.controller.obstacles.append(AABB2D(x: -1.95, z: Self.halfD - 0.27, w: 1.18, d: 0.54))
            return
        }
        let w = SK.group(name, at: SCNVector3(-2.18, 0, 1.8), in: root)
        SK.box(0.75, 2.0, 0.55, wood, at: SCNVector3(0, 1.0, 0), in: w)
        SK.box(0.01, 1.9, 0.01, SK.material(.black), at: SCNVector3(0.376, 1.0, 0), in: w)
        SK.box(0.02, 0.12, 0.02, metal, at: SCNVector3(0.39, 1.05, -0.04), in: w)
        SK.box(0.02, 0.12, 0.02, metal, at: SCNVector3(0.39, 1.05, 0.04), in: w)
        world.controller.obstacles.append(AABB2D(x: -2.18, z: 1.8, w: 0.6, d: 0.8))
    }

    private func buildClutter() {
        // rug
        let rug = ModelLibrary.texturedMaterial("dirty_carpet", repeat: 1.5, tint: UIColor(red: 0.75, green: 0.5, blue: 0.52, alpha: 1))
            ?? SK.material(UIColor(red: 0.3, green: 0.12, blue: 0.14, alpha: 1), roughness: 1)
        SK.box(1.8, 0.01, 1.3, rug, at: SCNVector3(0.2, 0.005, 0.3), in: root)
        // mug on desk
        let mug = SK.group(InteractionSystem.prefix + "mug", at: SCNVector3(-0.35, Self.deskTop, -1.72), in: root)
        SK.cylinder(0.04, 0.1, SK.material(UIColor(red: 0.85, green: 0.85, blue: 0.82, alpha: 1), roughness: 0.3), at: SCNVector3(0, 0.05, 0), in: mug)
        SK.cylinder(0.035, 0.002, SK.material(UIColor(red: 0.15, green: 0.08, blue: 0.04, alpha: 1), roughness: 0.1), at: SCNVector3(0, 0.085, 0), in: mug)
        // phone on the bed
        let phoneMat = SK.material(UIColor(white: 0.05, alpha: 1), roughness: 0.2, metalness: 0.4,
                                   emission: UIColor(red: 0.15, green: 0.2, blue: 0.3, alpha: 1))
        var phonePos = SCNVector3(1.85, 0.56, -0.2)
        if let bed = root.childNode(withName: InteractionSystem.prefix + "bed", recursively: false), bed.childNodes.first?.geometry == nil,
           bed.childNodes.count == 1 {
            phonePos = SCNVector3(2.0, ModelLibrary.surfaceY(x: 2.0, z: -0.8, on: bed, in: root, fallback: 0.45) + 0.005, -0.8)
        }
        let phone = SK.box(0.075, 0.009, 0.155, phoneMat, at: phonePos, in: root,
                           name: InteractionSystem.prefix + "phone", chamfer: 0.004)
        phone.eulerAngles.y = 0.4
        // trash can with crumpled paper
        let bin = SK.group(InteractionSystem.prefix + "trash", at: SCNVector3(0.0, 0, -1.9), in: root)
        let binMat = SK.material(UIColor(white: 0.2, alpha: 1), roughness: 0.5, metalness: 0.3)
        SK.cylinder(0.14, 0.32, binMat, at: SCNVector3(0, 0.16, 0), in: bin)
        let paper = SK.material(UIColor(white: 0.9, alpha: 1), roughness: 1)
        let ball = SCNNode(geometry: SCNSphere(radius: 0.05)); ball.geometry!.materials = [paper]
        ball.position = SCNVector3(0.03, 0.33, 0.02); bin.addChildNode(ball)
        world.controller.obstacles.append(AABB2D(x: 0, z: -1.9, w: 0.3, d: 0.3))
        // ceiling light fixture (switched off)
        if ModelLibrary.place("modern_ceiling_lamp_01", at: SCNVector3(0, Self.height, 0), height: 0.45, anchorTop: true, in: root) == nil {
            SK.cylinder(0.22, 0.05, SK.material(UIColor(white: 0.9, alpha: 1), roughness: 0.3), at: SCNVector3(0, Self.height - 0.03, 0), in: root)
        }
        // a plant in the corner by the window
        if ModelLibrary.place("potted_plant_02", at: SCNVector3(-2.22, 0, -0.3), yaw: 0.6, in: root, nodeName: "plant") != nil {
            world.controller.obstacles.append(AABB2D(x: -2.22, z: -0.3, w: 0.6, d: 0.6))
        } else {
            let pot = SK.group("plant", at: SCNVector3(-2.35, 0, -0.3), in: root)
            SK.cylinder(0.12, 0.25, SK.material(UIColor(red: 0.5, green: 0.3, blue: 0.2, alpha: 1)), at: SCNVector3(0, 0.125, 0), in: pot)
        }
        // desk clutter: arm lamp (unlit), an old console next to the PC
        ModelLibrary.place("desk_lamp_arm_01", at: SCNVector3(-1.42, Self.deskTop, -2.0), yaw: 0.5, in: root)
        ModelLibrary.place("gaming_console", at: SCNVector3(-0.42, Self.deskTop, -2.0), yaw: -0.2, in: root)
        // moving box nobody unpacked
        if ModelLibrary.place("cardboard_box_01", at: SCNVector3(-0.75, 0, 1.92), yaw: 0.3, in: root) != nil {
            world.controller.obstacles.append(AABB2D(x: -0.75, z: 1.92, w: 0.55, d: 0.55))
        }
        // a framed picture over the bed
        ModelLibrary.place("hanging_picture_frame_02", at: SCNVector3(1.0, 1.3, -Self.halfD + 0.02), in: root)
    }
}

/// Procedural "printed" art. REPLACEMENT POINT: swap for real cover / poster images.
enum ArtTex {
    static func paperlightArt(_ c: CGContext, _ s: CGSize, title: Bool) {
        let colors = [UIColor(red: 0.05, green: 0.08, blue: 0.25, alpha: 1).cgColor,
                      UIColor(red: 0.45, green: 0.25, blue: 0.45, alpha: 1).cgColor] as CFArray
        let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
        c.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: s.height), options: [])
        // sea
        c.setFillColor(UIColor(red: 0.05, green: 0.12, blue: 0.3, alpha: 1).cgColor)
        c.fill(CGRect(x: 0, y: s.height * 0.72, width: s.width, height: s.height * 0.28))
        // lighthouse
        let lx = s.width * 0.62, lw = s.width * 0.12, top = s.height * 0.3
        for i in 0..<6 {
            c.setFillColor((i % 2 == 0 ? UIColor.white : UIColor(red: 0.85, green: 0.15, blue: 0.15, alpha: 1)).cgColor)
            let y = top + CGFloat(i) * s.height * 0.07
            c.fill(CGRect(x: lx, y: y, width: lw, height: s.height * 0.07))
        }
        c.setFillColor(UIColor(red: 1, green: 0.9, blue: 0.5, alpha: 1).cgColor)
        c.fill(CGRect(x: lx - lw * 0.1, y: top - s.height * 0.06, width: lw * 1.2, height: s.height * 0.06))
        // light beam
        c.setFillColor(UIColor(red: 1, green: 0.95, blue: 0.6, alpha: 0.25).cgColor)
        c.move(to: CGPoint(x: lx + lw / 2, y: top - s.height * 0.03))
        c.addLine(to: CGPoint(x: 0, y: top - s.height * 0.2))
        c.addLine(to: CGPoint(x: 0, y: top + s.height * 0.05))
        c.fillPath()
        // tiny silhouette of a kid with a lantern
        c.setFillColor(UIColor(white: 0.02, alpha: 1).cgColor)
        c.fill(CGRect(x: s.width * 0.25, y: s.height * 0.62, width: s.width * 0.05, height: s.height * 0.1))
        c.fillEllipse(in: CGRect(x: s.width * 0.245, y: s.height * 0.58, width: s.width * 0.06, height: s.width * 0.06))
        c.setFillColor(UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1).cgColor)
        c.fillEllipse(in: CGRect(x: s.width * 0.31, y: s.height * 0.64, width: s.width * 0.03, height: s.width * 0.03))
        if title {
            let p = NSMutableParagraphStyle(); p.alignment = .center
            let t: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: s.width * 0.13, weight: .black),
                                                    .foregroundColor: UIColor(red: 1, green: 0.92, blue: 0.6, alpha: 1),
                                                    .paragraphStyle: p, .kern: 2]
            ("PAPERLIGHT" as NSString).draw(in: CGRect(x: 0, y: s.height * 0.06, width: s.width, height: s.height * 0.2), withAttributes: t)
            let sub: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: s.width * 0.045, weight: .semibold),
                                                      .foregroundColor: UIColor(white: 1, alpha: 0.8), .paragraphStyle: p]
            ("HALDEN SOFTWORKS · 1999" as NSString).draw(in: CGRect(x: 0, y: s.height * 0.9, width: s.width, height: s.height * 0.08), withAttributes: sub)
        }
    }

    static func poster() -> UIImage {
        ProcTex.render(CGSize(width: 400, height: 568)) { c, s in paperlightArt(c, s, title: true) }
    }

    static func gameBoxCover() -> UIImage {
        ProcTex.render(CGSize(width: 280, height: 380)) { c, s in paperlightArt(c, s, title: true) }
    }
}
