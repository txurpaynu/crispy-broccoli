import Foundation
import CryptoKit

// MARK: - Snapshots
//
// Backups are rendered from plain value snapshots of the SwiftData models.
// Snapshots are `Sendable`, so file I/O can run off the main actor without
// touching live model objects.

struct AttachmentSnapshot: Codable, Hashable, Sendable {
    var id: UUID
    var kind: String
    var fileName: String
    var originalFileName: String
    var caption: String
}

struct JournalEntrySnapshot: Codable, Hashable, Sendable, Identifiable {
    var id: UUID
    var title: String
    var body: String
    var reflection: String
    var date: Date
    var createdAt: Date
    var modifiedAt: Date
    var mood: String
    var tags: [String]
    var category: String
    var locationName: String
    var latitude: Double?
    var longitude: Double?
    var isFavorite: Bool
    var isImportant: Bool
    var attachments: [AttachmentSnapshot]
    var tripTitle: String
    var projectName: String
    var people: [String]

    var dayKey: String { DayKey.key(for: date) }
}

extension JournalEntrySnapshot {
    @MainActor
    init(_ e: JournalEntry) {
        id = e.id
        title = e.title
        body = e.body
        reflection = e.reflection
        date = e.date
        createdAt = e.createdAt
        modifiedAt = e.modifiedAt
        mood = e.moodRaw
        tags = e.tags
        category = e.category?.name ?? ""
        locationName = e.locationName
        latitude = e.latitude
        longitude = e.longitude
        isFavorite = e.isFavorite
        isImportant = e.isImportant
        attachments = e.sortedAttachments.map {
            AttachmentSnapshot(id: $0.id, kind: $0.kindRaw, fileName: $0.fileName,
                               originalFileName: $0.originalFileName, caption: $0.caption)
        }
        tripTitle = e.trip?.title ?? ""
        projectName = e.project?.name ?? ""
        people = (e.people ?? []).map(\.name).sorted()
    }
}

// MARK: - Codec

/// Converts journal entries to and from TXAWPAY's Markdown day files.
///
/// Format (version 1). One file per calendar day; each entry is wrapped in
/// HTML comments, which Markdown viewers hide, so the file reads naturally
/// while still being machine-restorable:
///
///     # Monday, November 16, 2026
///     <!-- txawpay:day date=2026-11-16 format=1 -->
///
///     ---
///
///     ## Entry title
///     <!-- txawpay:entry
///     id: 6F1E…
///     title: Entry title
///     date: 2026-11-16T09:12:00+01:00
///     created: …
///     modified: …
///     mood: calm
///     tags: sea, family
///     category: Personal Diary
///     body-bytes: 1234
///     -->
///
///     - **Time:** 09:12
///     - **Mood:** Calm …   (human-readable summary, ignored by the parser)
///
///     <!-- txawpay:body -->
///     …the entry text, byte-for-byte…
///     <!-- txawpay:/body -->
///     <!-- txawpay:/entry -->
///
/// The body is stored verbatim. `body-bytes` lets the parser slice it exactly
/// even if the text itself contains something that looks like a marker; if a
/// person edits the file by hand and the length no longer matches, the parser
/// falls back to the closing marker.
enum JournalMarkdownCodec {
    static let formatVersion = 1

    // MARK: Rendering

    static func renderDay(key: String, entries: [JournalEntrySnapshot], mediaLinkPrefix: String? = "../../Media") -> String {
        var out = "# \(DayKey.heading(for: key))\n"
        out += "<!-- txawpay:day date=\(key) format=\(formatVersion) -->\n"
        let sorted = entries.sorted { $0.date == $1.date ? $0.createdAt < $1.createdAt : $0.date < $1.date }
        for entry in sorted {
            out += "\n---\n\n"
            out += renderEntry(entry, mediaLinkPrefix: mediaLinkPrefix)
        }
        return out
    }

