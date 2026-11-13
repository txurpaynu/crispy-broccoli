import Foundation

/// Vexley's behavioural states (design doc section 6). `dormant` = not yet activated.
enum VexleyState: String, Codable, CaseIterable {
    case dormant, friendly, curious, observant, suspicious, manipulative,
         frustrated, aggressive, glitching, hostile
}

/// What Vexley can actually see. He must never know more than his access allows.
enum AccessLevel: Int, Codable, Comparable {
    case none = 0      // not running
    case gameOnly = 1  // inside the OLD build: map, menus, the player's inputs
    case desktop = 2   // after the fake update (Chapter 3)
    case network = 3   // company network (Chapter 6)
    case facility = 4  // master control (Chapter 8)

    static func < (a: AccessLevel, b: AccessLevel) -> Bool { a.rawValue < b.rawValue }
}

/// The eight required facial expressions.
enum VexleyExpression: String, Codable, CaseIterable {
    case neutral, happy, curious, annoyed, angry, worried, scared, glitching

    /// Which GIF in Resources/Vexley plays for this expression.
    /// PLACEHOLDER MAPPING: there is no neutral or curious art yet, so neutral uses
    /// the happy face and curious uses the excited face. Drop in vx_neutral.gif /
    /// vx_curious.gif and change these two lines to replace them.
    var assetName: String {
        switch self {
        case .neutral: return "vx_happy"
        case .happy: return "vx_happy"
        case .curious: return "vx_excited"
        case .annoyed: return "vx_annoyed"
        case .angry: return "vx_angry"
        case .worried: return "vx_worried"
        case .scared: return "vx_scared"
        case .glitching: return "vx_glitch"
        }
    }
}

/// Persistent relationship + memory. `trust` is internal only and never shown as a meter.
struct VexleyMemory: Codable {
    var trust: Int = 0
    var state: VexleyState = .dormant
    var access: AccessLevel = .none
    /// Player decisions Vexley remembers ("tried_to_close", "lied_about_date", ...).
    var remembered: Set<String> = []
    /// Facts he has actually learned ("current_year", "player_not_developer", ...).
    var knowledge: Set<String> = []
    /// Number of times the player has left him.
    var abandonments: Int = 0
}
