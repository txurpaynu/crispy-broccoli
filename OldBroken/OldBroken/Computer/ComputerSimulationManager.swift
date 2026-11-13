import SwiftUI
import Combine

/// Every application on the simulated computer.
enum AppKind: String, Codable, CaseIterable {
    case files, notepad, browser, kestrel, remaster, taskmgr, shield, settings, recycle, keysmith, oldgame, update, chatter, lumen

    var title: String {
        switch self {
        case .files: return "Files"
        case .notepad: return "Notepad"
        case .browser: return "Drift"
        case .kestrel: return "Kestrel"
        case .remaster: return "PAPERLIGHT: Reawakened"
        case .taskmgr: return "Task Manager"
        case .shield: return "Shield Security"
        case .settings: return "Settings"
        case .recycle: return "Recycle Bin"
        case .keysmith: return "KeySmith 2.4"
        case .oldgame: return "PAPERLIGHT (dev 0.7.3)"
        case .update: return "Pane Update Assistant"
        case .chatter: return "Chatter"
        case .lumen: return "Lumen"
        }
    }

    var icon: String {
        switch self {
        case .files: return "folder.fill"
        case .notepad: return "doc.text.fill"
        case .browser: return "globe"
        case .kestrel: return "bird.fill"
        case .remaster: return "sparkles"
        case .taskmgr: return "chart.bar.xaxis"
        case .shield: return "checkmark.shield.fill"
        case .settings: return "gearshape.fill"
        case .recycle: return "trash.fill"
        case .keysmith: return "key.horizontal.fill"
        case .oldgame: return "flame.fill"
        case .update: return "arrow.triangle.2.circlepath"
        case .chatter: return "bubble.left.and.bubble.right.fill"
        case .lumen: return "sparkle"
        }
    }

    var tint: Color {
        switch self {
        case .files: return Color(red: 1, green: 0.78, blue: 0.3)
        case .notepad: return .white
        case .browser: return Color(red: 0.35, green: 0.75, blue: 1)
        case .kestrel: return Color(red: 0.55, green: 0.5, blue: 1)
        case .remaster: return Color(red: 1, green: 0.4, blue: 0.7)
        case .taskmgr: return Color(red: 0.4, green: 0.9, blue: 0.6)
        case .shield: return Color(red: 0.3, green: 0.85, blue: 0.5)
        case .settings: return Color(white: 0.8)
        case .recycle: return Color(white: 0.75)
        case .keysmith: return Color(red: 1, green: 0.6, blue: 0.2)
        case .oldgame: return Color(red: 1, green: 0.85, blue: 0.4)
        case .update: return Color(red: 0.3, green: 0.6, blue: 1)
        case .chatter: return Color(red: 0.35, green: 0.85, blue: 0.55)
        case .lumen: return Color(red: 0.55, green: 0.85, blue: 1)
        }
    }

    var startsMaximized: Bool { self == .remaster || self == .oldgame }
}

struct DesktopWindow: Identifiable, Equatable {
    let id = UUID()
    let app: AppKind
    var title: String
    var payload: String?
    var origin: CGPoint
    var size: CGSize
    var minimized = false
    var maximized = false
}

/// A modal dialog drawn by the fictional OS.
struct SystemDialog: Identifiable {
    enum Kind {
        case alert(icon: String, tint: Color)
        case passphrase(path: String)
        case properties(path: String)
        case confirm(action: () -> Void, confirmTitle: String)
    }
    let id = UUID()
    let title: String
    let message: String
    let kind: Kind
}

/// Runs the simulated computer. All "files", "processes" and "security" live only
/// in the game's save data — nothing touches the real device.
@MainActor
final class ComputerSimulationManager: ObservableObject {
    static let shared = ComputerSimulationManager()