    static func renderEntry(_ e: JournalEntrySnapshot, mediaLinkPrefix: String?) -> String {
        var s = "## \(oneLine(e.title.isEmpty ? "Untitled entry" : e.title))\n"
        s += "<!-- txawpay:entry\n"
        s += "id: \(e.id.uuidString)\n"
        s += "title: \(meta(e.title))\n"
        s += "date: \(DayKey.isoString(e.date))\n"
        s += "created: \(DayKey.isoString(e.createdAt))\n"
        s += "modified: \(DayKey.isoString(e.modifiedAt))\n"
        if !e.mood.isEmpty { s += "mood: \(meta(e.mood))\n" }
        if !e.tags.isEmpty { s += "tags: \(meta(e.tags.joined(separator: ", ")))\n" }
        if !e.category.isEmpty { s += "category: \(meta(e.category))\n" }
        if !e.locationName.isEmpty { s += "location: \(meta(e.locationName))\n" }
        if let lat = e.latitude, let lon = e.longitude { s += "coordinate: \(lat), \(lon)\n" }
        if e.isFavorite { s += "favorite: true\n" }
        if e.isImportant { s += "important: true\n" }
        if !e.tripTitle.isEmpty { s += "trip: \(meta(e.tripTitle))\n" }
        if !e.projectName.isEmpty { s += "project: \(meta(e.projectName))\n" }
        if !e.people.isEmpty { s += "people: \(meta(e.people.joined(separator: ", ")))\n" }
        for a in e.attachments {
            s += "attachment: \(a.kind) | \(meta(a.fileName)) | \(meta(a.originalFileName)) | \(meta(a.caption))\n"
        }
        s += "body-bytes: \(e.body.utf8.count)\n"
        if !e.reflection.isEmpty { s += "reflection-bytes: \(e.reflection.utf8.count)\n" }
        s += "-->\n\n"

        // Human-readable summary (ignored when restoring).
        s += "- **Time:** \(e.date.formatted(date: .omitted, time: .shortened))\n"
        if let mood = Mood(rawValue: e.mood) { s += "- **Mood:** \(mood.label)\n" }
        if !e.tags.isEmpty { s += "- **Tags:** \(e.tags.map { "#\($0)" }.joined(separator: " "))\n" }
        if !e.category.isEmpty { s += "- **Category:** \(oneLine(e.category))\n" }
        if !e.locationName.isEmpty { s += "- **Location:** \(oneLine(e.locationName))\n" }
        s += "- **Created:** \(DayKey.isoString(e.createdAt))\n"
        s += "- **Last modified:** \(DayKey.isoString(e.modifiedAt))\n\n"

        s += "<!-- txawpay:body -->\n"
        s += e.body
        s += "\n<!-- txawpay:/body -->\n"

        if !e.reflection.isEmpty {
            s += "\n### Reflection\n\n"
            s += "<!-- txawpay:reflection -->\n"
            s += e.reflection
            s += "\n<!-- txawpay:/reflection -->\n"
        }

        if let prefix = mediaLinkPrefix, !e.attachments.isEmpty {
            s += "\n### Attachments\n\n"
            for a in e.attachments {
                let path = "\(prefix)/\(e.id.uuidString)/\(a.fileName)"
                let label = a.originalFileName.isEmpty ? a.kind : a.originalFileName
                s += a.kind == AttachmentKind.photo.rawValue ? "![\(oneLine(label))](\(path))\n" : "[\(oneLine(label))](\(path))\n"
            }
        }
        s += "<!-- txawpay:/entry -->\n"
        return s
    }

    /// Plain-text rendering (optional TXT backups). Human-readable only.
    static func renderPlainDay(key: String, entries: [JournalEntrySnapshot]) -> String {
        var out = DayKey.heading(for: key) + "\n" + String(repeating: "=", count: 32) + "\n"
        for e in entries.sorted(by: { $0.date < $1.date }) {
            out += "\n\(e.title.isEmpty ? "Untitled entry" : e.title)\n"
            out += "\(e.date.formatted(date: .omitted, time: .shortened))"
            if let m = Mood(rawValue: e.mood) { out += " · \(m.label)" }
            if !e.tags.isEmpty { out += " · " + e.tags.map { "#\($0)" }.joined(separator: " ") }
            out += "\n\n\(e.body)\n"
            if !e.reflection.isEmpty { out += "\nReflection:\n\(e.reflection)\n" }
            out += "\nCreated \(DayKey.isoString(e.createdAt)) · Modified \(DayKey.isoString(e.modifiedAt))\n"
            out += String(repeating: "-", count: 32) + "\n"
        }
        return out
    }

    // MARK: Parsing

    struct ParsedAttachment: Hashable {
        var kind: String
        var fileName: String
        var originalFileName: String
        var caption: String
    }

    struct ParsedEntry: Hashable, Identifiable {
        var id: UUID
        /// True if the id came from the file (TXAWPAY format), false if synthesised.
        var hasStableID: Bool
        var title: String
        var body: String
        var reflection: String
        var date: Date
        var createdAt: Date
        var modifiedAt: Date
        var mood: String
        var tags: [String]
        var category: String
        var locationName: String
        var latitude: Double?
        var longitude: Double?
        var isFavorite: Bool
        var isImportant: Bool
        var attachments: [ParsedAttachment]
        var sourceFile: String
    }

    /// Parses a day file. `fileName` (e.g. "2026-11-16.md") is used to infer
    /// the date for Markdown files that weren't written by TXAWPAY.
    static func parse(_ text: String, fileName: String) -> [ParsedEntry] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        let entryMarker = "<!-- txawpay:entry"
        guard normalized.contains(entryMarker) else {
            return parsePlainMarkdown(normalized, fileName: fileName).map { [$0] } ?? []
        }

        var results: [ParsedEntry] = []
        var searchStart = normalized.startIndex
        while let markerRange = normalized.range(of: entryMarker, range: searchStart..<normalized.endIndex) {
            guard let metaEnd = normalized.range(of: "-->", range: markerRange.upperBound..<normalized.endIndex) else { break }
            let metaText = String(normalized[markerRange.upperBound..<metaEnd.lowerBound])
            let meta = parseMeta(metaText)
            var cursor = metaEnd.upperBound

            // The entry ends at its closing marker (or the next entry / end of file).
            let nextEntry = normalized.range(of: entryMarker, range: cursor..<normalized.endIndex)?.lowerBound ?? normalized.endIndex
            let entryEnd = normalized.range(of: "<!-- txawpay:/entry -->", range: cursor..<nextEntry)?.upperBound ?? nextEntry

            let body = extractBlock(in: normalized, name: "body", from: &cursor, limit: entryEnd,
                                    byteCount: meta.single["body-bytes"].flatMap { Int($0) }) ?? ""
            var reflectionCursor = cursor
            let reflection = extractBlock(in: normalized, name: "reflection", from: &reflectionCursor, limit: entryEnd,
                                          byteCount: meta.single["reflection-bytes"].flatMap { Int($0) }) ?? ""

            let date = meta.single["date"].flatMap(DayKey.parseISO)
                ?? dateFromFileName(fileName) ?? Date()
            let created = meta.single["created"].flatMap(DayKey.parseISO) ?? date
            let modified = meta.single["modified"].flatMap(DayKey.parseISO) ?? created
            let idString = meta.single["id"] ?? ""
            let stableID = UUID(uuidString: idString)

            var lat: Double? = nil, lon: Double? = nil
            if let coord = meta.single["coordinate"] {
                let parts = coord.split(separator: ",").map { Double($0.trimmingCharacters(in: .whitespaces)) }
                if parts.count == 2 { lat = parts[0]; lon = parts[1] }
            }

            let attachments: [ParsedAttachment] = (meta.multi["attachment"] ?? []).compactMap { line in
                let parts = line.components(separatedBy: " | ")
                guard parts.count >= 2 else { return nil }
                return ParsedAttachment(kind: parts[0].trimmingCharacters(in: .whitespaces),
                                        fileName: unmeta(parts[1]),
                                        originalFileName: parts.count > 2 ? unmeta(parts[2]) : "",
                                        caption: parts.count > 3 ? unmeta(parts[3]) : "")
            }

            let parsed = ParsedEntry(
                id: stableID ?? syntheticID(date: date, title: unmeta(meta.single["title"] ?? ""), body: body),
                hasStableID: stableID != nil,
                title: unmeta(meta.single["title"] ?? ""),
                body: body,
                reflection: reflection,
                date: date,
                createdAt: created,
                modifiedAt: modified,
                mood: meta.single["mood"] ?? "",
                tags: (meta.single["tags"].map(unmeta) ?? "").split(separator: ",").map { TagNormalizer.normalize(String($0)) }.filter { !$0.isEmpty },
                category: unmeta(meta.single["category"] ?? ""),
                locationName: unmeta(meta.single["location"] ?? ""),
                latitude: lat, longitude: lon,
                isFavorite: meta.single["favorite"] == "true",
                isImportant: meta.single["important"] == "true",
                attachments: attachments,
                sourceFile: fileName)
            results.append(parsed)
            searchStart = entryEnd > markerRange.upperBound ? entryEnd : markerRange.upperBound
        }
        return results
    }

