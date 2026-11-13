import Foundation

/// Writes SaveData as JSON into the app's Documents folder. One manual slot plus autosave.
enum SaveSlot: String, CaseIterable {
    case auto = "autosave"
    case manual = "save1"
}

struct SaveGameManager {
    private var folder: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func url(_ slot: SaveSlot) -> URL {
        folder.appendingPathComponent("\(slot.rawValue).json")
    }

    func save(_ data: SaveData, to slot: SaveSlot) {
        var copy = data
        copy.savedAt = Date()
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let bytes = try encoder.encode(copy)
            try bytes.write(to: url(slot), options: .atomic)
        } catch {
            print("[Save] failed: \(error)")
        }
    }

    func load(_ slot: SaveSlot) -> SaveData? {
        guard let bytes = try? Data(contentsOf: url(slot)) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SaveData.self, from: bytes)
    }

    func exists(_ slot: SaveSlot) -> Bool {
        FileManager.default.fileExists(atPath: url(slot).path)
    }

    func savedAt(_ slot: SaveSlot) -> Date? {
        load(slot)?.savedAt
    }

    /// Most recent of the two slots.
    func latest() -> SaveData? {
        let all = SaveSlot.allCases.compactMap { load($0) }
        return all.max { $0.savedAt < $1.savedAt }
    }

    func deleteAll() {
        for s in SaveSlot.allCases { try? FileManager.default.removeItem(at: url(s)) }
    }
}
