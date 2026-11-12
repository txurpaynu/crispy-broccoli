import Foundation
import SwiftUI
#if canImport(ActivityKit)
import ActivityKit
#endif

// MARK: - Mood

enum Mood: String, Codable, Hashable, CaseIterable {
    case happy, excited, curious, sleepy, sad

    var emoji: String {
        switch self {
        case .happy: return "😊"
        case .excited: return "🤩"
        case .curious: return "🤔"
        case .sleepy: return "😴"
        case .sad: return "🥺"
        }
    }

    var label: String { rawValue.capitalized }
}

// MARK: - Face (one animated face per case, see ShimejiCompanion/Expressions)

enum Face: String, Codable, Hashable, CaseIterable {
    case happy, excited, annoyed, angry, worried, scared
    case error404 = "error-404"
    case glitch

    /// The face shown when nothing in particular is happening.
    static func resting(for mood: Mood) -> Face {
        switch mood {
        case .happy: return .happy
        case .excited: return .excited
        case .curious: return .happy
        case .sleepy: return .annoyed
        case .sad: return .worried
        }
    }
}

// MARK: - Live Activity data

#if canImport(ActivityKit)
struct CompanionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var message: String
        var mood: Mood
        var happiness: Int
        var face: Face
    }

    var name: String
}
#endif

// MARK: - Look (swap these colors to restyle the placeholder character)

struct CompanionStyle {
    var body: Color
    var bodyShade: Color
    var outline: Color
    var blush: Color
    var eye: Color

    static let `default` = CompanionStyle(
        body: Color(red: 1.00, green: 0.90, blue: 0.93),
        bodyShade: Color(red: 0.98, green: 0.74, blue: 0.82),
        outline: Color(red: 0.45, green: 0.25, blue: 0.32),
        blush: Color(red: 1.00, green: 0.55, blue: 0.62),
        eye: Color(red: 0.20, green: 0.12, blue: 0.16)
    )
}