    /// Extracts the text between `<!-- txawpay:NAME -->\n` and `\n<!-- txawpay:/NAME -->`.
    private static func extractBlock(in text: String, name: String, from cursor: inout String.Index,
                                     limit: String.Index, byteCount: Int?) -> String? {
        let open = "<!-- txawpay:\(name) -->\n"
        let close = "\n<!-- txawpay:/\(name) -->"
        guard cursor < limit, let openRange = text.range(of: open, range: cursor..<limit) else { return nil }
        let start = openRange.upperBound

        // Preferred: exact byte length, verified against the closing marker.
        if let byteCount {
            let utf8 = text.utf8
            if let endIndex = utf8.index(start, offsetBy: byteCount, limitedBy: utf8.endIndex),
               endIndex <= limit,
               text[endIndex...].hasPrefix(close) {
                cursor = text.index(endIndex, offsetBy: close.count)
                return String(text[start..<endIndex])
            }
        }
        // Fallback: first closing marker.
        if let closeRange = text.range(of: close, range: start..<limit) {
            cursor = closeRange.upperBound
            return String(text[start..<closeRange.lowerBound])
        }
        // Body with no trailing newline before the marker (hand-edited files).
        if let closeRange = text.range(of: "<!-- txawpay:/\(name) -->", range: start..<limit) {
            cursor = closeRange.upperBound
            return String(text[start..<closeRange.lowerBound])
        }
        return nil
    }

