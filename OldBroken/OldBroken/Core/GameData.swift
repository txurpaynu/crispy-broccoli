import Foundation

// MARK: - Data definitions (loaded from the JSON files in Data/)

struct ObjectiveDef: Codable, Identifiable {
    let id: String
    let chapter: String
    let text: String
    /// All of these flags must be set for the objective to be active.
    let requires: [String]
    /// The objective is complete when ANY of these flags is set.
    let complete: [String]
}

struct ChapterDef: Codable, Identifiable {
    let id: String
    let number: String
    let title: String
    /// Flag that starts this chapter (nil for the first one).
    let startFlag: String?
}

struct DocumentDef: Codable, Identifiable {
    let id: String
    let title: String
    let kind: String
    let body: String
}

struct ItemDef: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    /// Inspecting the item reveals this document, if any.
    let revealsDocument: String?
}

enum DataLoader {
    static func load<T: Decodable>(_ name: String, as type: T.Type) -> T? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            print("[DataLoader] missing \(name).json")
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            print("[DataLoader] failed to decode \(name).json: \(error)")
            return nil
        }
    }
}

/// All static, data-driven content. Loaded once.
final class GameDatabase {
    static let shared = GameDatabase()

    let objectives: [ObjectiveDef]
    let chapters: [ChapterDef]
    let documents: [String: DocumentDef]
    let items: [String: ItemDef]

    private init() {
        objectives = DataLoader.load("objectives", as: [ObjectiveDef].self) ?? []
        chapters = DataLoader.load("chapters", as: [ChapterDef].self) ?? []
        let docs = DataLoader.load("documents", as: [DocumentDef].self) ?? []
        documents = Dictionary(uniqueKeysWithValues: docs.map { ($0.id, $0) })
        let its = DataLoader.load("items", as: [ItemDef].self) ?? []
        items = Dictionary(uniqueKeysWithValues: its.map { ($0.id, $0) })
    }
}
