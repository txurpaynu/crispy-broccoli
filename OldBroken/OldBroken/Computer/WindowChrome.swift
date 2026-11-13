import SwiftUI

/// A draggable window with title bar, minimize / maximize / close.
struct WindowChrome: View {
    @EnvironmentObject var comp: ComputerSimulationManager
    let window: DesktopWindow
    let area: CGSize
    @GestureState private var drag: CGSize = .zero

    var frameSize: CGSize { window.maximized ? area : window.size }
    var origin: CGPoint {
        window.maximized ? .zero : CGPoint(x: window.origin.x + drag.width, y: window.origin.y + drag.height)
    }

    var body: some View {
        VStack(spacing: 0) {
            if !(window.app == .oldgame && window.maximized) {
                titleBar
            }
            AppContent(window: window)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        }
        .frame(width: frameSize.width, height: frameSize.height)
        .background(Color(red: 0.11, green: 0.12, blue: 0.15))
        .clipShape(RoundedRectangle(cornerRadius: window.maximized ? 0 : 8))
        .overlay(RoundedRectangle(cornerRadius: window.maximized ? 0 : 8).stroke(.white.opacity(0.14)))
        .shadow(color: .black.opacity(0.5), radius: 14, y: 6)
        .offset(x: origin.x, y: origin.y)
        .simultaneousGesture(TapGesture().onEnded { comp.focus(window.id) })
    }

    private var titleBar: some View {
        HStack(spacing: 8) {
            Image(systemName: window.app.icon).foregroundStyle(window.app.tint).font(.system(size: 11))
            Text(window.title).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.85)).lineLimit(1)
            Spacer()
            chromeButton("minus") { comp.minimize(window.id) }
            chromeButton(window.maximized ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right") {
                comp.toggleMaximize(window.id)
            }
            chromeButton("xmark", destructive: true) { comp.close(window.id) }
        }
        .padding(.leading, 10)
        .frame(height: 30)
        .background(Color(red: 0.07, green: 0.075, blue: 0.1))
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 2)
                .updating($drag) { v, s, _ in if !window.maximized { s = v.translation } }
                .onEnded { v in if !window.maximized { comp.move(window.id, by: v.translation) } }
        )
    }

    private func chromeButton(_ icon: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 36, height: 30)
                .background(destructive ? Color.red.opacity(0.0001) : .clear)
        }
        .buttonStyle(.plain)
    }
}

/// Routes a window to its app view.
struct AppContent: View {
    let window: DesktopWindow
    var body: some View {
        switch window.app {
        case .files: FilesApp(windowID: window.id, startPath: window.payload ?? "C:/Users/sam")
        case .notepad: NotepadApp(path: window.payload ?? "")
        case .browser: BrowserApp()
        case .kestrel: KestrelApp()
        case .remaster: RemasterApp()
        case .taskmgr: TaskManagerApp()
        case .shield: ShieldApp()
        case .settings: SettingsApp()
        case .recycle: RecycleBinApp()
        case .keysmith: KeySmithApp()
        case .oldgame: OldGameWindow()
        }
    }
}

