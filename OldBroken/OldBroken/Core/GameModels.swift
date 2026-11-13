import Foundation

/// Which top-level screen is showing.
enum GameScreen: String, Codable {
    case title, apartment, desktop, endSlice, interstitial, facility, ending
}

struct PlayerTransform: Codable, Equatable {
    var x: Float = -0.4
    var y: Float = 0
    var z: Float = 0.7
    var yaw: Float = 0.25
    var pitch: Float = -0.05
}

/// Everything that is written to disk by SaveGameManager.
struct SaveData: Codable {
    var version: Int = 1
    var flags: Set<String> = []
    var counters: [String: Int] = [:]
    var inventory: [String] = []
    var documents: [String] = []
    var player = PlayerTransform()
    var screen: GameScreen = .apartment
    var vexley = VexleyMemory()
    var filesystem: VFSNode? = nil
    var wallet: Double = 42.50
    /// In-game clock, minutes after midnight. The slice starts at 00:41.
    var clockMinutes: Double = 41
    var desktop = DesktopPersistentState()
    var savedAt: Date = Date()
}

/// The parts of the simulated computer that must survive a save/load.
struct DesktopPersistentState: Codable {
    var wallpaper: Int = 0
    var downloads: [String] = []
    var oldWindowOpen: Bool = false
    var lastFocusLossAt: Date? = nil
    var recycled: [RecycledItem] = []
    var notifications: [DesktopNotification] = []
}

struct RecycledItem: Codable, Identifiable {
    var id: String { originalPath }
    let originalPath: String
    let node: VFSNode
}

struct DesktopNotification: Codable, Identifiable, Equatable {
    var id = UUID()
    let app: String
    let title: String
    let body: String
    var time: String = ""
}

/// A line of the protagonist's inner monologue, shown as a subtitle.
struct NarrationLine: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let duration: Double
}

/// Small, transient banner (objective updated, item picked up...).
struct Banner: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let detail: String
}