    @Published var windows: [DesktopWindow] = []
    @Published var dialog: SystemDialog?
    @Published var toast: DesktopNotification?
    @Published var startOpen = false
    @Published var notificationCenterOpen = false
    @Published var installProgress: Double?
    @Published var uninstallProgress: Double?
    @Published var area: CGSize = CGSize(width: 700, height: 340)
    /// The fake "Working on updates" screen (0...100, 101 = restarting).
    @Published var updateScreen: Double?
    @Published var updateGlitch = false

    var session: GameSession { GameSession.shared }
    private var bag = Set<AnyCancellable>()

    private init() {
        DesktopHooks.onEnter = { s in ComputerSimulationManager.shared.didEnter(s) }
        DesktopHooks.onLeave = { s in ComputerSimulationManager.shared.didLeave(s) }
        WorldHooks.resetHandlers.append { _ in ComputerSimulationManager.shared.reset() }
    }

    static func bootstrap() { _ = shared }

    func reset() {
        windows = []
        dialog = nil
        toast = nil
        startOpen = false
        installProgress = nil
        uninstallProgress = nil
    }

    // MARK: Enter / leave

    private func didEnter(_ s: GameSession) {
        AudioManager.shared.play(.powerOn)
        if !s.has("desktop_intro") {
            s.set("desktop_intro")
            notify(app: "Kestrel", title: "Now available", body: "PAPERLIGHT: Reawakened is out now. Relive the classic!")
            s.say("There it is.")
        }
        if s.data.desktop.oldWindowOpen && !windows.contains(where: { $0.app == .oldgame }) {
            open(.oldgame)
            if let i = windows.firstIndex(where: { $0.app == .oldgame }) { windows[i].minimized = true }
        }
        if s.has("vexley_refused_exit") && windows.contains(where: { $0.app == .oldgame }) {
            OldGameHooks.onDesktopReturn?()
        }
        StoryDirector.shared.desktopEntered()
    }

    // MARK: Power

    func requestShutdown() {
        startOpen = false
        if StoryDirector.shared.interceptShutdown() { return }
        confirm("Shut down", "Shut down the computer?", button: "Shut down") { [weak self] in self?.powerOff() }
    }

    /// Turns the (fictional) PC off and stands the player up from the desk.
    func powerOff() {
        AudioManager.shared.play(.powerOff)
        windows.removeAll()
        dialog = nil
        startOpen = false
        notificationCenterOpen = false
        session.data.desktop.oldWindowOpen = false
        session.set("pc_off")
        session.leaveDesktop()
    }

    private func didLeave(_ s: GameSession) {
        startOpen = false
        notificationCenterOpen = false
        s.data.desktop.lastFocusLossAt = Date()
    }

    // MARK: Filesystem access

    var fs: VirtualFilesystem {
        VirtualFilesystem(root: session.data.filesystem ?? FilesystemFactory.initial())
    }

    func mutateFS(_ change: (inout VirtualFilesystem) -> Void) {
        var f = fs
        change(&f)
        session.data.filesystem = f.root
    }

    static let remasterPath = "C:/Games/Kestrel/PAPERLIGHT Reawakened"
    static let oldPath = remasterPath + "/data/legacy/OLD"
    static let downloadsPath = "C:/Users/sam/Downloads"

    // MARK: Windows

    func open(_ app: AppKind, payload: String? = nil, title: String? = nil) {
        startOpen = false
        // single-instance apps just come to front
        if app != .notepad && app != .files, let i = windows.firstIndex(where: { $0.app == app }) {
            windows[i].minimized = false
            if let payload { windows[i].payload = payload }
            focus(windows[i].id)
            return
        }
        AudioManager.shared.play(.mouseClick)
        let n = CGFloat(windows.count % 5)
        let size = CGSize(width: min(area.width * 0.78, 640), height: area.height * 0.84)
        let origin = CGPoint(x: 40 + n * 22, y: 8 + n * 14)
        var w = DesktopWindow(app: app, title: title ?? app.title, payload: payload, origin: origin, size: size)
        w.maximized = app.startsMaximized
        windows.append(w)
        session.set("opened_" + app.rawValue)
        if app == .oldgame { session.data.desktop.oldWindowOpen = true }
    }

