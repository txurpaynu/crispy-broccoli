import Foundation

/// A fictional, in-memory filesystem. Nothing here ever touches the real device.
enum VFSKind: String, Codable {
    case folder, text, app, encrypted, data, image, installer, shortcut, system
}

struct VFSNode: Codable, Identifiable, Equatable {
    var id: String { name }
    var name: String
    var kind: VFSKind
    var children: [VFSNode]? = nil
    var content: String? = nil
    var sizeKB: Int = 0
    var created: String = "11/02/2026 21:14"
    var modified: String = "11/02/2026 21:14"
    /// If set, deleting this node (or a folder containing it) fails with this message.
    var lockedBy: String? = nil
    /// Cannot be deleted at all (system files).
    var protected: Bool = false
    /// Extra rows for the Properties dialog.
    var meta: [String: String]? = nil
    /// For `app` / `shortcut`: which in-game app to launch.
    var launches: String? = nil

    var isFolder: Bool { kind == .folder }

    init(name: String, kind: VFSKind, children: [VFSNode]? = nil, content: String? = nil, sizeKB: Int = 0) {
        self.name = name
        self.kind = kind
        self.children = children
        self.content = content
        self.sizeKB = sizeKB
    }

    enum CodingKeys: String, CodingKey {
        case name, kind, children, content, sizeKB, created, modified, lockedBy, protected, meta, launches
    }

    /// JSON content files omit most fields, so every field except name/kind is optional on decode.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        kind = try c.decode(VFSKind.self, forKey: .kind)
        children = try c.decodeIfPresent([VFSNode].self, forKey: .children)
        content = try c.decodeIfPresent(String.self, forKey: .content)
        sizeKB = try c.decodeIfPresent(Int.self, forKey: .sizeKB) ?? 0
        created = try c.decodeIfPresent(String.self, forKey: .created) ?? "11/02/2026 21:14"
        modified = try c.decodeIfPresent(String.self, forKey: .modified) ?? created
        lockedBy = try c.decodeIfPresent(String.self, forKey: .lockedBy)
        protected = try c.decodeIfPresent(Bool.self, forKey: .protected) ?? false
        meta = try c.decodeIfPresent([String: String].self, forKey: .meta)
        launches = try c.decodeIfPresent(String.self, forKey: .launches)
    }

    var totalSizeKB: Int {
        if let c = children { return c.reduce(0) { $0 + $1.totalSizeKB } }
        return sizeKB
    }

    /// First locked descendant (including self), used to block folder deletion.
    func firstLock(path: String) -> (path: String, by: String)? {
        if let by = lockedBy { return (path, by) }
        for c in children ?? [] {
            if let hit = c.firstLock(path: path + "/" + c.name) { return hit }
        }
        return nil
    }

    func containsProtected() -> Bool {
        if protected { return true }
        return (children ?? []).contains { $0.containsProtected() }
    }
}

/// Path helpers. Paths look like "C:/Users/sam/Documents/todo.txt".
struct VirtualFilesystem: Codable {
    var root: VFSNode

    static func components(_ path: String) -> [String] {
        path.split(separator: "/").map(String.init)
    }

    static func join(_ parent: String, _ name: String) -> String {
        parent.hasSuffix("/") ? parent + name : parent + "/" + name
    }

    static func parent(of path: String) -> String {
        var c = components(path)
        if c.count <= 1 { return c.first ?? path }
        c.removeLast()
        return c.joined(separator: "/")
    }

    func node(at path: String) -> VFSNode? {
        let comps = Self.components(path)
        guard let first = comps.first, first == root.name else { return nil }
        var cur = root
        for name in comps.dropFirst() {
            guard let next = cur.children?.first(where: { $0.name == name }) else { return nil }
            cur = next
        }
        return cur
    }

    mutating func update(at path: String, _ change: (inout VFSNode) -> Void) {
        let comps = Array(Self.components(path).dropFirst())
        Self.mutate(&root, comps[...], change)
    }

    private static func mutate(_ node: inout VFSNode, _ rest: ArraySlice<String>, _ change: (inout VFSNode) -> Void) {
        guard let name = rest.first else { change(&node); return }
        guard var kids = node.children, let i = kids.firstIndex(where: { $0.name == name }) else { return }
        mutate(&kids[i], rest.dropFirst(), change)
        node.children = kids
    }

    mutating func insert(_ child: VFSNode, into folder: String) {
        update(at: folder) { n in
            var kids = n.children ?? []
            kids.removeAll { $0.name == child.name }
            kids.append(child)
            n.children = kids
        }
    }

    @discardableResult
    mutating func remove(at path: String) -> VFSNode? {
        let parentPath = Self.parent(of: path)
        let name = Self.components(path).last ?? ""
        var removed: VFSNode?
        update(at: parentPath) { n in
            if let i = n.children?.firstIndex(where: { $0.name == name }) {
                removed = n.children?.remove(at: i)
            }
        }
        return removed
    }

    /// All files of a given kind with their paths (used by KeySmith's file picker).
    func find(kind: VFSKind) -> [VFSHit] {
        var out: [VFSHit] = []
        func walk(_ n: VFSNode, _ p: String) {
            if n.kind == kind { out.append(VFSHit(path: p, node: n)) }
            for c in n.children ?? [] { walk(c, p + "/" + c.name) }
        }
        walk(root, root.name)
        return out
    }
}

struct VFSHit: Identifiable {
    let path: String
    let node: VFSNode
    var id: String { path }
}
