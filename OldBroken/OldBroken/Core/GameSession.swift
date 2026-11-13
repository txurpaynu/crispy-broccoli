import Foundation
import Combine
import SwiftUI

/// Central game state. Owns the save data and the managers; views observe it.
/// Gameplay code changes the story only through flags (`set(_:)`), which keeps
/// objectives, chapters, Vexley and horror events data-driven and in sync.
@MainActor
final class GameSession: ObservableObject {
    static let shared = GameSession()

    @Published var data = SaveData()
    @Published var screen: GameScreen = .title
    @Published var narration: NarrationLine?
    @Published var banner: Banner?
    @Published var chapterCard: ChapterDef?
    @Published var paused = false
    /// Document currently open in the inspect overlay.
    @Published var inspecting: DocumentDef?
    /// Full-screen story text between scenes (nights, dinner, travel).
    @Published var interstitial: Interstitial?
    /// TV or phone, shown full-screen over the apartment.
    @Published var deviceOverlay: DeviceOverlay?

    /// Fires with the flag name every time a new flag is set.
    let flagSet = PassthroughSubject<String, Never>()

    let db = GameDatabase.shared
    let saves = SaveGameManager()
    lazy var objectives = ObjectiveManager(defs: db.objectives)
    lazy var chapters = ChapterManager(defs: db.chapters)

    private var narrationQueue: [NarrationLine] = []
    private var narrationTask: Task<Void, Never>?
    private var clockTimer: Timer?

    private init() {}

    // MARK: Flags

    func has(_ flag: String) -> Bool { data.flags.contains(flag) }

    func set(_ flag: String) {
        guard !data.flags.contains(flag) else { return }
        let objBefore = currentObjective?.id
        let chapterBefore = chapters.current(flags: data.flags)?.id
        data.flags.insert(flag)
        flagSet.send(flag)

        if let ch = chapters.current(flags: data.flags), ch.id != chapterBefore {
            chapterCard = ch
            AudioManager.shared.play(.chapterSting)
        }
        if let obj = currentObjective, obj.id != objBefore {
            showBanner("New objective", obj.text)
        }
        autosave()
    }

    func unset(_ flag: String) { data.flags.remove(flag) }

    func counter(_ key: String) -> Int { data.counters[key, default: 0] }

    @discardableResult
    func increment(_ key: String, by n: Int = 1) -> Int {
        data.counters[key, default: 0] += n
        return data.counters[key]!
    }

    var currentObjective: ObjectiveDef? { objectives.current(flags: data.flags) }
    var currentChapter: ChapterDef? { chapters.current(flags: data.flags) }

    // MARK: Narration (protagonist's inner voice)

    func say(_ text: String, duration: Double? = nil) {
        let d = duration ?? max(2.6, Double(text.count) * 0.055)
        narrationQueue.append(NarrationLine(text: text, duration: d))
        pumpNarration()
    }

    private func pumpNarration() {
        guard narrationTask == nil, !narrationQueue.isEmpty else { return }
        let line = narrationQueue.removeFirst()
        narration = line
        narrationTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(line.duration * 1_000_000_000))
            guard let self else { return }
            if self.narration == line { self.narration = nil }
            self.narrationTask = nil
            try? await Task.sleep(nanoseconds: 250_000_000)
            self.pumpNarration()
        }
    }

    func showBanner(_ title: String, _ detail: String) {
        let b = Banner(title: title, detail: detail)
        banner = b
        AudioManager.shared.play(.uiConfirm)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_200_000_000)
            if self?.banner == b { self?.banner = nil }
        }
    }

    // MARK: Inventory & documents

    func hasItem(_ id: String) -> Bool { data.inventory.contains(id) }

    func addItem(_ id: String) {
        guard !data.inventory.contains(id) else { return }
        data.inventory.append(id)
        set("item_" + id)
        showBanner("Picked up", db.items[id]?.name ?? id)
    }

    func removeItem(_ id: String) { data.inventory.removeAll { $0 == id } }

    func hasDocument(_ id: String) -> Bool { data.documents.contains(id) }

    func collectDocument(_ id: String) {
        guard !data.documents.contains(id) else { return }
        data.documents.append(id)
        set("doc_" + id)
        showBanner("Added to journal", db.documents[id]?.title ?? id)
    }

    /// Opens a document in the inspect overlay and adds it to the journal.
    func inspect(_ docId: String) {
        guard let d = db.documents[docId] else { return }
        inspecting = d
        collectDocument(docId)
    }

    // MARK: Clock

    var clockText: String {
        let total = Int(data.clockMinutes) % (24 * 60)
        let h = total / 60, m = total % 60
        let h12 = h % 12 == 0 ? 12 : h % 12
        return String(format: "%d:%02d %@", h12, m, h < 12 ? "AM" : "PM")
    }

    private func startClock() {
        clockTimer?.invalidate()
        clockTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.screen != .title, !self.paused else { return }
                self.data.clockMinutes += 10.0 / 60.0 * 2   // in-game time runs 2x
            }
        }
    }

    // MARK: Save / load

    func newGame() {
        data = SaveData()
        data.filesystem = FilesystemFactory.initial()
        resetWorlds()
        screen = .apartment
        startClock()
        AudioManager.shared.setScene(.apartment)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            self?.set("game_started")
            self?.say("Almost one in the morning. I should sleep.")
            self?.say("...Just one more look at the computer first.")
        }
    }

    func continueGame() {
        guard let d = saves.latest() else { newGame(); return }
        apply(d)
    }

    func load(_ slot: SaveSlot) {
        guard let d = saves.load(slot) else { return }
        apply(d)
    }

    private func apply(_ d: SaveData) {
        data = d
        if data.filesystem == nil { data.filesystem = FilesystemFactory.initial() }
        resetWorlds()
        switch d.screen {
        case .title, .endSlice, .interstitial: screen = .apartment
        default: screen = d.screen
        }
        paused = false
        startClock()
        AudioManager.shared.setScene(screen == .desktop ? .desktop : screen == .facility ? (has("robot_awake") ? .chase : .facility) : .apartment)
        StoryHooks.onLoad?(self)
        if screen == .desktop {
            apartmentWorld().sitAtComputer {}
            DesktopHooks.onEnter?(self)
        }
        showBanner("Game loaded", clockText)
    }

    func autosave() {
        guard screen != .title else { return }
        snapshotWorlds()
        saves.save(data, to: .auto)
    }

    func saveManual() {
        snapshotWorlds()
        saves.save(data, to: .manual)
        showBanner("Game saved", clockText)
    }

    func quitToTitle() {
        autosave()
        paused = false
        screen = .title
        AudioManager.shared.setScene(.title)
    }

    // MARK: Worlds

    /// The 3D apartment is long-lived so its state survives switching to the desktop.
    private(set) var apartment: ApartmentWorld?

    func apartmentWorld() -> ApartmentWorld {
        if let a = apartment { return a }
        let a = ApartmentWorld(session: self)
        apartment = a
        return a
    }

    private func resetWorlds() {
        apartment?.teardown()
        apartment = nil
        WorldHooks.reset(self)
    }

    private func snapshotWorlds() {
        if let a = apartment { data.player = a.player.transform }
        data.screen = screen
    }
}

/// Extension point so later systems (desktop, Vexley, horror) can reset without
/// GameSession knowing every type.
@MainActor
enum WorldHooks {
    static var resetHandlers: [(GameSession) -> Void] = []
    static func reset(_ s: GameSession) { resetHandlers.forEach { $0(s) } }
}