    struct Meta {
        var single: [String: String] = [:]
        var multi: [String: [String]] = [:]
    }

    private static func parseMeta(_ text: String) -> Meta {
        var meta = Meta()
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = String(rawLine)
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            if meta.single[key] == nil { meta.single[key] = value }
            meta.multi[key, default: []].append(value)
        }
        return meta
    }

    /// Imports ordinary Markdown/TXT files (e.g. written by hand or another app).
    static func parsePlainMarkdown(_ text: String, fileName: String) -> ParsedEntry? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var lines = trimmed.components(separatedBy: "\n")
        var title = ""
        var date = dateFromFileName(fileName)

        // Leading headings: a date heading and/or a title heading.
        while let first = lines.first, first.hasPrefix("#") {
            let heading = first.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
            if let d = parseLooseDate(heading) {
                if date == nil { date = d }
            } else if title.isEmpty {
                title = heading
            } else {
                break
            }
            lines.removeFirst()
            while let f = lines.first, f.trimmingCharacters(in: .whitespaces).isEmpty { lines.removeFirst() }
        }
        let body = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedDate = date ?? Date()
        if title.isEmpty {
            let stem = (fileName as NSString).deletingPathExtension
            title = dateFromFileName(fileName) == nil ? stem : ""
        }
        return ParsedEntry(id: syntheticID(date: resolvedDate, title: title, body: body), hasStableID: false,
                           title: title, body: body, reflection: "", date: resolvedDate,
                           createdAt: resolvedDate, modifiedAt: resolvedDate, mood: "", tags: [], category: "",
                           locationName: "", latitude: nil, longitude: nil, isFavorite: false, isImportant: false,
                           attachments: [], sourceFile: fileName)
    }

    static func dateFromFileName(_ name: String) -> Date? {
        let stem = ((name as NSString).lastPathComponent as NSString).deletingPathExtension
        guard stem.count >= 10 else { return nil }
        let candidate = String(stem.prefix(10))
        guard let day = DayKey.date(fromKey: candidate) else { return nil }
        // Noon avoids time-zone edge cases moving the entry to another day.
        return Calendar.current.date(byAdding: .hour, value: 12, to: day)
    }

    private static func parseLooseDate(_ s: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        for format in ["EEEE, MMMM d, yyyy", "MMMM d, yyyy", "yyyy-MM-dd", "d MMMM yyyy"] {
            f.dateFormat = format
            if let d = f.date(from: s) { return Calendar.current.date(byAdding: .hour, value: 12, to: d) }
        }
        return nil
    }

    /// Deterministic id for entries without one, so importing the same plain
    /// file twice is recognised as a duplicate.
    static func syntheticID(date: Date, title: String, body: String) -> UUID {
        let seed = "\(DayKey.key(for: date))|\(title)|\(body)"
        let digest = SHA256.hash(data: Data(seed.utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50 // version 5-style
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        let t = (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                 bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15])
        return UUID(uuid: t)
    }

    // MARK: Escaping for single-line metadata values

    /// Metadata values must stay on one line and must not close the comment.
    static func meta(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "-->", with: "--\\>")
            .replacingOccurrences(of: " | ", with: " \\| ")
    }

    static func unmeta(_ s: String) -> String {
        var out = ""
        var escaping = false
        for ch in s {
            if escaping {
                switch ch {
                case "n": out.append("\n")
                case ">": out.append(">")
                case "|": out.append("|")
                case "\\": out.append("\\")
                default: out.append("\\"); out.append(ch)
                }
                escaping = false
            } else if ch == "\\" {
                escaping = true
            } else {
                out.append(ch)
            }
        }
        if escaping { out.append("\\") }
        return out.trimmingCharacters(in: .whitespaces)
    }

    private static func oneLine(_ s: String) -> String {
        s.replacingOccurrences(of: "\n", with: " ")
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Entry ids contained in a day file (used to detect deletions before overwriting).
    static func entryIDs(in text: String) -> Set<UUID> {
        var ids = Set<UUID>()
        for line in text.split(separator: "\n") where line.hasPrefix("id: ") {
            if let id = UUID(uuidString: String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces)) { ids.insert(id) }
        }
        return ids
    }
}
