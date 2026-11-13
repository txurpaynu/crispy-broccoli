import SceneKit
import UIKit

/// Small helpers for building greybox-but-lit environments in code.
/// REPLACEMENT POINT: any node built here can be swapped for a .usdz/.scn model
/// with the same name; interactables find objects by node name ("ia:<id>").
enum SK {
    static func material(_ color: UIColor, roughness: CGFloat = 0.75, metalness: CGFloat = 0,
                         emission: UIColor? = nil, image: UIImage? = nil, repeat r: Float = 1) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        if let image {
            m.diffuse.contents = image
            m.diffuse.wrapS = .repeat
            m.diffuse.wrapT = .repeat
            m.diffuse.contentsTransform = SCNMatrix4MakeScale(r, r, 1)
            m.multiply.contents = color
        } else {
            m.diffuse.contents = color
        }
        m.roughness.contents = roughness
        m.metalness.contents = metalness
        if let emission { m.emission.contents = emission }
        return m
    }

    @discardableResult
    static func box(_ w: CGFloat, _ h: CGFloat, _ l: CGFloat, _ mat: SCNMaterial,
                    at p: SCNVector3, in parent: SCNNode, name: String? = nil, chamfer: CGFloat = 0.004) -> SCNNode {
        let g = SCNBox(width: w, height: h, length: l, chamferRadius: min(chamfer, min(w, min(h, l)) / 2))
        g.materials = [mat]
        let n = SCNNode(geometry: g)
        n.position = p
        n.name = name
        parent.addChildNode(n)
        return n
    }

    @discardableResult
    static func cylinder(_ r: CGFloat, _ h: CGFloat, _ mat: SCNMaterial, at p: SCNVector3, in parent: SCNNode, name: String? = nil) -> SCNNode {
        let g = SCNCylinder(radius: r, height: h)
        g.materials = [mat]
        let n = SCNNode(geometry: g)
        n.position = p
        n.name = name
        parent.addChildNode(n)
        return n
    }

    @discardableResult
    static func plane(_ w: CGFloat, _ h: CGFloat, _ mat: SCNMaterial, at p: SCNVector3, yaw: Float = 0,
                      in parent: SCNNode, name: String? = nil) -> SCNNode {
        let g = SCNPlane(width: w, height: h)
        g.materials = [mat]
        let n = SCNNode(geometry: g)
        n.position = p
        n.eulerAngles.y = yaw
        n.name = name
        parent.addChildNode(n)
        return n
    }

    static func group(_ name: String?, at p: SCNVector3 = SCNVector3Zero, in parent: SCNNode) -> SCNNode {
        let n = SCNNode()
        n.name = name
        n.position = p
        parent.addChildNode(n)
        return n
    }

    static func omni(_ color: UIColor, intensity: CGFloat, range: CGFloat, shadows: Bool) -> SCNLight {
        let l = SCNLight()
        l.type = .omni
        l.color = color
        l.intensity = intensity
        l.attenuationStartDistance = 0
        l.attenuationEndDistance = range
        l.attenuationFalloffExponent = 2
        if shadows {
            l.castsShadow = true
            l.shadowMode = .forward
            l.shadowSampleCount = 8
            l.shadowRadius = 4
            l.shadowMapSize = CGSize(width: 1024, height: 1024)
            l.shadowColor = UIColor(white: 0, alpha: 0.7)
        }
        return l
    }
}

