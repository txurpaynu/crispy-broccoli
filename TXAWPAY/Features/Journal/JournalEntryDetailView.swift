import SwiftUI
import SwiftData

struct EditEntryRoute: Hashable {
    let entry: JournalEntry
}

/// Read view for a single entry.
struct JournalEntryDetailView: View {
    @Bindable var entry: JournalEntry
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: AppRouter
    @State private var showDeleteConfirm = false
    @State private var exportURL: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.date.formatted(date: .complete, time: .shortened))
                        .font(Typo.eyebrow)
                        .foregroundStyle(Theme.gold)
                        .textCase(.uppercase)
                    Text(entry.displayTitle)
                        .font(Typo.largeTitle)
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    FlowLayout {
                        if let mood = entry.mood { Chip(text: mood.label, symbol: mood.symbol, color: mood.tint) }
                        if let cat = entry.category { Chip(text: cat.name, symbol: cat.symbol, color: Color(hexString: cat.colorHex)) }
                        if !entry.locationName.isEmpty { Chip(text: entry.locationName, symbol: "mappin", color: Theme.earth) }
                        if entry.isImportant { Chip(text: "Important", symbol: "sparkle", color: Theme.gold) }
                    }
                }

                GoldDivider()

                if !entry.sortedAttachments.isEmpty {
                    AttachmentGrid(attachments: entry.sortedAttachments)
                }

                if !entry.body.isEmpty {
                    Text(Self.markdown(entry.body))
                        .font(Typo.bodySerif)
                        .foregroundStyle(Theme.textPrimary)
                        .lineSpacing(5)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !entry.reflection.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Reflection", systemImage: "leaf")
                            .font(Typo.eyebrow)
                            .foregroundStyle(Theme.jungle)
                        Text(entry.reflection)
                            .font(Typo.bodySerif.italic())
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .cardStyle()
                }

                if !entry.tags.isEmpty { TagList(tags: entry.tags) }

                links

                VStack(alignment: .leading, spacing: 4) {
                    Text("Created \(entry.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    Text("Last modified \(entry.modifiedAt.formatted(date: .abbreviated, time: .shortened))")
                    Text("\(entry.wordCount) words")
                    EntryBackupLine(dayKey: DayKey.key(for: entry.date))
                }
                .font(Typo.caption)
                .foregroundStyle(Theme.textTertiary)
            }
            .padding()
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    entry.isFavorite.toggle()
                    try? JournalStore.save(entry, previousDayKey: nil, in: context, touch: false)
                } label: {
                    Image(systemName: entry.isFavorite ? "star.fill" : "star")
                }
                .accessibilityLabel(entry.isFavorite ? "Remove from favorites" : "Add to favorites")

                Menu {
                    NavigationLink(value: EditEntryRoute(entry: entry)) { Label("Edit", systemImage: "pencil") }
                    if let exportURL {
                        ShareLink(item: exportURL) { Label("Share as Markdown", systemImage: "square.and.arrow.up") }
                    }
                    Button(role: .destructive) { showDeleteConfirm = true } label: { Label("Delete", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Entry actions")
            }
        }
        .safeAreaInset(edge: .bottom) {
            NavigationLink(value: EditEntryRoute(entry: entry)) {
                Label("Edit entry", systemImage: "pencil")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.bottom, 8)
        }
        .confirmationDialog("Delete this entry?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete entry", role: .destructive) {
                do {
                    try JournalStore.delete(entry, in: context)
                    router.showToast("Entry deleted", symbol: "trash")
                    dismiss()
                } catch {
                    router.showToast(error.localizedDescription, symbol: "exclamationmark.triangle", isError: true)
                }
            }
        } message: {
            Text("A copy of the day's backup file is kept in Version History.")
        }
        .onAppear {
            RecentsStore.shared.record(.journal, id: entry.id, title: entry.displayTitle)
            exportURL = makeExport()
        }
    }

    @ViewBuilder
    private var links: some View {
        let people = entry.people ?? []
        if entry.trip != nil || entry.project != nil || !people.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("Connected").font(Typo.eyebrow).foregroundStyle(Theme.textSecondary)
                if let trip = entry.trip {
                    NavigationLink(value: trip) { NavRow(symbol: "airplane", title: trip.title, subtitle: "Trip") }
                }
                if let project = entry.project {
                    NavigationLink(value: project) { NavRow(symbol: "paintbrush.pointed", title: project.name, subtitle: "Project", tint: Theme.gold) }
                }
                ForEach(people) { p in
                    NavigationLink(value: p) { NavRow(symbol: "person", title: p.name, subtitle: p.relationship, tint: Theme.earth) }
                }
            }
            .buttonStyle(.plain)
            .cardStyle()
        }
    }

    private func makeExport() -> URL? {
        let snapshot = JournalEntrySnapshot(entry)
        let text = JournalMarkdownCodec.renderDay(key: snapshot.dayKey, entries: [snapshot], mediaLinkPrefix: nil)
        let safe = entry.displayTitle.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined(separator: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(snapshot.dayKey) \(safe.prefix(40)).md")
        return (try? Data(text.utf8).write(to: url, options: .atomic)).map { url }
    }

    /// Renders inline Markdown (bold, italics, links) while preserving line breaks.
    static func markdown(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }
}

/// Shows the backup state of the entry's day file.
struct EntryBackupLine: View {
    let dayKey: String
    @Query private var records: [BackupRecord]

    init(dayKey: String) {
        self.dayKey = dayKey
        _records = Query(filter: #Predicate<BackupRecord> { $0.dayKey == dayKey })
    }

    var body: some View {
        if let r = records.first {
            Label(r.state.label, systemImage: r.state.symbol)
        } else {
            Label("Not backed up yet", systemImage: "clock")
        }
    }
}
