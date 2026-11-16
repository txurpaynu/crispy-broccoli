import Foundation

/// Rotating quotes and reflection prompts. Deterministic per day, so the card
/// doesn't change every time Home appears.
enum InspirationService {
    struct Item: Hashable {
        var text: String
        var source: String?
        var isPrompt: Bool
    }

    static let quotes: [Item] = [
        Item(text: "Water is fluid, soft and yielding. But water will wear away rock.", source: "Lao Tzu", isPrompt: false),
        Item(text: "The world is a book, and those who do not travel read only one page.", source: "Augustine of Hippo", isPrompt: false),
        Item(text: "We do not remember days, we remember moments.", source: "Cesare Pavese", isPrompt: false),
        Item(text: "Not all those who wander are lost.", source: "J. R. R. Tolkien", isPrompt: false),
        Item(text: "The cure for anything is salt water: sweat, tears or the sea.", source: "Isak Dinesen", isPrompt: false),
        Item(text: "Creativity is intelligence having fun.", source: nil, isPrompt: false),
        Item(text: "Little by little, one travels far.", source: "J. R. R. Tolkien", isPrompt: false),
        Item(text: "Wherever you go, go with all your heart.", source: "Confucius", isPrompt: false),
        Item(text: "Rivers know this: there is no hurry. We shall get there some day.", source: "A. A. Milne", isPrompt: false),
        Item(text: "What we learn with pleasure we never forget.", source: "Alfred Mercier", isPrompt: false)
    ]

    static let prompts: [Item] = [
        Item(text: "What made you smile today, even briefly?", source: nil, isPrompt: true),
        Item(text: "Which place would you return to tomorrow if you could?", source: nil, isPrompt: true),
        Item(text: "What is something you're slowly getting better at?", source: nil, isPrompt: true),
        Item(text: "Who would you like to thank this week, and for what?", source: nil, isPrompt: true),
        Item(text: "Describe a sound, smell or colour from today.", source: nil, isPrompt: true),
        Item(text: "What would make tomorrow feel a little lighter?", source: nil, isPrompt: true),
        Item(text: "What idea keeps returning to you lately?", source: nil, isPrompt: true),
        Item(text: "Which small adventure could you have this month?", source: nil, isPrompt: true)
    ]

    static func today(_ date: Date = Date()) -> Item {
        let all = quotes + prompts
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return all[day % all.count]
    }

    static func prompt(for date: Date = Date()) -> Item {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return prompts[day % prompts.count]
    }
}
