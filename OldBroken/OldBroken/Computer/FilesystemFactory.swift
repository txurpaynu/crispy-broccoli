import Foundation

/// Builds fictional filesystem trees from JSON in Data/.
enum FilesystemFactory {
    static func initial() -> VFSNode {
        DataLoader.load("filesystem", as: VFSNode.self)
            ?? VFSNode(name: "C:", kind: .folder, children: [])
    }

    /// The remaster's install folder, added when the Kestrel install finishes.
    static func remasterInstall() -> VFSNode? {
        DataLoader.load("filesystem_remaster", as: VFSNode.self)
    }
}
