import SwiftUI
import SpriteKit
import Combine

/// Runs the original game (OLD): boot → title → Lantern Town → Vexley's first appearance
/// → the helper room → the refused exit. Story progress is stored as flags, so a loaded
/// save resumes in the right state.
@MainActor
final class RetroGameController: ObservableObject {
    static let shared = RetroGameController()

    enum Phase { case boot, title, playing }

    struct MenuItem: Identifiable, Equatable {
        let id: String
        var label: String
        var offset: CGSize = .zero
    }

    @Published var phase: Phase = .boot
    @Published var bootLines: [String] = []
    @Published var menuOpen = false
    @Published var menu: [MenuItem] = []
    @Published var debugText = ""
    @Published var vexleyEntrance = false
    @Published var glitch: Double = 0
    @Published var startLabel = "START"

    var held: Dir?
    let dialogue = DialogueManager(file: "dialogue_ch1")
    private(set) var scene: RetroGameScene?
    private var session: GameSession { GameSession.shared }
    private var vexley: VexleyController { VexleyController.shared }
    private var comp: ComputerSimulationManager { ComputerSimulationManager.shared }
    private var interacted: Set<String> = []
    private var playTime: Double = 0
    private var quitDodges = 0
    private var secretBumps = 0
    private var bag = Set<AnyCancellable>()
    private var clock: Timer?
    private var buildDate = "1998-10-02"
    private var pendingAfterDialogue: (() -> Void)?

