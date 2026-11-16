import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Restore Journal: pick → preview → import (no duplicates).
struct RestoreJournalView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var backup: BackupManager
    @EnvironmentObject private var router: AppRouter

    @State private var pickFolder = false
    @State private var pickFiles = false
    @State private var importerShown = false
    @State private var importerTypes: [UTType] = [.folder]
    @State private var importerMultiple = false
    @State private var scanning = false
    @State private var plan: JournalRestorer.Plan?
    @State private var selected: Set<UUID> = []
    @State private var error: String?
    @State private var pendingURLs: [URL] = []
    @State private var needsPassword = false
    @State private var password = ""
    @State private var summary: JournalRestorer.Summary?

    var body: some View {
        List {
            if let plan {
                previewSections(plan)
            } else {
                Section {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        Text("Bring your journal back from a TXAWPAY backup folder, Markdown files, or an exported ZIP. Nothing is imported until you confirm, and entries you already have are skipped.")
                            .font(Typo.callout)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Section {
                    Button { pickFolder = true } label: {
                        NavRow(symbol: "folder", title: "Choose a backup folder",
                               subtitle: "Your TXAWPAY folder or its Journal Backups folder, in iCloud Drive or Files")
                    }
                    Button { pickFiles = true } label: {
                        NavRow(symbol: "doc.zipper", title: "Choose files",
                               subtitle: "Markdown (.md), text (.txt), a TXAWPAY ZIP export or an encrypted backup", tint: Theme.gold)
                    }
                }
                .buttonStyle(.plain)
                if scanning {
                    Section { HStack { ProgressView(); Text("Reading backup…") } }
                }
                if let error {
                    Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(Theme.danger) }
                }
                if let summary {
                    Section("Last restore") {
                        Text("Imported \(summary.imported), updated \(summary.updated), skipped \(summary.skipped).")
                        if summary.mediaRestored + summary.mediaMissing > 0 {
                            Text("Media restored: \(summary.mediaRestored)\(summary.mediaMissing > 0 ? ", not found: \(summary.mediaMissing)" : "")")
                        }
                    }
                }
            }
        }
        .screenBackground()
        .navigationTitle("Restore Journal")
        .toolbar {
            if plan != nil {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { cancelPlan() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Import \(selectedImportable)") { apply() }
                        .disabled(selectedImportable == 0)
                        .fontWeight(.semibold)
                }
            }
        }
        // One importer only: SwiftUI ignores all but one .fileImporter per view.
        .fileImporter(isPresented: $importerShown, allowedContentTypes: importerTypes,
                      allowsMultipleSelection: importerMultiple) { result in
            handle(result)
        }
        .onChange(of: pickFolder) { _, on in
            guard on else { return }
            pickFolder = false
            importerTypes = [.folder]; importerMultiple = false; importerShown = true
        }
        .onChange(of: pickFiles) { _, on in
            guard on else { return }
            pickFiles = false
            importerTypes = [.markdownText, .plainText, .zip, .txawpayEncryptedBackup, .data]
            importerMultiple = true; importerShown = true
        }
        .alert("Encrypted backup", isPresented: $needsPassword) {
            SecureField("Password", text: $password)
            Button("Cancel", role: .cancel) { password = "" }
            Button("Unlock") { scan(pendingURLs) }
        } message: {
            Text("Enter the password used when this backup was exported.")
        }
    }

    private var selectedImportable: Int {
        plan?.items.filter { selected.contains($0.id) && $0.status != .duplicate }.count ?? 0
    }

    @ViewBuilder
    private func previewSections(_ plan: JournalRestorer.Plan) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("Found \(plan.items.count) entries in \(plan.filesScanned) files").font(Typo.headline)
                Text("\(plan.newCount) new · \(plan.newerCount) newer than yours · \(plan.duplicateCount) already in your journal")
                    .font(Typo.caption).foregroundStyle(Theme.textSecondary)
                if !plan.unreadableFiles.isEmpty {
                    Text("Couldn't read: \(plan.unreadableFiles.joined(separator: ", "))")
                        .font(Typo.caption).foregroundStyle(Theme.danger)
                }
            }
            HStack {
                Button("Select all") { selected = Set(plan.items.filter { $0.status != .duplicate }.map(\.id)) }
                Spacer()
                Button("Select none") { selected = [] }
            }
            .buttonStyle(.borderless)
        }
        Section("Preview") {
            ForEach(plan.items) { item in
                Button {
                    guard item.status != .duplicate else { return }
                    if selected.contains(item.id) { selected.remove(item.id) } else { selected.insert(item.id) }
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: item.status == .duplicate ? "minus.circle" :
                                (selected.contains(item.id) ? "checkmark.circle.fill" : "circle"))
                            .foregroundStyle(item.status == .duplicate ? Theme.textTertiary : Theme.accent)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.entry.title.isEmpty ? "Untitled entry" : item.entry.title)
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                            Text(item.entry.date.formatted(date: .abbreviated, time: .shortened))
                                .font(Typo.caption).foregroundStyle(Theme.textSecondary)
                            Text(item.entry.body.prefix(120))
                                .font(Typo.caption).foregroundStyle(Theme.textTertiary).lineLimit(2)
                            Label(item.status.rawValue, systemImage: item.status.symbol)
                                .font(Typo.caption2Safe)
                                .foregroundStyle(item.status == .newer ? Theme.gold : Theme.textTertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func handle(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            pendingURLs = urls
            password = ""
            scan(urls)
        case .failure(let e):
            error = e.localizedDescription
        }
    }

    private func scan(_ urls: [URL]) {
        error = nil
        scanning = true
        let (index, prints) = JournalRestorer.existingIndex(context: context)
        let pw = password
        Task {
            do {
                let result = try await JournalRestorer.scan(urls: urls, password: pw.isEmpty ? nil : pw,
                                                            existing: index, existingFingerprints: prints)
                plan = result
                selected = Set(result.items.filter { $0.status != .duplicate }.map(\.id))
            } catch JournalRestorer.RestoreError.needsPassword {
                needsPassword = true
            } catch {
                self.error = error.localizedDescription
            }
            scanning = false
        }
    }

    private func apply() {
        guard let plan else { return }
        let result = JournalRestorer.apply(plan: plan, selected: selected, context: context, backup: backup)
        summary = result
        self.plan = nil
        password = ""
        backup.flushNow()
        router.showToast("Restored \(result.imported + result.updated) entries")
    }

    private func cancelPlan() {
        if let temp = plan?.tempFolder { try? FileManager.default.removeItem(at: temp) }
        plan = nil
    }
}

extension Typo {
    static let caption2Safe = Font.system(.caption2).weight(.medium)
}