/// Procedural textures so the slice ships without external image assets.
enum ProcTex {
    static func render(_ size: CGSize, _ draw: (CGContext, CGSize) -> Void) -> UIImage {
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in draw(ctx.cgContext, size) }
    }

    static func woodFloor() -> UIImage {
        var rng = SystemRandomNumberGenerator()
        return render(CGSize(width: 512, height: 512)) { c, s in
            let planks = 6
            let pw = s.width / CGFloat(planks)
            for i in 0..<planks {
                var y: CGFloat = CGFloat(Int.random(in: 0...200, using: &rng)) * -1
                while y < s.height {
                    let len = CGFloat(Int.random(in: 180...320, using: &rng))
                    let t = CGFloat(Double.random(in: 0.78...1.0, using: &rng))
                    c.setFillColor(UIColor(red: 0.42 * t, green: 0.29 * t, blue: 0.19 * t, alpha: 1).cgColor)
                    c.fill(CGRect(x: CGFloat(i) * pw, y: y, width: pw, height: len))
                    for _ in 0..<14 {
                        let gx = CGFloat(i) * pw + CGFloat(Double.random(in: 4...Double(pw - 4), using: &rng))
                        c.setStrokeColor(UIColor(red: 0.3, green: 0.2, blue: 0.12, alpha: 0.25).cgColor)
                        c.setLineWidth(1)
                        c.move(to: CGPoint(x: gx, y: y)); c.addLine(to: CGPoint(x: gx + 3, y: y + len)); c.strokePath()
                    }
                    c.setFillColor(UIColor(white: 0.08, alpha: 0.8).cgColor)
                    c.fill(CGRect(x: CGFloat(i) * pw, y: y + len - 2, width: pw, height: 2))
                    y += len
                }
                c.setFillColor(UIColor(white: 0.05, alpha: 0.9).cgColor)
                c.fill(CGRect(x: CGFloat(i) * pw, y: 0, width: 2, height: s.height))
            }
        }
    }

    static func noiseWall() -> UIImage {
        render(CGSize(width: 256, height: 256)) { c, s in
            c.setFillColor(UIColor.white.cgColor)
            c.fill(CGRect(origin: .zero, size: s))
            for _ in 0..<3000 {
                let v = CGFloat.random(in: 0.88...1)
                c.setFillColor(UIColor(white: v, alpha: 1).cgColor)
                c.fill(CGRect(x: .random(in: 0..<s.width), y: .random(in: 0..<s.height), width: 2, height: 2))
            }
        }
    }

    static func nightCity() -> UIImage {
        render(CGSize(width: 512, height: 512)) { c, s in
            let colors = [UIColor(red: 0.02, green: 0.03, blue: 0.08, alpha: 1).cgColor,
                          UIColor(red: 0.10, green: 0.10, blue: 0.20, alpha: 1).cgColor] as CFArray
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
            c.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: s.height), options: [])
            // buildings
            var x: CGFloat = 0
            while x < s.width {
                let w = CGFloat.random(in: 30...80), h = CGFloat.random(in: 120...330)
                c.setFillColor(UIColor(red: 0.03, green: 0.035, blue: 0.06, alpha: 1).cgColor)
                c.fill(CGRect(x: x, y: s.height - h, width: w, height: h))
                var wy = s.height - h + 8
                while wy < s.height - 6 {
                    var wx = x + 5
                    while wx < x + w - 6 {
                        if Int.random(in: 0..<5) == 0 {
                            c.setFillColor(UIColor(red: 1, green: 0.78, blue: 0.45, alpha: .random(in: 0.4...0.9)).cgColor)
                            c.fill(CGRect(x: wx, y: wy, width: 4, height: 5))
                        }
                        wx += 9
                    }
                    wy += 11
                }
                x += w + .random(in: 2...10)
            }
            // moon
            c.setFillColor(UIColor(red: 0.85, green: 0.88, blue: 1, alpha: 0.9).cgColor)
            c.fillEllipse(in: CGRect(x: 380, y: 50, width: 34, height: 34))
        }
    }

    /// What the monitor shows when you're not sitting at it.
    static func monitorIdle(_ text: String = "") -> UIImage {
        render(CGSize(width: 512, height: 304)) { c, s in
            let colors = [UIColor(red: 0.10, green: 0.16, blue: 0.32, alpha: 1).cgColor,
                          UIColor(red: 0.03, green: 0.05, blue: 0.12, alpha: 1).cgColor] as CFArray
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
            c.drawLinearGradient(g, start: .zero, end: CGPoint(x: s.width, y: s.height), options: [])
            c.setFillColor(UIColor(white: 0, alpha: 0.6).cgColor)
            c.fill(CGRect(x: 0, y: s.height - 22, width: s.width, height: 22))
            for i in 0..<4 {
                c.setFillColor(UIColor(white: 1, alpha: 0.25).cgColor)
                c.fill(CGRect(x: 14, y: 14 + i * 46, width: 28, height: 28))
            }
            if !text.isEmpty {
                let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.monospacedSystemFont(ofSize: 22, weight: .bold),
                                                            .foregroundColor: UIColor.white]
                (text as NSString).draw(at: CGPoint(x: 120, y: 130), withAttributes: attrs)
            }
        }
    }
}

/// One place to tune the apartment's light levels (SceneKit physically based units).
/// It's a dark room at 1 AM: a warm bedside lamp, a cold monitor and a little moonlight.
enum Lighting {
    static let ambient: CGFloat = 14
    static let moon: CGFloat = 55
    static let monitor: CGFloat = 26
    static let lamp: CGFloat = 95
    static let exposure: CGFloat = -0.35
}
