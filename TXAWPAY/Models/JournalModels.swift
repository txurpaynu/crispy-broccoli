import Foundation
import SwiftData

// SwiftData schema notes
// ----------------------
// * Every stored property has a default value and every relationship is
//   optional. That's what CloudKit-backed SwiftData stores require, so the
//   same schema works with or without the optional iCloud sync.
// * No `@Attribute(.unique)`: CloudKit doesn't support unique constraints.
//   Each model carries its own stable `id: UUID`, which the backup, restore
//   and export code uses to recognise duplicates.
// * Delete rules: owned children (attachments, milestones, sessions…) are
//   cascaded. Cross-module links (entry ↔ trip, entry ↔ person…) use the
//   default `.nullify`, so deleting a trip never deletes a journal entry.

@Model
final class JournalCategory {
    var id: UUID = UUID()
    var name: String = ""
    var symbol: String = "book.closed"
    var colorHex: String = "#39AFC0"
    var isBuiltIn: Bool = false
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    @Relationship(inverse: \JournalEntry.category)
    var entries: [JournalEntry]? = []

    init(name: String, symbol: String = "book.closed", colorHex: String = "#39AFC0", isBuiltIn: Bool = false, sortOrder: Int = 0) {
        self.name = name
        self.symbol = symbol
        self.colorHex = colorHex
        self.isBuiltIn = isBuiltIn
        self.sortOrder = sortOrder
    }

    static let builtInDefinitions: [(String, String, String)] = [
        ("Personal Diary", "book.closed", "#39AFC0"),
        ("Travel Journal", "airplane", "#2F7F8C"),
        ("Creative Journal", "paintbrush.pointed", "#C69B55"),
        ("Gratitude Journal", "heart", "#647B50"),
        ("Daily Reflections", "leaf", "#76503B")
    ]
}

@Model
final class JournalEntry {
    var id: UUID = UUID()
    var title: String = ""
    /// The full entry text, stored verbatim (Markdown is allowed).
    var body: String = ""
    var reflection: String = ""
    /// The day/time the entry is *about* (user editable).
    var date: Date = Date()
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var moodRaw: String = ""
    var tags: [String] = []
    var locationName: String = ""
    var latitude: Double? = nil
    var longitude: Double? = nil
    var isFavorite: Bool = false
    /// "Important moment" flag used by memories and the yearbook.
    var isImportant: Bool = false
    /// Sample content created by demo mode. Never backed up, easy to remove.
    var isDemo: Bool = false
    /// The day key ("yyyy-MM-dd") of the backup file this entry was last written to.
    /// Lets the backup engine rewrite the *old* day file when an entry's date changes.
    var lastBackupDayKey: String? = nil

    var category: JournalCategory? = nil

    @Relationship(deleteRule: .cascade, inverse: \JournalAttachment.entry)
    var attachments: [JournalAttachment]? = []

    var trip: TravelTrip? = nil
    var project: CreativeProject? = nil

    @Relationship(inverse: \Person.journalEntries)
    var people: [Person]? = []

    @Relationship(inverse: \Memory.journalEntries)
    var memories: [Memory]? = []

    init(title: String = "", body: String = "", date: Date = Date()) {
        self.title = title
        self.body = body
        self.date = date
        self.createdAt = Date()
        self.modifiedAt = Date()
    }

    var mood: Mood? {
        get { Mood(rawValue: moodRaw) }
        set { moodRaw = newValue?.rawValue ?? "" }
    }

    var displayTitle: String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return t }
        let firstLine = body.split(separator: "\n").first.map(String.init) ?? ""
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Untitled entry" : String(trimmed.prefix(60))
    }

    var excerpt: String {
        String(body.replacingOccurrences(of: "\n", with: " ").prefix(160))
    }

    var sortedAttachments: [JournalAttachment] {
        (attachments ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    var photoAttachments: [JournalAttachment] {
        sortedAttachments.filter { $0.kind == .photo }
    }

    var wordCount: Int {
        body.split { $0.isWhitespace || $0.isNewline }.count
    }

    var hasLocation: Bool { latitude != nil && longitude != nil }
}

/// A photo, video or file stored in TXAWPAY's media folder.
///
/// Although named for the journal (per the product spec), the same model is
/// used for media on memories, trips, places, projects and people. Exactly
/// one owner relationship is normally set.
@Model
final class JournalAttachment {
    var id: UUID = UUID()
    var kindRaw: String = AttachmentKind.photo.rawValue
    var roleRaw: String = AttachmentRole.general.rawValue
    /// File name inside `MediaStore`'s directory (never an absolute path,
    /// because the app container path changes between installs).
    var fileName: String = ""
    var originalFileName: String = ""
    var caption: String = ""
    var createdAt: Date = Date()

    var entry: JournalEntry? = nil
    var memory: Memory? = nil
    var trip: TravelTrip? = nil
    var place: TravelDestination? = nil
    var project: CreativeProject? = nil
    var person: Person? = nil

    init(kind: AttachmentKind, fileName: String, originalFileName: String = "", role: AttachmentRole = .general) {
        self.kindRaw = kind.rawValue
        self.fileName = fileName
        self.originalFileName = originalFileName
        self.roleRaw = role.rawValue
    }

    var kind: AttachmentKind {
        get { AttachmentKind(rawValue: kindRaw) ?? .file }
        set { kindRaw = newValue.rawValue }
    }

    var role: AttachmentRole {
        get { AttachmentRole(rawValue: roleRaw) ?? .general }
        set { roleRaw = newValue.rawValue }
    }

    var fileURL: URL { MediaStore.shared.url(for: fileName) }
}
