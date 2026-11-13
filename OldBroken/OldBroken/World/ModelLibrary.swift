import SceneKit
import UIKit

/// Loads the CC0 Poly Haven models (Resources/Models/*.usdz) and textures
/// (Resources/Textures/*), and places them at real-world scale.
/// If a model is missing, `place` returns nil and the builder keeps its blockout geometry.
@MainActor
enum ModelLibrary {
    struct Info: Decodable { let size: [Float] }

    private static let info: [String: Info] = {
        guard let url = Bundle.main.url(forResource: "models", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: Info].self, from: data)) ?? [:]
    }()

    /// Loads a model as a node whose origin is at its bottom-center (or top-center),
    /// with Y up and its front facing +Z.
    static func load(_ name: String, anchorTop: Bool = false) -> SCNNode? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "usdz"),
              let scene = try? SCNScene(url: url, options: [.checkConsistency: false]) else {
            print("[ModelLibrary] missing \(name)")
            return nil
        }
        let inner = SCNNode()
        for c in scene.rootNode.childNodes { inner.addChildNode(c) }
        let oriented = SCNNode()
        oriented.addChildNode(inner)

        // Blender exports Z-up. Decide from the measured size whether SceneKit already converted it.
        var (mn, mx) = inner.boundingBox
        if let h = info[name]?.size[1] {
            let ySpan = mx.y - mn.y, zSpan = mx.z - mn.z
            if abs(zSpan - h) < abs(ySpan - h) - 0.01 {
                inner.eulerAngles.x = -.pi / 2
            }
        }
        (mn, mx) = oriented.boundingBox
        let cx = (mn.x + mx.x) / 2, cz = (mn.z + mx.z) / 2
        let y = anchorTop ? mx.y : mn.y
        let container = SCNNode()
        oriented.position = SCNVector3(-cx, -y, -cz)
        container.addChildNode(oriented)
        container.enumerateHierarchy { n, _ in
            n.castsShadow = true
            n.geometry?.materials.forEach { $0.lightingModel = .physicallyBased }
        }
        return container
    }

    /// Height of a loaded node in meters.
    static func height(_ n: SCNNode) -> Float {
        let (mn, mx) = n.boundingBox
        return mx.y - mn.y
    }

    /// Loads and places a model. `height` rescales uniformly to that height (meters).
    @discardableResult
    static func place(_ name: String, at p: SCNVector3, yaw: Float = 0, height: Float? = nil,
                      anchorTop: Bool = false, in parent: SCNNode, nodeName: String? = nil) -> SCNNode? {
        guard let model = load(name, anchorTop: anchorTop) else { return nil }
        if let h = height {
            let cur = Self.height(model)
            if cur > 0.001 { model.scale = SCNVector3(h / cur, h / cur, h / cur) }
        }
        let holder = SCNNode()
        holder.name = nodeName
        holder.position = p
        holder.eulerAngles.y = yaw
        holder.addChildNode(model)
        parent.addChildNode(holder)
        return holder
    }

    /// A PBR material from a Poly Haven texture set ("<id>_diff.jpg", "_nor.jpg", "_rough.jpg").
    static func texturedMaterial(_ id: String, repeat r: Float, tint: UIColor = .white) -> SCNMaterial? {
        func img(_ suffix: String) -> UIImage? {
            guard let p = Bundle.main.path(forResource: "\(id)_\(suffix)", ofType: "jpg") else { return nil }
            return UIImage(contentsOfFile: p)
        }
        guard let diff = img("diff") else { return nil }
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = diff
        m.multiply.contents = tint
        if let n = img("nor") { m.normal.contents = n; m.normal.intensity = 0.8 }
        if let r = img("rough") { m.roughness.contents = r } else { m.roughness.contents = 0.8 }
        m.metalness.contents = 0.0
        let t = SCNMatrix4MakeScale(r, r, 1)
        for prop in [m.diffuse, m.normal, m.roughness, m.multiply] {
            prop.wrapS = .repeat
            prop.wrapT = .repeat
            prop.contentsTransform = t
            prop.mipFilter = .linear
        }
        return m
    }
}

extension ModelLibrary {
    /// The top surface height under (x, z), found by casting a ray down through `node`.
    static func surfaceY(x: Float, z: Float, on node: SCNNode, in root: SCNNode, fallback: Float) -> Float {
        let hits = root.hitTestWithSegment(from: SCNVector3(x, 3, z), to: SCNVector3(x, 0, z),
                                           options: [SCNHitTestOption.searchMode.rawValue: SCNHitTestSearchMode.all.rawValue,
                                                     SCNHitTestOption.ignoreHiddenNodes.rawValue: true,
                                                     SCNHitTestOption.backFaceCulling.rawValue: false])
        for h in hits {
            var n: SCNNode? = h.node
            while let c = n, c !== node { n = c.parent }
            if n != nil { return h.worldCoordinates.y }
        }
        return fallback
    }
}