/// OS-styled modal dialogs: alerts, confirmations, passphrase prompt, file properties.
struct SystemDialogView: View {
    @EnvironmentObject var comp: ComputerSimulationManager
    @EnvironmentObject var session: GameSession
    let dialog: SystemDialog
    @State private var text = ""
    @State private var wrong = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(dialog.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
            content
        }
        .padding(16)
        .background(Color(red: 0.13, green: 0.14, blue: 0.18), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.15)))
        .shadow(color: .black.opacity(0.6), radius: 20)
    }

    @ViewBuilder private var content: some View {
        switch dialog.kind {
        case .alert(let icon, let tint):
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon).font(.system(size: 24)).foregroundStyle(tint)
                Text(dialog.message).font(.system(size: 12)).foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack { Spacer(); okButton("OK") { comp.dialog = nil } }

        case .confirm(let action, let confirmTitle):
            Text(dialog.message).font(.system(size: 12)).foregroundStyle(.white.opacity(0.85)).fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                okButton("Cancel", primary: false) { comp.dialog = nil }
                okButton(confirmTitle) { comp.dialog = nil; action() }
            }

        case .passphrase(let path):
            Text(dialog.message).font(.system(size: 12)).foregroundStyle(.white.opacity(0.85)).fixedSize(horizontal: false, vertical: true)
            SecureField("Passphrase", text: $text)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.system(size: 13, design: .monospaced))
                .padding(8)
                .background(.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(wrong ? Color.red : Color.white.opacity(0.2)))
                .onSubmit(submit)
            if wrong {
                Text("Incorrect passphrase.").font(.system(size: 11)).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                okButton("Cancel", primary: false) { comp.dialog = nil }
                okButton("Unpack") { submit() }
            }
            .onAppear { _ = path }

        case .properties(let path):
            PropertiesBody(path: path)
            HStack { Spacer(); okButton("OK") { comp.dialog = nil } }
        }
    }

    private func submit() {
        guard case .passphrase(let path) = dialog.kind else { return }
        if PuzzleManager.shared.tryPassphrase(text, path: path) {
            comp.dialog = nil
        } else {
            wrong = true
            text = ""
        }
    }

    private func okButton(_ t: String, primary: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t).font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(primary ? Color(red: 0.25, green: 0.45, blue: 0.9) : Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 5))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

struct PropertiesBody: View {
    @EnvironmentObject var comp: ComputerSimulationManager
    let path: String

    var body: some View {
        if let n = comp.fs.node(at: path) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 10) {
                    Image(systemName: FileIcon.symbol(n)).font(.system(size: 26)).foregroundStyle(FileIcon.tint(n))
                    Text(n.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                }
                .padding(.bottom, 4)
                row("Type", n.meta?["Type"] ?? FileIcon.typeName(n))
                row("Location", VirtualFilesystem.parent(of: path))
                row("Size", FileIcon.size(n.isFolder ? n.totalSizeKB : n.sizeKB))
                row("Created", n.created)
                row("Modified", n.modified)
                if let m = n.meta {
                    ForEach(m.keys.sorted().filter { $0 != "Type" }, id: \.self) { k in row(k, m[k] ?? "") }
                }
                row("Attributes", n.protected ? "System, Read-only" : (n.kind == .encrypted ? "Encrypted, Archive" : "Archive"))
            }
        }
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top) {
            Text(k + ":").foregroundStyle(.white.opacity(0.5)).frame(width: 90, alignment: .leading)
            Text(v).foregroundStyle(.white.opacity(0.9)).textSelection(.enabled)
        }
        .font(.system(size: 11))
    }
}

enum FileIcon {
    static func symbol(_ n: VFSNode) -> String {
        switch n.kind {
        case .folder: return "folder.fill"
        case .text: return "doc.text"
        case .app, .shortcut: return n.launches == "oldgame" ? "flame.fill" : "app.fill"
        case .encrypted: return "lock.doc.fill"
        case .data: return "doc.zipper"
        case .image: return "photo"
        case .installer: return "shippingbox.fill"
        case .system: return "gearshape.2.fill"
        }
    }

    static func tint(_ n: VFSNode) -> Color {
        switch n.kind {
        case .folder: return Color(red: 1, green: 0.78, blue: 0.3)
        case .encrypted: return Color(red: 1, green: 0.45, blue: 0.5)
        case .app, .shortcut: return n.launches == "oldgame" ? Color(red: 1, green: 0.85, blue: 0.4) : Color(red: 0.5, green: 0.7, blue: 1)
        case .installer: return Color(red: 0.75, green: 0.6, blue: 0.4)
        default: return .white.opacity(0.75)
        }
    }

    static func typeName(_ n: VFSNode) -> String {
        switch n.kind {
        case .folder: return "File folder"
        case .text: return "Text document"
        case .app: return "Application"
        case .shortcut: return "Shortcut"
        case .encrypted: return "Encrypted file"
        case .data: return "Data file"
        case .image: return "JPEG image"
        case .installer: return "Installer"
        case .system: return "System file"
        }
    }

    static func size(_ kb: Int) -> String {
        if kb >= 1_048_576 { return String(format: "%.1f GB", Double(kb) / 1_048_576) }
        if kb >= 1024 { return String(format: "%.1f MB", Double(kb) / 1024) }
        return "\(kb) KB"
    }
}