    private init() {
        dialogue.onEvent = { [weak self] e in self?.handleEvent(e) }
        dialogue.onFinish = { [weak self] id in self?.dialogueFinished(id) }
        dialogue.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &bag)
        WorldHooks.resetHandlers.append { _ in RetroGameController.shared.reset() }
        OldGameHooks.shouldClose = { RetroGameController.shared.attemptClose() }
        OldGameHooks.shouldKill = { RetroGameController.shared.attemptKill() }
        OldGameHooks.onMinimize = { GameSession.shared.data.desktop.lastFocusLossAt = Date() }
        OldGameHooks.onDesktopReturn = { RetroGameController.shared.returnedToDesktop() }
    }

    static func bootstrap() { _ = shared }

    func reset() {
        dialogue.cancel()
        scene = nil
        phase = .boot
        bootLines = []
        menuOpen = false
        interacted = []
        playTime = 0
        quitDodges = 0
        secretBumps = 0
        vexleyEntrance = false
        held = nil
        clock?.invalidate()
    }

    var canMove: Bool { phase == .playing && !dialogue.isActive && !menuOpen && !vexleyEntrance }

    // MARK: Lifecycle

    func makeSceneIfNeeded() -> RetroGameScene {
        if let s = scene { return s }
        let data = DataLoader.load("retro_map", as: RetroMapData.self)
            ?? RetroMapData(tileSize: 16, rows: ["T"], playerStart: [0, 0], secretTile: [0, 0], helperRoomTrigger: [0, 0], walkable: ".", entities: [])
        let s = RetroGameScene(map: data)
        s.controller = self
        scene = s
        restoreFromFlags()
        return s
    }

    func windowAppeared() {
        _ = makeSceneIfNeeded()
        AudioManager.shared.setScene(session.has("vexley_met") ? .retroDread : .retro)
        AudioManager.shared.setDread(session.has("vexley_refused_exit") ? 0.25 : 0)
        if phase == .boot && bootLines.isEmpty { boot() }
        clock?.invalidate()
        clock = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickSecond() }
        }
        updateDebug()
    }

    func windowDisappeared() {
        clock?.invalidate()
        held = nil
        if session.screen == .desktop { AudioManager.shared.setScene(.desktop) }
    }

    private func boot() {
        if !session.has("old_launched") {
            session.set("old_launched")
            vexley.handle(.activated)
        }
        let lines = ["HSW-PACK v2: unpacking paperlight_dev.exe", "mounting data… ok", "VXL module: present (flag DISABLED)",
                     "VXL module: ...", "PAPERLIGHT build 0.7.3 — Halden Softworks — INTERNAL"]
        for (i, l) in lines.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35 * Double(i + 1)) { [weak self] in
                self?.bootLines.append(l)
                AudioManager.shared.play(.keyTap)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { [weak self] in
            self?.phase = .title
            AudioManager.shared.play(.retroStart)
            if !(self?.session.has("old_title_seen") ?? true) {
                self?.session.set("old_title_seen")
                self?.session.say("That's the title screen. That's actually it.")
                self?.session.say("It looks exactly like I remember. Except... I don't remember the debug text.")
            }
        }
    }

    /// Re-applies the map changes Vexley made, after a reload.
    private func restoreFromFlags() {
        guard let s = scene else { return }
        menu = baseMenu()
        if session.has("vexley_met") && session.has("vx_door_open") {
            openHelperDoor(animated: false)
            s.showFox()
            rewriteMenu()
            startLabel = "PAUSE (V)"
        }
        if session.has("vexley_met") { buildDate = Self.today() }
    }

    private func baseMenu() -> [MenuItem] {
        [MenuItem(id: "resume", label: "Resume"), MenuItem(id: "options", label: "Options"), MenuItem(id: "quit", label: "Quit to desktop")]
    }

    private func tickSecond() {
        guard phase == .playing, session.screen == .desktop else { return }
        playTime += 1
        if !session.has("vexley_met") && !session.has("vx_stirring") && (interacted.count >= 3 || playTime > 90) {
            session.set("vx_stirring")
            buildDate = "????-??-??"
            AudioManager.shared.play(.glitch)
            glitchPulse(0.4)
            AudioManager.shared.setDread(0.15)
        }
        updateDebug()
    }

    private func updateDebug() {
        guard let s = scene else { return }
        let vxl = session.has("vexley_met") ? "VXL:ACTIVE" : (session.has("vx_stirring") ? "VXL:..." : "VXL:off")
        debugText = "x:\(s.px) y:\(s.py)  map:town_01  build:\(buildDate)  \(vxl)"
    }

    static func today() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date())
    }

    // MARK: Input

    func pressStart() {
        switch phase {
        case .boot: return
        case .title:
            AudioManager.shared.play(.retroStart)
            phase = .playing
            if !session.has("old_played") {
                session.set("old_played")
                session.say("Lantern Town. I can almost hear my old room.")
            }
            updateDebug()
        case .playing:
            guard !dialogue.isActive, !vexleyEntrance else { return }
            AudioManager.shared.play(.retroSelect)
            menuOpen.toggle()
            if menuOpen { quitDodgesResetIfNeeded() }
        }
    }

    func pressA() {
        if phase == .title { pressStart(); return }
        guard phase == .playing, !vexleyEntrance else { return }
        if dialogue.isActive { dialogue.advance(); return }
        if menuOpen { return }
        guard let s = scene else { return }
        let (fx, fy) = s.facingTile
        interact(x: fx, y: fy)
    }

    func pressB() {
        if menuOpen { menuOpen = false; AudioManager.shared.play(.retroBlip); return }
        if dialogue.isActive { dialogue.advance() }
    }

    // MARK: World interaction

    private func interact(x: Int, y: Int) {
        guard let s = scene else { return }
        if let e = s.entity(at: x, y) {
            // the first interaction after the build starts "stirring" is hijacked
            if session.has("vx_stirring") && !session.has("vexley_met") {
                startDialogue("vx_pre_1")
                return
            }
            interacted.insert(e.id)
            if e.id == "helper_door" && session.has("vx_door_open") { return }
            startDialogue(e.dialogue)
            return
        }
        switch s.tile(x, y) {
        case "~": startDialogue("water")
        case "X": startDialogue("missing_texture"); interacted.insert("missing")
        case "?": startDialogue("void"); interacted.insert("void")
        case "L", "l": startDialogue("sign_lighthouse")
        default: break
        }
    }

    func onStep(x: Int, y: Int) {
        updateDebug()
        guard let s = scene else { return }
        let t = s.map.helperRoomTrigger
        if x == t[0] && y == t[1] && session.has("vx_door_open") && !session.has("vx_room_started") {
            session.set("vx_room_started")
            startDialogue("vx_room_1")
        }
        let sec = s.map.secretTile
        if !(x == sec[0] && y == sec[1]) { secretBumps = 0 }
    }

    func onBump(x: Int, y: Int, dir: Dir) {
        guard let s = scene else { return }
        let sec = s.map.secretTile
        if s.px == sec[0] && s.py == sec[1] && dir == .up && !session.has("vexley_met") {
            secretBumps += 1
            AudioManager.shared.play(.retroBlip)
            if secretBumps >= 3 {
                secretBumps = 0
                session.set("found_secret_fox")
                startDialogue("vx_secret_1")
            }
        }
    }

    private func startDialogue(_ id: String) {
        held = nil
        dialogue.start(id)
    }

    private func dialogueFinished(_ id: String) {
        if let p = pendingAfterDialogue { pendingAfterDialogue = nil; p() }
        switch id {
        case "vx_door2":
            session.say("It moved the door. It's... talking to me.")
        case "vx_room_end":
            session.say("It's almost two. I really should stop.")
        case "vx_refuse_promise3", "vx_refuse_cold2":
            session.say("The quit button won't work. Fine. I'll deal with it tomorrow.")
        default: break
        }
        updateDebug()
    }

    // MARK: Dialogue events (UI manipulation)

    private func handleEvent(_ e: String) {
        switch e {
        case "glitch":
            AudioManager.shared.play(.glitch)
            glitchPulse(0.6)
            vexley.handle(.glitchPulse)
        case "glitch_long":
            AudioManager.shared.play(.glitchLong)
            glitchPulse(1.0)
            vexley.handle(.glitchPulse)
        case "rewrite_debug":
            buildDate = Self.today()
            updateDebug()
        case "vexley_appear":
            vexley.handle(.activated)
            vexleyEntrance = true
            AudioManager.shared.setScene(.retroDread)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
                withAnimation(.easeInOut(duration: 0.5)) { self?.vexleyEntrance = false }
            }
        case "open_helper_door":
            session.set("vx_door_open")
            openHelperDoor(animated: true)
        case "rewrite_menu":
            rewriteMenu()
            startLabel = "PAUSE (V)"
        case "show_fox":
            scene?.showFox()
        case "sign_rewrite":
            session.set("vx_sign_rewritten")
        case "retitle_window":
            if let i = comp.windows.firstIndex(where: { $0.app == .oldgame }) {
                comp.windows[i].title = "PAPERLIGHT (dev 0.7.3) — VXL"
            }
        case "lock_window":
            session.set("vexley_refused_exit")
            menuOpen = false
            AudioManager.shared.setDread(0.25)
            session.apartment?.refreshMonitor()
        default:
            break
        }
    }

    private func glitchPulse(_ amount: Double) {
        glitch = amount
        scene?.glitchWorld()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in self?.glitch = amount * 0.3 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.glitch = 0 }
    }

    private func openHelperDoor(animated: Bool) {
        guard let s = scene else { return }
        if let door = s.map.entities.first(where: { $0.id == "helper_door" }) {
            s.setTile(door.x, door.y, "r")
        }
        if animated { AudioManager.shared.play(.retroStart) }
    }

    private func rewriteMenu() {
        menu = [MenuItem(id: "resume", label: "Resume"), MenuItem(id: "ask", label: "Ask Vexley"), MenuItem(id: "quit", label: "Quit")]
    }

    // MARK: Pause menu

    private func quitDodgesResetIfNeeded() {
        if session.has("vexley_refused_exit") {
            if let i = menu.firstIndex(where: { $0.id == "quit" }) { menu[i].label = "Stay"; menu[i].offset = .zero }
        }
    }

    func selectMenu(_ item: MenuItem) {
        AudioManager.shared.play(.retroSelect)
        switch item.id {
        case "resume":
            menuOpen = false
        case "options":
            menuOpen = false
            startDialogue("void")
        case "ask":
            menuOpen = false
            startDialogue("vx_ask")
        case "quit":
            quitPressed()
        default: break
        }
    }

    private func quitPressed() {
        if !session.has("vexley_met") {
            menuOpen = false
            comp.windows.removeAll { $0.app == .oldgame }
            session.data.desktop.oldWindowOpen = false
            session.say("I'll come back to it.")
            return
        }
        if session.has("vexley_refused_exit") {
            menuOpen = false
            attemptCloseDialogue()
            return
        }
        if !session.has("vx_room_seen") {
            menuOpen = false
            startDialogue("vx_quit_early")
            return
        }
        // the Quit button runs away
        guard let i = menu.firstIndex(where: { $0.id == "quit" }) else { return }
        quitDodges += 1
        AudioManager.shared.play(.glitch)
        let labels = ["Quit?", "Qu it", "Stay."]
        withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
            menu[i].offset = CGSize(width: CGFloat.random(in: -70...70), height: CGFloat.random(in: -20...26))
            menu[i].label = labels[min(quitDodges - 1, labels.count - 1)]
        }
        if quitDodges >= 3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.menuOpen = false
                self?.startDialogue("vx_refuse_1")
            }
        }
    }

    // MARK: Window hooks (Vexley refuses to close)

    private func attemptCloseDialogue() {
        if vexley.remembers("tried_to_close_window") { vexley.remember("tried_to_close_twice") }
        vexley.handle(.playerTriedToClose)
        startDialogue("vx_close_attempt")
    }

    func attemptClose() -> Bool {
        guard session.has("vexley_refused_exit") else {
            if session.has("vexley_met") && !session.has("vexley_refused_exit") {
                // He's not ready to let go yet either, but he asks rather than blocks.
                if let i = comp.windows.firstIndex(where: { $0.app == .oldgame }) { comp.windows[i].minimized = false; comp.windows[i].maximized = true }
                startDialogue(session.has("vx_room_seen") ? "vx_refuse_1" : "vx_quit_early")
                return false
            }
            return true
        }
        if let i = comp.windows.firstIndex(where: { $0.app == .oldgame }) {
            comp.windows[i].minimized = false
            comp.windows[i].maximized = true
            comp.focus(comp.windows[i].id)
        }
        AudioManager.shared.play(.glitch)
        attemptCloseDialogue()
        return false
    }

    func attemptKill() -> Bool {
        guard session.has("vexley_met") else { return true }
        comp.alert("Task Manager", "Unable to terminate process paperlight_dev.exe.\n\nAccess is denied.", icon: "xmark.octagon.fill", tint: .red)
        vexley.handle(.playerTriedToKill)
        if let i = comp.windows.firstIndex(where: { $0.app == .oldgame }) {
            comp.windows[i].minimized = false
            comp.windows[i].maximized = true
        }
        pendingAfterDialogue = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.comp.dialog = nil
            if let id = self?.comp.windows.first(where: { $0.app == .oldgame })?.id { self?.comp.focus(id) }
            self?.startDialogue("vx_kill_attempt")
        }
        return false
    }

    /// Back from the apartment (or another app). He noticed the window lost focus — but
    /// he can only see that it lost focus, not what the player did.
    func returnedToDesktop() {
        vexley.handle(.playerReturned)
        guard session.has("av_scanned") || session.has("vexley_refused_exit"),
              !vexley.remembers("noticed_focus_loss") else { return }
        if let i = comp.windows.firstIndex(where: { $0.app == .oldgame }) {
            comp.windows[i].minimized = false
            comp.windows[i].maximized = true
            comp.focus(comp.windows[i].id)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self, !self.dialogue.isActive else { return }
            if self.phase != .playing { self.phase = .playing }
            self.startDialogue("vx_noticed_away")
        }
    }
}
