import Foundation
import SceneKit

/// Every interactive object implements this. The player never hard-codes object logic:
/// the InteractionSystem finds the object under the crosshair and calls `interact`.
@MainActor
protocol Interactable: AnyObject {
    var id: String { get }
    /// Text for the contextual prompt, or nil when the object can't be used right now.
    func prompt(_ ctx: InteractionContext) -> String?
    func interact(_ ctx: InteractionContext)
}

@MainActor
struct InteractionContext {
    let session: GameSession
    let world: ApartmentWorld
    /// The SceneKit node this interactable is attached to.
    let node: SCNNode?
}

/// Maps nodes named "ia:<id>" to Interactable components and does the crosshair raycast.
@MainActor
final class InteractionSystem {
    static let prefix = "ia:"
    private(set) var registry: [String: Interactable] = [:]
    let reach: Float = 2.1

    func register(_ i: Interactable) { registry[i.id] = i }

    func unregister(_ id: String) { registry.removeValue(forKey: id) }

    /// Returns the interactable and its node under the crosshair, if any.
    func target(root: SCNNode, camera: SCNNode) -> (Interactable, SCNNode)? {
        let from = camera.presentation.worldPosition
        let f = camera.presentation.worldFront
        let to = SCNVector3(from.x + f.x * reach, from.y + f.y * reach, from.z + f.z * reach)
        let hits = root.hitTestWithSegment(from: from, to: to, options: [
            SCNHitTestOption.searchMode.rawValue: SCNHitTestSearchMode.closest.rawValue,
            SCNHitTestOption.ignoreHiddenNodes.rawValue: true,
        ])
        guard let hit = hits.first else { return nil }
        var n: SCNNode? = hit.node
        while let node = n {
            if let name = node.name, name.hasPrefix(Self.prefix) {
                let id = String(name.dropFirst(Self.prefix.count))
                if let i = registry[id] { return (i, node) }
            }
            n = node.parent
        }
        return nil
    }
}

/// Generic component for one-off interactions defined with closures.
@MainActor
final class ActionInteractable: Interactable {
    let id: String
    private let promptFn: @MainActor (InteractionContext) -> String?
    private let action: @MainActor (InteractionContext) -> Void

    init(id: String, prompt: @escaping @MainActor (InteractionContext) -> String?, action: @escaping @MainActor (InteractionContext) -> Void) {
        self.id = id
        self.promptFn = prompt
        self.action = action
    }

    func prompt(_ ctx: InteractionContext) -> String? { promptFn(ctx) }
    func interact(_ ctx: InteractionContext) { action(ctx) }
}