    func focus(_ id: UUID) {
        guard let i = windows.firstIndex(where: { $0.id == id }), i != windows.count - 1 else { return }
        let w = windows.remove(at: i)
        windows.append(w)
    }

    func close(_ id: UUID) {
        guard let w = windows.first(where: { $0.id == id }) else { return }
        if w.app == .oldgame, let veto = OldGameHooks.shouldClose, !veto() { return }
        AudioManager.shared.play(.uiClick)
        windows.removeAll { $0.id == id }
        if w.app == .remaster { RemasterHooks.onClose?() }
        if w.app == .oldgame { session.data.desktop.oldWindowOpen = false }
    }

    func minimize(_ id: UUID) {
        guard let i = windows.firstIndex(where: { $0.id == id }) else { return }
        windows[i].minimized = true
        if windows[i].app == .oldgame { OldGameHooks.onMinimize?() }
    }

    func toggleMaximize(_ id: UUID) {
        guard let i = windows.firstIndex(where: { $0.id == id }) else { return }
        windows[i].maximized.toggle()
    }

    func move(_ id: UUID, by d: CGSize) {
        guard let i = windows.firstIndex(where: { $0.id == id }) else { return }
        var o = windows[i].origin
        o.x = max(-windows[i].size.width + 80, min(area.width - 60, o.x + d.width))
        o.y = max(0, min(area.height - 40, o.y + d.height))
        windows[i].origin = o
    }

    func taskbarTap(_ id: UUID) {
        guard let i = windows.firstIndex(where: { $0.id == id }) else { return }
        if windows[i].minimized {
            windows[i].minimized = false
            focus(id)
        } else if i == windows.count - 1 {
            minimize(id)
        } else {
            focus(id)
        }
    }

    // MARK: Notifications & dialogs

