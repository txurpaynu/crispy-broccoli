import Foundation

/// Objectives are pure data: an objective is active when its `requires` flags are
/// set and none of its `complete` flags are. The first active one is "current".
struct ObjectiveManager {
    let defs: [ObjectiveDef]

    func current(flags: Set<String>) -> ObjectiveDef? {
        defs.first { isActive($0, flags: flags) }
    }

    func isActive(_ o: ObjectiveDef, flags: Set<String>) -> Bool {
        o.requires.allSatisfy { flags.contains($0) } && !isComplete(o, flags: flags)
    }

    func isComplete(_ o: ObjectiveDef, flags: Set<String>) -> Bool {
        o.complete.contains { flags.contains($0) }
    }

    /// Completed objectives, in order, for the journal.
    func completed(flags: Set<String>) -> [ObjectiveDef] {
        defs.filter { isComplete($0, flags: flags) }
    }
}

/// Chapters start when their start flag is set. The latest started chapter is current.
struct ChapterManager {
    let defs: [ChapterDef]

    func current(flags: Set<String>) -> ChapterDef? {
        defs.last { $0.startFlag == nil || flags.contains($0.startFlag!) }
    }
}
