import SwiftUI
import Combine

/// Runs Chapters 2–8. Chapter 1 lives in RetroGameController; everything after it is
/// driven from here: one dialogue runner for all later chapters, story flags, pacing,
/// and the hooks the apartment, the desktop and the facility call into.
@MainActor
final class StoryDirector: ObservableObject {
    static let shared = StoryDirector()

    enum VXMode { case menu, playing }

    let dialogue = DialogueManager(files: ["dialogue_ch2", "dialogue_ch3", "dialogue_ch4",
                                           "dialogue_ch5", "dialogue_ch6", "dialogue_ch7", "dialogue_ch8"])
    /// Number of on-screen views that draw the story dialogue themselves (e.g. the VX game window).
    @Published var inlineHosts = 0
    @Published var vxMode: VXMode = .menu
    @Published var messagesOpen = false

    var session: GameSession { GameSession.shared }
    var comp: ComputerSimulationManager { ComputerSimulationManager.shared }
    var vexley: VexleyController { VexleyController.shared }

    /// Seconds without any dialogue, used for pacing.
    var idleSeconds = 0
    /// Runs once the current conversation ends.
    var afterDialogue: [() -> Void] = []
    private var bag = Set<AnyCancellable>()
    private var timer: Timer?

    private init() {
        dialogue.onEvent = { [weak self] e in self?.handleEvent(e) }
        dialogue.onFinish = { [weak self] id in self?.finished(id) }
        dialogue.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &bag)
        session.flagSet.sink { [weak self] f in self?.flag(f) }.store(in: &bag)
        WorldHooks.resetHandlers.append { _ in StoryDirector.shared.reset() }
        StoryHooks.onLoad = { _ in StoryDirector.shared.loaded() }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in StoryDirector.shared.tick() }
        }
    }

    static func bootstrap() { _ = shared }

    func reset() {
        dialogue.cancel()
        vxMode = .menu
        messagesOpen = false
        idleSeconds = 0
        afterDialogue = []
    }

    var showsOverlayDialogue: Bool { dialogue.isActive && inlineHosts == 0 }

    // MARK: Dialogue

    func start(_ id: String) {
        guard dialogue.hasNode(id) else { print("[Story] missing node \(id)"); return }
        idleSeconds = 0
        dialogue.start(id)
    }

    /// Runs `f` now if nothing is being said, otherwise when the conversation ends.
    func whenQuiet(_ f: @escaping () -> Void) {
        if dialogue.isActive { afterDialogue.append(f) } else { f() }
    }

    private func finished(_ id: String) {
        idleSeconds = 0
        let pending = afterDialogue
        afterDialogue = []
        pending.forEach { $0() }
        ch2Finished(id)
    }

    private func handleEvent(_ e: String) {
        switch e {
        case "glitch":
            AudioManager.shared.play(.glitch)
            vexley.handle(.glitchPulse)
        case "glitch_long":
            AudioManager.shared.play(.glitchLong)
            vexley.handle(.glitchPulse)
        case "heartbeat":
            AudioManager.shared.play(.heartbeat)
        default:
            if ch2Event(e) { return }
            _ = laterEvent(e)
        }
    }

    private func flag(_ f: String) {
        ch2Flag(f)
        ch3Flag(f)
        laterFlag(f)
    }

    private func tick() {
        guard session.screen != .title, !session.paused else { return }
        if !dialogue.isActive { idleSeconds += 1 }
        ch2Tick()
        laterTick()
    }

    private func loaded() {
        session.apartment?.refreshMonitor()
    }

    // MARK: Hooks from the world and the desktop

    func desktopEntered() {
        ch2DesktopEntered()
        ch3DesktopEntered()
        laterDesktopEntered()
    }

    /// Return true if the story took over the door.
    func useDoor() -> Bool {
        ch2Door()
    }

    /// Return true if the story took over the shutdown.
    func interceptShutdown() -> Bool {
        ch2InterceptShutdown()
    }

    /// The OLD window's close button (Chapter 2 onwards). Return true to allow closing.
    func oldWindowCloseRequested() -> Bool {
        ch2CloseRequested()
    }

    /// A line for the bed when it isn't time to sleep yet.
    func bedLine() -> String {
        switch session.currentObjective?.id ?? "" {
        case "ch2_check": return "The monitor's on. I want to know why first."
        case "ch2_play": return "It's the middle of the day."
        case "ch2_dinner": return "Food first. I'm shaking."
        case "ch2_read", "ch2_shutdown": return "Not with the computer still running."
        case "ch3_boot", "ch3_wait": return "I just got up."
        case "ch3_update", "ch3_notice", "ch3_talk", "ch3_restore": return "Not until I know what's happening on that computer."
        case "ch4_tv", "ch4_ask", "ch4_try", "ch4_use": return "It's the middle of the day."
        default: return "I'm not tired yet."
        }
    }
}