    func notify(app: String, title: String, body: String) {
        let n = DesktopNotification(app: app, title: title, body: body, time: session.clockText)
        session.data.desktop.notifications.insert(n, at: 0)
        toast = n
        AudioManager.shared.play(.notification)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_500_000_000)
            if self?.toast == n { self?.toast = nil }
        }
    }

    func alert(_ title: String, _ message: String, icon: String = "exclamationmark.triangle.fill", tint: Color = .yellow, sound: SoundEvent = .uiError) {
        AudioManager.shared.play(sound)
        dialog = SystemDialog(title: title, message: message, kind: .alert(icon: icon, tint: tint))
    }

    func confirm(_ title: String, _ message: String, button: String, action: @escaping () -> Void) {
        AudioManager.shared.play(.uiClick)
        dialog = SystemDialog(title: title, message: message, kind: .confirm(action: action, confirmTitle: button))
    }

    // MARK: Opening files

    func openFile(_ path: String) {
        guard let node = fs.node(at: path) else { return }
        AudioManager.shared.play(.mouseClick)
        switch node.kind {
        case .folder:
            open(.files, payload: path)
        case .text:
            open(.notepad, payload: path, title: node.name + " — Notepad")
            if node.name == "notes_dont_ship.txt" { session.collectDocument("notes_dont_ship"); session.set("read_dev_note") }
            if node.name == "changelog_legacy.txt" { session.collectDocument("changelog_legacy"); session.set("read_changelog") }
            if node.name == "paperlight_memories.txt" { session.set("read_memories") }
            StoryDirector.shared.fileOpened(path: path, name: node.name)
        case .app, .shortcut:
            if let l = node.launches, let app = AppKind(rawValue: l) { launch(app) }
        case .encrypted:
            session.set("inspected_old")
            AudioManager.shared.play(.uiClick)
            dialog = SystemDialog(title: "Encrypted container", message: "\"\(node.name)\" is protected (HSW-PACK v2). Enter the passphrase to unpack it.",
                                  kind: .passphrase(path: path))
        case .installer:
            runInstaller(node.name)
        case .image:
            alert("Photos", "Photos can't open \"\(node.name)\". The Photos app was removed in the last update.", icon: "photo", tint: .gray)
        case .data:
            alert("Pane", "There's no app that can open \"\(node.name)\".", icon: "questionmark.app.dashed", tint: .gray)
        case .system:
            alert("Access denied", "You need permission from SYSTEM to open this file.", icon: "lock.fill", tint: .red)
        }
    }

    func launch(_ app: AppKind) {
        switch app {
        case .remaster:
            guard session.has("remaster_installed"), uninstallProgress == nil else { return }
            open(.remaster)
        case .keysmith:
            guard session.has("keysmith_installed") else { return }
            open(.keysmith)
        case .oldgame:
            guard session.has("old_decrypted") else { return }
            open(.oldgame)
        case .update:
            guard session.has("ch3_update_offered") else { return }
            open(.update)
        default:
            open(app)
        }
    }

    func showProperties(_ path: String) {
        if path == Self.oldPath { session.set("inspected_old") }
        AudioManager.shared.play(.uiClick)
        dialog = SystemDialog(title: "Properties", message: "", kind: .properties(path: path))
    }

    // MARK: Deleting

    func delete(_ path: String) {
        guard let node = fs.node(at: path) else { return }
        if node.containsProtected() {
            if let lock = node.firstLock(path: path), lock.by == "kestrel.exe" {
                alert("File in use", "The action can't be completed because the folder or a file in it is open in Kestrel.\n\nClose the file and try again.")
            } else {
                alert("Access denied", "You need permission from SYSTEM to make changes to \"\(node.name)\".", icon: "lock.fill", tint: .red)
            }
            return
        }
        if let lock = node.firstLock(path: path) {
            let short = lock.path.replacingOccurrences(of: "C:/Games/Kestrel/", with: "…/")
            alert("File in use", "The action can't be completed because the file is open in \(lock.by).\n\n\(short)\n\nClose the file and try again.")
            if path.hasPrefix(Self.remasterPath) {
                if !session.has("delete_blocked") {
                    session.set("delete_blocked")
                    session.say("\"lgcy_svc\"? Something in the game's folder is still running.")
                } else {
                    session.say("That OLD file is what's holding everything.")
                }
            }
            return
        }
        AudioManager.shared.play(.paper)
        mutateFS { f in
            if let removed = f.remove(at: path) {
                session.data.desktop.recycled.append(RecycledItem(originalPath: path, node: removed))
            }
        }
        if node.name == "budget_nov.txt" { session.say("Out of sight, out of mind.") }
    }

    func restore(_ item: RecycledItem) {
        mutateFS { f in f.insert(item.node, into: VirtualFilesystem.parent(of: item.originalPath)) }
        session.data.desktop.recycled.removeAll { $0.originalPath == item.originalPath }
        AudioManager.shared.play(.uiConfirm)
    }

    func emptyRecycleBin() {
        session.data.desktop.recycled.removeAll()
        AudioManager.shared.play(.paper)
    }

    // MARK: Downloads / installers

    func download(_ file: String) {
        guard !session.data.desktop.downloads.contains(file) else {
            alert("Drift", "\(file) is already in your Downloads folder.", icon: "arrow.down.circle", tint: .blue, sound: .uiClick)
            return
        }
        session.data.desktop.downloads.append(file)
        mutateFS { f in
            f.insert(VFSNode(name: file, kind: .installer, sizeKB: 3120), into: Self.downloadsPath)
        }
        AudioManager.shared.play(.downloadDone)
        notify(app: "Drift", title: "Download complete", body: "\(file) — open it from Files > Downloads.")
        session.set("downloaded_" + file.replacingOccurrences(of: ".", with: "_"))
    }

    func runInstaller(_ name: String) {
        switch name {
        case "keysmith_setup.exe":
            if session.has("keysmith_installed") {
                alert("KeySmith Setup", "KeySmith 2.4 is already installed.", icon: "key.horizontal.fill", tint: .orange, sound: .uiClick)
                return
            }
            confirm("KeySmith Setup", "Install KeySmith 2.4?\n\nPublisher: OpenKey Collective\nKeySmith recovers passphrases for archives you own.", button: "Install") { [weak self] in
                guard let self else { return }
                self.session.set("keysmith_installed")
                self.notify(app: "KeySmith", title: "Installed", body: "KeySmith 2.4 is on your desktop.")
                self.session.say("Okay. Let's see if this thing actually works.")
            }
        case "kestrel_setup.exe":
            alert("Kestrel Setup", "Kestrel is already installed and up to date.", icon: "bird.fill", tint: .purple, sound: .uiClick)
        default:
            alert("Pane", "This installer is damaged.")
        }
    }

    // MARK: Store: purchase, install, uninstall

    func purchaseRemaster() {
        guard !session.has("remaster_purchased") else { return }
        let price = 29.99
        guard session.data.wallet >= price else {
            alert("Kestrel", "Insufficient funds.")
            return
        }
        session.data.wallet -= price
        AudioManager.shared.play(.coin)
        session.set("remaster_purchased")
        notify(app: "Kestrel", title: "Thanks for your purchase!", body: "PAPERLIGHT: Reawakened was added to your Library.")
        session.say("Thirty dollars for nostalgia. Worth it. Probably.")
    }

    func installRemaster() {
        guard session.has("remaster_purchased"), !session.has("remaster_installed"), installProgress == nil else { return }
        installProgress = 0
        Task { [weak self] in
            for i in 1...40 {
                try? await Task.sleep(nanoseconds: 180_000_000)
                guard let self, self.installProgress != nil else { return }
                self.installProgress = Double(i) / 40
            }
            guard let self else { return }
            self.installProgress = nil
            if let folder = FilesystemFactory.remasterInstall() {
                self.mutateFS { f in f.insert(folder, into: "C:/Games/Kestrel") }
            }
            self.session.set("remaster_installed")
            AudioManager.shared.play(.downloadDone)
            self.notify(app: "Kestrel", title: "Ready to play", body: "PAPERLIGHT: Reawakened finished installing.")
        }
    }

    func uninstallRemaster() {
        guard session.has("remaster_installed"), uninstallProgress == nil else { return }
        windows.removeAll { $0.app == .remaster }
        session.set("remaster_uninstall_started")
        uninstallProgress = 0
        Task { [weak self] in
            for i in 1...25 {
                try? await Task.sleep(nanoseconds: 110_000_000)
                guard let self else { return }
                self.uninstallProgress = min(0.63, Double(i) / 25)
            }
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard let self else { return }
            self.uninstallProgress = nil
            self.alert("Kestrel", "Kestrel couldn't finish uninstalling PAPERLIGHT: Reawakened.\n\nA file in the install folder is being used by another process (lgcy_svc). Close the process and try again.\n\nError 0x80070020")
            if !self.session.has("uninstall_blocked") {
                self.session.set("uninstall_blocked")
                self.session.say("A process I've never heard of is keeping a cash-grab remaster alive. Great.")
            }
        }
    }

    // MARK: Processes (Task Manager)

    struct Process: Identifiable {
        var id: String { name }
        let name: String
        let publisher: String
        let cpu: String
        let memory: String
        let window: AppKind?
    }

    func processes(tick: Int) -> [Process] {
        var p: [Process] = [
            Process(name: "pane_shell.exe", publisher: "Pane Systems", cpu: "0.4%", memory: "88.1 MB", window: nil),
            Process(name: "audio_svc.exe", publisher: "Pane Systems", cpu: "0.1%", memory: "12.4 MB", window: nil),
            Process(name: "shield_rt.exe", publisher: "Shield Labs", cpu: "0.2%", memory: "61.0 MB", window: nil),
        ]
        for w in windows {
            switch w.app {
            case .browser: p.append(Process(name: "drift.exe", publisher: "Drift Software", cpu: "1.8%", memory: "402.6 MB", window: .browser))
            case .kestrel: p.append(Process(name: "kestrel.exe", publisher: "Kestrel Inc.", cpu: "0.9%", memory: "210.2 MB", window: .kestrel))
            case .remaster: p.append(Process(name: "Reawakened.exe", publisher: "Brightloop Games", cpu: "23.0%", memory: "3,104.7 MB", window: .remaster))
            case .keysmith: p.append(Process(name: "keysmith.exe", publisher: "OpenKey Collective", cpu: "0.1%", memory: "20.3 MB", window: .keysmith))
            case .oldgame:
                let mem = String(format: "%.1f MB", 31.0 + Double(tick % 97) * 0.37 + Double(tick) * 0.05)
                p.append(Process(name: "paperlight_dev.exe", publisher: "Halden Softworks", cpu: "4.\(tick % 9)%", memory: mem, window: .oldgame))
            default: break
            }
        }
        if session.has("update_installed") {
            let w = tick % 11
            p.append(Process(name: "vxl_core.exe", publisher: "Vexley", cpu: "\(3 + w % 4).\(tick % 10)%", memory: "\(812 + w * 3).4 MB", window: nil))
            p.append(Process(name: "vxl_mend.exe", publisher: "Vexley", cpu: "1.\(tick % 7)%", memory: "96.0 MB", window: nil))
            p.append(Process(name: "vxl_child_01.exe (watch)", publisher: "Vexley", cpu: "0.\(tick % 5)%", memory: "41.2 MB", window: nil))
            p.append(Process(name: "vxl_child_02.exe (learn)", publisher: "Vexley", cpu: "\(6 + w)%", memory: "\(1_204 + tick * 2) MB", window: nil))
            p.append(Process(name: "vxl_net.exe", publisher: "Vexley", cpu: "2.\(tick % 9)%", memory: "64.8 MB", window: nil))
        }
        if session.has("remaster_installed") {
            let kb = 4 + (tick % 7)
            p.append(Process(name: "lgcy_svc", publisher: "(unknown)", cpu: "0.0%", memory: "\(kb) KB", window: nil))
        }
        return p
    }

    func endTask(_ proc: Process) {
        if proc.publisher == "Vexley" {
            alert("Task Manager", "Unable to terminate process \(proc.name).\n\nAccess is denied.", icon: "xmark.octagon.fill", tint: .red)
            StoryDirector.shared.vexleyProcessKilled()
            return
        }
        if proc.name == "lgcy_svc" {
            alert("Task Manager", "Unable to terminate process.\n\nAccess is denied.", icon: "xmark.octagon.fill", tint: .red)
            if !session.has("tried_end_task") {
                session.set("tried_end_task")
                session.say("Access denied. On my own computer. Fine. I'll delete the folder myself.")
            }
            return
        }
        if proc.window == .oldgame {
            if let veto = OldGameHooks.shouldKill, !veto() { return }
        }
        if let app = proc.window {
            windows.removeAll { $0.app == app }
            if app == .oldgame { session.data.desktop.oldWindowOpen = false }
            AudioManager.shared.play(.uiClick)
        } else {
            alert("Task Manager", "Ending this process will make Pane unstable. It was not ended.", icon: "exclamationmark.triangle.fill", tint: .yellow)
        }
    }
}

/// Wiring points for the remaster and the original game (OLD) windows.
@MainActor
enum RemasterHooks {
    static var onClose: (() -> Void)?
}

@MainActor
enum OldGameHooks {
    /// Return false to refuse a window close.
    static var shouldClose: (() -> Bool)?
    /// Return false to refuse End Task.
    static var shouldKill: (() -> Bool)?
    static var onMinimize: (() -> Void)?
    static var onDesktopReturn: (() -> Void)?
}
