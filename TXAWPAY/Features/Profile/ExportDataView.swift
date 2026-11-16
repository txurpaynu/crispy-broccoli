import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Export the journal (ZIP / encrypted), export everything, restore everything, delete everything.
struct ExportDataView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var backup: BackupManager

    @State private var includeMedia = true
    @State private var encrypt = false
    @State private var password = ""
    @State private var passwordConfirm = ""
    @State private var working = false
    @State private var exportedURL: URL?
    @State private var error: String?

    @State private var importing = false
    @State private var importURL: URL?
    @State private var importPassword = ""
    @State private var askImportPassword = false

    @State private var confirmDelete = false
    @State private var deleteText = ""
    @State private var deleteLocalBackups = false

    private var passwordProblem: String? {
        guard encrypt else { return nil }
        if password.count < 8 { return "Use at least 8 characters." }
        if password != passwordConfirm { return "Passwords don't match." }
        return nil
    }

    var body: some View {
        List {
            Section {
                Toggle("Include photos and videos", isOn: $includeMedia)
                Toggle("Protect with a password", isOn: $encrypt)
                if encrypt {
                    SecureField("Password (8+ characters)", text: $password)
                    SecureField("Confirm password", text: $passwordConfirm)
                    ValidationHint(message: password.isEmpty ? nil : passwordProblem)
                    Text("Encrypted with AES-256. If you forget this password, the export cannot be opened by anyone, including TXAWPAY.")
                        .font(Typo.caption).foregroundStyle(Theme.textSecondary)
                }
            } header: {
                Text("Options")
            }

            Section {
                Button { exportJournal() } label: {
                    NavRow(symbol: "book.closed", title: "Export journal",
                           subtitle: "Markdown day files, metadata and media in a ZIP")
                }
                Button { exportEverything() } label: {
                    NavRow(symbol: "shippingbox", title: "Export everything",
                           subtitle: "All sections as JSON, plus the journal as Markdown and all media", tint: Theme.gold)
                }
                if working { HStack { ProgressView(); Text("Preparing export…") } }
                if let exportedURL {
                    ShareLink(item: exportedURL) {
                        Label("Save or share \(exportedURL.lastPathComponent)", systemImage: "square.and.arrow.up")
                    }
                }
                if let error { Text(error).foregroundStyle(Theme.danger).font(Typo.caption) }
            } header: {
                Text("Export")
            } footer: {
                Text("Use “Save to Files” in the share sheet to keep the export somewhere safe, such as iCloud Drive.")
            }
            .disabled(working || passwordProblem != nil)
            .buttonStyle(.plain)

            Section {
                Button { importing = true } label: {
                    NavRow(symbol: "arrow.down.doc", title: "Restore from a full export",
                           subtitle: "Adds everything missing from a TXAWPAY Export ZIP. Existing items are kept.")
                }
                .buttonStyle(.plain)
                NavigationLink(value: AppModule.restore) {
                    NavRow(symbol: "arrow.counterclockwise", title: "Restore journal only", subtitle: "From backup folders, Markdown files or a journal ZIP")
                }
            } header: {
                Text("Restore")
            }

            Section {
                Button("Delete all TXAWPAY data…", role: .destructive) { confirmDelete = true }
            } header: {
                Text("Delete")
            } footer: {
                Text("Removes all content from this iPhone. Backup folders in iCloud Drive or Files are not touched, so you can restore from them later.")
            }
        }
        .screenBackground()
        .navigationTitle("Export & Delete")
        .fileImporter(isPresented: $importing, allowedContentTypes: [.zip, .txawpayEncryptedBackup, .data]) { result in
            if case .success(let url) = result {
                importURL = url
                if EncryptedArchive.isEncrypted(url) || url.pathExtension == EncryptedArchive.fileExtension {
                    askImportPassword = true
                } else {
                    runImport(url, password: nil)
                }
            }
        }
        .alert("Encrypted export", isPresented: $askImportPassword) {
            SecureField("Password", text: $importPassword)
            Button("Cancel", role: .cancel) {}
            Button("Restore") { if let importURL { runImport(importURL, password: importPassword) } }
        }
        .sheet(isPresented: $confirmDelete) { deleteSheet }
    }

    private var deleteSheet: some View {
        NavigationStack {
            Form {
                Section {
                    Text("This permanently deletes every journal entry, memory, trip, project, goal, person, workout and setting stored on this iPhone.")
                    Toggle("Also delete the on-device backup folder", isOn: $deleteLocalBackups)
                } footer: {
                    Text("Export first if you are unsure. iCloud Drive and Files backup folders are kept.")
                }
                Section("Type DELETE to confirm") {
                    TextField("DELETE", text: $deleteText)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }
                Section {
                    Button("Delete everything", role: .destructive) {
                        do {
                            try DataExportService.deleteEverything(context: context, includeLocalBackups: deleteLocalBackups)
                            backup.refreshStats()
                            confirmDelete = false
                            deleteText = ""
                            router.showToast("All data deleted", symbol: "trash")
                        } catch {
                            self.error = error.localizedDescription
                        }
                    }
                    .disabled(deleteText != "DELETE")
                }
            }
            .navigationTitle("Delete all data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { confirmDelete = false } } }
        }
    }

    private func exportJournal() {
        working = true; error = nil; exportedURL = nil
        let payload = JournalExporter.snapshot(context: context)
        let pw = encrypt ? password : nil
        Task {
            do {
                exportedURL = try await JournalExporter.makeArchive(payload: payload, includeMedia: includeMedia, password: pw)
                router.showToast("Journal export ready")
            } catch {
                self.error = error.localizedDescription
            }
            working = false
        }
    }

    private func exportEverything() {
        working = true; error = nil; exportedURL = nil
        var bundle = DataExportService.makeBundle(context: context)
        if !includeMedia {
            bundle.entries = bundle.entries.map { var e = $0; e.media = []; return e }
        }
        let pw = encrypt ? password : nil
        Task {
            do {
                exportedURL = try await DataExportService.makeArchive(bundle: bundle, password: pw)
                router.showToast("Export ready")
            } catch {
                self.error = error.localizedDescription
            }
            working = false
        }
    }

    private func runImport(_ url: URL, password: String?) {
        working = true; error = nil
        Task {
            do {
                let (bundle, media) = try await DataExportService.readArchive(url, password: password)
                let summary = DataExportService.importBundle(bundle, mediaFolder: media, context: context)
                backup.flushNow()
                await NotificationService.shared.refreshAll(context: context)
                router.showToast("Restored \(summary.created) items · \(summary.skipped) already present")
            } catch {
                self.error = error.localizedDescription
            }
            importPassword = ""
            working = false
        }
    }
}
