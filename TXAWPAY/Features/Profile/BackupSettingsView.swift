import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Backup management: destination, status, manual backup, integrity check, version history.
struct BackupSettingsView: View {
    @EnvironmentObject private var backup: BackupManager
    @EnvironmentObject private var router: AppRouter
    @Query(sort: \BackupRecord.dayKey, order: .reverse) private var records: [BackupRecord]
    @State private var pickingFolder = false
    @State private var integrity: IntegrityReport?
    @State private var integrityError: String?
    @State private var verifying = false
    @State private var historyDay: String?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    HStack {
                        Image(systemName: backup.isEnabled ? backup.overallState.symbol : "externaldrive.badge.xmark")
                            .font(.title2)
                            .foregroundStyle(Theme.accent)
                        VStack(alignment: .leading) {
                            Text(backup.isEnabled ? backup.overallState.label : "Automatic backup is off")
                                .font(Typo.headline)
                            if let last = backup.lastSuccess {
                                Text("Last successful backup \(last.formatted(date: .abbreviated, time: .shortened))")
                                    .font(Typo.caption).foregroundStyle(Theme.textSecondary)
                            } else {
                                Text("No backup has completed yet").font(Typo.caption).foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                        statRow("Entries backed up", "\(backup.stats.backedUpEntries)")
                        statRow("Pending days", "\(backup.stats.pending)")
                        statRow("Waiting for iCloud", "\(backup.stats.waitingForICloud)")
                        statRow("Failed days", "\(backup.stats.failed)")
                    }
                    .font(Typo.callout)
                    if let error = backup.stats.lastError ?? backup.lastMessage {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(Typo.caption).foregroundStyle(Theme.danger)
                    }
                    Button {
                        Task {
                            await backup.backUpEverything()
                            router.showToast(backup.stats.failed == 0 ? "Backup finished" : "Backup finished with problems",
                                             symbol: backup.stats.failed == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle",
                                             isError: backup.stats.failed > 0)
                        }
                    } label: {
                        HStack {
                            if backup.isRunning { ProgressView().tint(.white) }
                            Text(backup.isRunning ? "Backing up…" : "Back up now")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(fullWidth: true))
                    .disabled(backup.isRunning)
                    .padding(.top, 4)
                }
                .padding(.vertical, 4)
            }

            Section {
                Toggle("Automatic backup", isOn: Binding(get: { backup.isEnabled }, set: { newValue in
                    backup.isEnabled = newValue
                    backup.objectWillChange.send()
                    if newValue { Task { await backup.backUpEverything() } }
                }))
            } footer: {
                Text("When on, every journal entry is saved to a Markdown file within seconds of each change, when you finish editing, and when TXAWPAY goes to the background.")
            }

            Section("Destination") {
                ForEach(BackupDestinationKind.allCases) { kind in
                    Button {
                        if kind == .folder { pickingFolder = true }
                        else { Task { await backup.changeDestination(to: kind) } }
                    } label: {
                        HStack(alignment: .top) {
                            Image(systemName: kind.symbol).frame(width: 28).foregroundStyle(Theme.accent)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(kind == .folder && !backup.folderName.isEmpty ? "Folder: \(backup.folderName)" : kind.label)
                                    .foregroundStyle(Theme.textPrimary)
                                Text(kind.explanation)
                                    .font(Typo.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            if backup.destination == kind {
                                Image(systemName: "checkmark").foregroundStyle(Theme.accent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                if !backup.resolvedPath.isEmpty {
                    Label(backup.resolvedPath, systemImage: "folder")
                        .font(Typo.caption).foregroundStyle(Theme.textSecondary)
                }
            }

            if backup.destination == .onDevice {
                Section {
                    Label {
                        Text("Files stored only inside TXAWPAY are deleted if the app is deleted. Choose iCloud Drive or a folder in Files to keep your journal safe.")
                    } icon: {
                        Image(systemName: "exclamationmark.shield").foregroundStyle(Theme.gold)
                    }
                    .font(Typo.callout)
                }
            }

            Section {
                Toggle("Also save plain-text (.txt) copies", isOn: Binding(get: { backup.alsoTXT }, set: { backup.alsoTXT = $0; backup.objectWillChange.send() }))
                Toggle("Include photos and videos", isOn: Binding(get: { backup.includeMedia }, set: { backup.includeMedia = $0; backup.objectWillChange.send() }))
            } header: {
                Text("Format")
            } footer: {
                Text("Markdown is always written. Media is copied once into Journal Backups/Media.")
            }

            Section("Integrity") {
                Button {
                    Task {
                        verifying = true
                        switch await backup.verifyIntegrity() {
                        case .success(let report): integrity = report; integrityError = nil
                        case .failure(let error): integrityError = error.localizedDescription
                        }
                        verifying = false
                    }
                } label: {
                    HStack {
                        Label("Verify backup files", systemImage: "checkmark.shield")
                        Spacer()
                        if verifying { ProgressView() }
                    }
                }
                if let integrity {
                    if integrity.manifestMissing {
                        Label("No manifest found at this destination yet. Run a backup first.", systemImage: "questionmark.folder")
                            .font(Typo.caption)
                    } else if integrity.isHealthy {
                        Label("All \(integrity.checked) day files match the manifest.", systemImage: "checkmark.seal.fill")
                            .font(Typo.caption).foregroundStyle(Theme.jungle)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(integrity.ok) of \(integrity.checked) files are intact.")
                            if !integrity.missing.isEmpty { Text("Missing: \(integrity.missing.joined(separator: ", "))") }
                            if !integrity.mismatched.isEmpty { Text("Changed outside TXAWPAY: \(integrity.mismatched.joined(separator: ", "))") }
                            Button("Repair by backing up again") { Task { await backup.backUpEverything() } }
                        }
                        .font(Typo.caption)
                        .foregroundStyle(Theme.danger)
                    }
                }
                if let integrityError {
                    Text(integrityError).font(Typo.caption).foregroundStyle(Theme.danger)
                }
            }

            Section {
                NavigationLink(value: AppModule.restore) { Label("Restore Journal", systemImage: "arrow.counterclockwise") }
                NavigationLink(value: AppModule.exportData) { Label("Export journal as ZIP", systemImage: "archivebox") }
            }

            Section {
                if records.isEmpty {
                    Text("No days backed up yet.").foregroundStyle(Theme.textSecondary)
                }
                ForEach(records.prefix(60)) { r in
                    Button { historyDay = r.dayKey } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.dayKey).font(.system(.body, design: .monospaced)).foregroundStyle(Theme.textPrimary)
                                Text(r.lastError.isEmpty ? "\(r.entryCount) entries" : r.lastError)
                                    .font(Typo.caption)
                                    .foregroundStyle(r.lastError.isEmpty ? Theme.textSecondary : Theme.danger)
                                    .lineLimit(2)
                            }
                            Spacer()
                            Label(r.state.label, systemImage: r.state.symbol)
                                .labelStyle(.iconOnly)
                                .foregroundStyle(r.state == .failed ? Theme.danger : Theme.accent)
                                .accessibilityLabel(r.state.label)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Days")
            } footer: {
                Text("Tap a day to see its saved versions.")
            }

            Section("Privacy") {
                Text("Backup files are ordinary Markdown files. They are not protected by TXAWPAY's Face ID lock, and anyone with access to the folder can read them. For stronger protection, use the encrypted export in Export & Delete Data.")
                    .font(Typo.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .screenBackground()
        .navigationTitle("Journal Backup")
        .fileImporter(isPresented: $pickingFolder, allowedContentTypes: [.folder]) { result in
            switch result {
            case .success(let url):
                do {
                    try backup.setFolder(url)
                    Task { await backup.changeDestination(to: .folder) }
                } catch {
                    router.showToast(error.localizedDescription, symbol: "exclamationmark.triangle", isError: true)
                }
            case .failure(let error):
                router.showToast(error.localizedDescription, symbol: "exclamationmark.triangle", isError: true)
            }
        }
        .sheet(item: Binding(get: { historyDay.map { DayBox(key: $0) } }, set: { historyDay = $0?.key })) { box in
            VersionHistoryView(dayKey: box.key)
        }
        .task { backup.refreshStats(); await backup.checkUploads() }
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(Theme.textSecondary)
            Text(value).fontWeight(.semibold)
        }
    }
}

struct DayBox: Identifiable { let key: String; var id: String { key } }

/// Lists saved versions of one day's file and lets the user read or share them.
struct VersionHistoryView: View {
    let dayKey: String
    @EnvironmentObject private var backup: BackupManager
    @Environment(\.dismiss) private var dismiss
    @State private var versions: [URL] = []
    @State private var loaded = false
    @State private var preview: String?

    var body: some View {
        NavigationStack {
            List {
                if loaded && versions.isEmpty {
                    Text("No earlier versions of this day are stored. Versions are kept when a file is changed outside TXAWPAY, when entries are removed, and periodically while you edit.")
                        .foregroundStyle(Theme.textSecondary)
                }
                ForEach(versions, id: \.self) { url in
                    Button {
                        Task { preview = await backup.readVersion(url) }
                    } label: {
                        Label(url.deletingPathExtension().lastPathComponent, systemImage: "doc.text")
                    }
                }
            }
            .navigationTitle(dayKey)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .task {
                versions = await backup.versions(for: dayKey)
                loaded = true
            }
            .sheet(item: Binding(get: { preview.map { TextBox(text: $0) } }, set: { preview = $0?.text })) { box in
                NavigationStack {
                    ScrollView {
                        Text(box.text).font(.system(.footnote, design: .monospaced)).textSelection(.enabled).padding()
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            ShareLink(item: box.text)
                        }
                    }
                }
            }
        }
    }
}

struct TextBox: Identifiable { let text: String; var id: Int { text.hashValue } }
