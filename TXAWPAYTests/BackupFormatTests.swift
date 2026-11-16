import XCTest
@testable import TXAWPAY

final class BackupFormatTests: XCTestCase {
    private func snapshot(title: String = "Morning", body: String, date: Date = Date(timeIntervalSince1970: 1_790_000_000)) -> JournalEntrySnapshot {
        JournalEntrySnapshot(id: UUID(), title: title, body: body, reflection: "Felt good\nsecond line",
                             date: date, createdAt: date, modifiedAt: date, mood: "calm",
                             tags: ["sea", "light"], category: "Personal Diary", locationName: "Cliffs | north",
                             latitude: 38.69, longitude: -9.42, isFavorite: true, isImportant: false,
                             attachments: [], tripTitle: "", projectName: "", people: [])
    }

    func testDayFileRoundTrip() {
        let tricky = "Line one\n\n<!-- txawpay:/body -->\nLooks like a marker --> but isn't.\n**bold** and émoji 🌊"
        let a = snapshot(body: tricky)
        let b = snapshot(title: "Evening", body: "Short", date: a.date.addingTimeInterval(3600))
        let key = a.dayKey
        let text = JournalMarkdownCodec.renderDay(key: key, entries: [a, b])
        let parsed = JournalMarkdownCodec.parse(text, fileName: "\(key).md")

        XCTAssertEqual(parsed.count, 2)
        let pa = parsed.first { $0.id == a.id }
        XCTAssertNotNil(pa)
        XCTAssertEqual(pa?.body, tricky)
        XCTAssertEqual(pa?.title, "Morning")
        XCTAssertEqual(pa?.reflection, "Felt good\nsecond line")
        XCTAssertEqual(pa?.locationName, "Cliffs | north")
        XCTAssertEqual(pa?.tags, ["sea", "light"])
        XCTAssertEqual(pa?.isFavorite, true)
        XCTAssertTrue(pa?.hasStableID ?? false)
        XCTAssertEqual(JournalMarkdownCodec.entryIDs(in: text), [a.id, b.id])
    }

    func testMetaEscapingRoundTrip() {
        let values = ["plain", "a | b", "back\\slash", "multi\nline", "closes --> comment", "trailing \\"]
        for v in values {
            let escaped = JournalMarkdownCodec.meta(v)
            XCTAssertFalse(escaped.contains("\n"))
            XCTAssertFalse(escaped.contains("-->"))
            XCTAssertEqual(JournalMarkdownCodec.unmeta(escaped), v.trimmingCharacters(in: .whitespaces))
        }
    }

    func testPlainMarkdownImportIsDeterministic() {
        let md = "# A walk\n\nWe went to the river."
        let first = JournalMarkdownCodec.parse(md, fileName: "2026-03-04.md")
        let second = JournalMarkdownCodec.parse(md, fileName: "2026-03-04.md")
        XCTAssertEqual(first.count, 1)
        XCTAssertEqual(first.first?.id, second.first?.id)
        XCTAssertFalse(first.first?.hasStableID ?? true)
        XCTAssertEqual(first.first.map { DayKey.key(for: $0.date) }, "2026-03-04")
    }

    func testDayKeyPaths() {
        XCTAssertEqual(DayKey.relativePath(for: "2026-11-16"), "2026/November/2026-11-16.md")
        XCTAssertEqual(DayKey.relativePath(for: "2024-02-29"), "2024/February/2024-02-29.md")
        XCTAssertEqual(DayKey.relativePath(for: "garbage"), "Unsorted/garbage.md")
    }

    func testZipRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let zipURL = dir.appendingPathComponent("test.zip")
        let big = Data(String(repeating: "tide ", count: 5000).utf8)
        let writer = try ZipWriter(url: zipURL)
        try writer.add(path: "TXAWPAY/Journal Backups/2026/November/2026-11-16.md", data: big)
        try writer.add(path: "TXAWPAY/empty.txt", data: Data())
        try writer.finish()

        let out = dir.appendingPathComponent("out")
        let files = try ZipReader.extract(archive: zipURL, to: out)
        XCTAssertEqual(files.count, 2)
        let restored = try Data(contentsOf: out.appendingPathComponent("TXAWPAY/Journal Backups/2026/November/2026-11-16.md"))
        XCTAssertEqual(restored, big)
    }

    func testEncryptionRoundTripAndWrongPassword() throws {
        let plain = Data("secret journal".utf8)
        let sealed = try EncryptedArchive.encrypt(plain, password: "correct horse")
        XCTAssertEqual(try EncryptedArchive.decrypt(sealed, password: "correct horse"), plain)
        XCTAssertThrowsError(try EncryptedArchive.decrypt(sealed, password: "wrong"))
    }

    func testNextBirthdayHandlesLeapDay() {
        var comps = DateComponents(); comps.year = 2000; comps.month = 2; comps.day = 29
        let birthday = Calendar.current.date(from: comps)!
        comps.year = 2027; comps.month = 1; comps.day = 10
        let ref = Calendar.current.date(from: comps)!
        let next = DateMath.nextOccurrence(of: birthday, repeatsYearly: true, from: ref)!
        let c = Calendar.current.dateComponents([.year, .month, .day], from: next)
        XCTAssertEqual([c.year, c.month, c.day], [2027, 2, 28])
    }
}
