import SwiftUI

/// File explorer over the fictional filesystem: browse, open, delete, properties.
struct FilesApp: View {
    @EnvironmentObject var comp: ComputerSimulationManager
    @EnvironmentObject var session: GameSession
    let windowID: UUID
    let startPath: String
    @State private var path: String = ""
    @State private var history: [String] = []
    @State private var selected: String?

    private struct Place: Hashable { let name: String; let icon: String; let path: String }
    private let places: [Place] = [
        Place(name: "Desktop", icon: "menubar.dock.rectangle", path: "C:/Users/sam/Desktop"),
        Place(name: "Documents", icon: "doc.fill", path: "C:/Users/sam/Documents"),
        Place(name: "Downloads", icon: "arrow.down.circle.fill", path: "C:/Users/sam/Downloads"),
        Place(name: "Pictures", icon: "photo.fill", path: "C:/Users/sam/Pictures"),
        Place(name: "Local Disk (C:)", icon: "internaldrive.fill", path: "C:"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().background(.white.opacity(0.1))
            HStack(spacing: 0) {
                sidebar
                Divider().background(.white.opacity(0.1))
                list
            }
        }
        .onAppear { if path.isEmpty { path = startPath } }
    }

    private var toolbar: some View {
        HStack(spacing: 6) {
            tbButton("chevron.left", enabled: !history.isEmpty) {
                if let p = history.popLast() { path = p; selected = nil }
            }
            tbButton("arrow.up", enabled: path.contains("/")) { go(VirtualFilesystem.parent(of: path)) }
            Text(path.replacingOccurrences(of: "/", with: " › "))
                .font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.8))
                .lineLimit(1).truncationMode(.head)
                .padding(.horizontal, 8).frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                .background(.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 4))
            tbButton("arrow.up.forward.app", enabled: selected != nil) { if let s = selected { comp.openFile(s) } }
            tbButton("trash", enabled: selected != nil) {
                if let s = selected { comp.delete(s); if comp.fs.node(at: s) == nil { selected = nil } }
            }
            tbButton("info.circle", enabled: true) { comp.showProperties(selected ?? path) }
        }
        .padding(6)
    }

    private func tbButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 12)).frame(width: 28, height: 24)
                .foregroundStyle(.white.opacity(enabled ? 0.9 : 0.3))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(places, id: \.self) { p in
                    Button { go(p.path) } label: {
                        Label(p.name, systemImage: p.icon)
                            .font(.system(size: 11)).foregroundStyle(.white.opacity(path == p.path ? 1 : 0.7))
                            .padding(.vertical, 5).padding(.horizontal, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(path == p.path ? Color.white.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
        }
        .frame(width: 130)
    }

    private var list: some View {
        let node = comp.fs.node(at: path)
        let kids = (node?.children ?? []).sorted { a, b in
            a.isFolder != b.isFolder ? a.isFolder : a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        return VStack(spacing: 0) {
            HStack {
                Text("Name").frame(maxWidth: .infinity, alignment: .leading)
                Text("Modified").frame(width: 110, alignment: .leading)
                Text("Size").frame(width: 60, alignment: .trailing)
            }
            .font(.system(size: 9, weight: .semibold)).foregroundStyle(.white.opacity(0.45))
            .padding(.horizontal, 10).padding(.vertical, 4)
            ScrollView {
                VStack(spacing: 1) {
                    if node == nil {
                        Text("This folder no longer exists.").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5)).padding(20)
                    } else if kids.isEmpty {
                        Text("This folder is empty.").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5)).padding(20)
                    }
                    ForEach(kids) { k in
                        let full = VirtualFilesystem.join(path, k.name)
                        Button {
                            if selected == full {
                                if k.isFolder { go(full) } else { comp.openFile(full) }
                            } else {
                                selected = full
                                AudioManager.shared.play(.mouseClick)
                                if full == ComputerSimulationManager.oldPath { session.set("saw_old_file") }
                            }
                        } label: {
                            HStack {
                                Image(systemName: FileIcon.symbol(k)).foregroundStyle(FileIcon.tint(k)).frame(width: 18)
                                Text(k.name).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                                Text(k.modified).lineLimit(1).frame(width: 110, alignment: .leading).foregroundStyle(.white.opacity(0.5))
                                Text(k.isFolder ? "" : FileIcon.size(k.sizeKB)).frame(width: 60, alignment: .trailing).foregroundStyle(.white.opacity(0.5))
                            }
                            .font(.system(size: 11))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(selected == full ? Color(red: 0.25, green: 0.45, blue: 0.9).opacity(0.45) : .clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Text(selected == nil ? "\(kids.count) items · tap to select, tap again to open" : "1 item selected · tap again to open")
                .font(.system(size: 9)).foregroundStyle(.white.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 10).padding(.vertical, 3)
        }
    }

    private func go(_ p: String) {
        guard p != path, comp.fs.node(at: p)?.isFolder == true else { return }
        if p.hasPrefix("C:/Pane") {
            comp.alert("Access denied", "You don't currently have permission to access this folder.", icon: "lock.fill", tint: .red)
            return
        }
        history.append(path)
        path = p
        selected = nil
        AudioManager.shared.play(.mouseClick)
        if p == ComputerSimulationManager.remasterPath + "/data/legacy" { session.set("opened_legacy_folder") }
    }
}

struct NotepadApp: View {
    @EnvironmentObject var comp: ComputerSimulationManager
    let path: String
    var body: some View {
        ScrollView {
            Text(comp.fs.node(at: path)?.content ?? "(file not found)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .textSelection(.enabled)
        }
        .background(Color(white: 0.96))
    }
}

struct RecycleBinApp: View {
    @EnvironmentObject var comp: ComputerSimulationManager
    @EnvironmentObject var session: GameSession
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("\(session.data.desktop.recycled.count) items").font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
                Spacer()
                Button("Empty Recycle Bin") { comp.emptyRecycleBin() }
                    .font(.system(size: 11)).disabled(session.data.desktop.recycled.isEmpty)
            }
            .padding(8)
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(session.data.desktop.recycled) { item in
                        HStack {
                            Image(systemName: FileIcon.symbol(item.node)).foregroundStyle(FileIcon.tint(item.node))
                            VStack(alignment: .leading) {
                                Text(item.node.name).font(.system(size: 11)).foregroundStyle(.white)
                                Text(VirtualFilesystem.parent(of: item.originalPath)).font(.system(size: 9)).foregroundStyle(.white.opacity(0.4))
                            }
                            Spacer()
                            Button("Restore") { comp.restore(item) }.font(.system(size: 11))
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                    }
                }
            }
        }
    }
}

struct SettingsApp: View {
    @EnvironmentObject var session: GameSession
    @EnvironmentObject var settings: GameSettings
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Personalization").font(.system(size: 13, weight: .semibold))
                HStack(spacing: 10) {
                    ForEach(0..<3) { i in
                        Wallpaper(index: i)
                            .frame(width: 90, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(session.data.desktop.wallpaper == i ? Color.blue : .white.opacity(0.2), lineWidth: 2))
                            .onTapGesture { session.data.desktop.wallpaper = i; AudioManager.shared.play(.uiClick) }
                    }
                }
                Text("Sound").font(.system(size: 13, weight: .semibold))
                Slider(value: $settings.masterVolume, in: 0...1).frame(maxWidth: 260)
                Text("About").font(.system(size: 13, weight: .semibold))
                Text("Pane 11 Home · build 26100.2\nDevice: SAM-DESKTOP · 32 GB RAM\nShield Security: active")
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(.white.opacity(0.6))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(.white)
        }
    }
}
