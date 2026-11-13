import Foundation

/// Player preferences. Stored in UserDefaults, not in the save game.
final class GameSettings: ObservableObject {
    static let shared = GameSettings()
    private let d = UserDefaults.standard

    @Published var lookSensitivity: Double { didSet { d.set(lookSensitivity, forKey: "lookSensitivity") } }
    @Published var invertY: Bool { didSet { d.set(invertY, forKey: "invertY") } }
    @Published var masterVolume: Double { didSet { d.set(masterVolume, forKey: "masterVolume"); AudioManager.shared.setMasterVolume(Float(masterVolume)) } }
    @Published var subtitles: Bool { didSet { d.set(subtitles, forKey: "subtitles") } }

    private init() {
        lookSensitivity = d.object(forKey: "lookSensitivity") as? Double ?? 1.0
        invertY = d.bool(forKey: "invertY")
        masterVolume = d.object(forKey: "masterVolume") as? Double ?? 0.8
        subtitles = d.object(forKey: "subtitles") as? Bool ?? true
    }
}
