import SwiftUI
import SwiftData

/// Journal tab: timeline, calendar and monthly overview with search and filters.
struct JournalView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case timeline = "Timeline", calendar = "Calendar", months = "Months"
        var id: String { rawValue }
    }

    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]
    @Query(sort: \JournalCategory.sortOrder) private var categories: [JournalCategory]
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var backup: BackupManager

    @State private var mode: Mode = .timeline
    @State private var searchText = ""
    @State private var filter = JournalFilter()
    @State private var showFilters = false

    private var filtered: [JournalEntry] {
        filter.apply(to: entries, search: searchText)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                BackupStatusPill()
                    .padding(.horizontal)

                Picker("View", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                categoryChips

                if entries.isEmpty {
                    EmptyStateView(symbol: "book.closed",
                                   title: "Your journal starts here",
                                   message: "Write about your day, a place, a feeling or an idea. Every entry is saved on your iPhone and backed up as a Markdown file.",
                                   actionTitle: "Write first entry") { router.newJournalEntry = true }
                } else {
                    switch mode {
                    case .timeline:
                        if filtered.isEmpty {
                            EmptyStateView(symbol: "magnifyingglass", title: "No matching entries",
                                           message: "Try another word, tag or filter.")
                        } else {
                            JournalTimelineList(entries: filtered)
                        }
                    case .calendar:
                        JournalCalendarView(entries: filtered)
                    case .months:
                        JournalMonthlyOverview(entries: filtered)
                    }
                }
            }
            .padding(.vertical)
        }
        .screenBackground()
        .navigationTitle("Journal")
        .searchable(text: $searchText, prompt: "Search words, #tags, places")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    NavigationLink(value: AppModule.onThisDay) { Label("On This Day", systemImage: "clock.arrow.circlepath") }
                    NavigationLink(value: AppModule.journalCategories) { Label("Categories", systemImage: "folder") }
                    Divider()
                    NavigationLink(value: AppModule.backup) { Label("Backup", systemImage: "externaldrive.badge.icloud") }
                    NavigationLink(value: AppModule.restore) { Label("Restore Journal", systemImage: "arrow.counterclockwise") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Journal menu")
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { showFilters = true } label: {
                    Image(systemName: filter.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel("Filters")
                Button { router.newJournalEntry = true } label: {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel("New entry")
            }
        }
        .sheet(isPresented: $showFilters) {
            JournalFilterSheet(filter: $filter, categories: categories, allTags: allTags)
                .presentationDetents([.medium, .large])
        }
    }

    private var allTags: [String] {
        Array(Set(entries.flatMap(\.tags))).sorted()
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button { filter.categoryID = nil } label: {
                    Chip(text: "All", isSelected: filter.categoryID == nil)
                }
                ForEach(categories) { cat in
                    Button { filter.categoryID = filter.categoryID == cat.id ? nil : cat.id } label: {
                        Chip(text: cat.name, symbol: cat.symbol, color: Color(hexString: cat.colorHex),
                             isSelected: filter.categoryID == cat.id)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
        }
    }
}

/// Search and filter state shared by the journal views.
struct JournalFilter: Equatable {
    var categoryID: UUID?
    var mood: Mood?
    var tag: String?
    var favoritesOnly = false
    var withPhotosOnly = false
    var useDateRange = false
    var from = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    var to = Date()

    var isActive: Bool {
        mood != nil || tag != nil || favoritesOnly || withPhotosOnly || useDateRange
    }

    func apply(to entries: [JournalEntry], search: String) -> [JournalEntry] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        let start = Calendar.current.startOfDay(for: from)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: to)) ?? to
        return entries.filter { e in
            if let categoryID, e.category?.id != categoryID { return false }
            if let mood, e.mood != mood { return false }
            if let tag, !e.tags.contains(tag) { return false }
            if favoritesOnly && !e.isFavorite { return false }
            if withPhotosOnly && e.photoAttachments.isEmpty { return false }
            if useDateRange && (e.date < start || e.date >= end) { return false }
            if !query.isEmpty {
                if query.hasPrefix("#") {
                    let t = String(query.dropFirst())
                    return e.tags.contains { $0.hasPrefix(t) }
                }
                return e.title.lowercased().contains(query)
                    || e.body.lowercased().contains(query)
                    || e.reflection.lowercased().contains(query)
                    || e.locationName.lowercased().contains(query)
                    || e.tags.contains { $0.contains(query) }
                    || (e.category?.name.lowercased().contains(query) ?? false)
                    || e.date.formatted(date: .long, time: .omitted).lowercased().contains(query)
            }
            return true
        }
    }
}

struct JournalFilterSheet: View {
    @Binding var filter: JournalFilter
    let categories: [JournalCategory]
    let allTags: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Mood") {
                    Picker("Mood", selection: $filter.mood) {
                        Text("Any").tag(Mood?.none)
                        ForEach(Mood.allCases) { Label($0.label, systemImage: $0.symbol).tag(Mood?.some($0)) }
                    }
                }
                if !allTags.isEmpty {
                    Section("Tag") {
                        Picker("Tag", selection: $filter.tag) {
                            Text("Any").tag(String?.none)
                            ForEach(allTags, id: \.self) { Text("#\($0)").tag(String?.some($0)) }
                        }
                    }
                }
                Section {
                    Toggle("Favorites only", isOn: $filter.favoritesOnly)
                    Toggle("With photos only", isOn: $filter.withPhotosOnly)
                }
                Section("Dates") {
                    Toggle("Limit to a date range", isOn: $filter.useDateRange)
                    if filter.useDateRange {
                        DatePicker("From", selection: $filter.from, displayedComponents: .date)
                        DatePicker("To", selection: $filter.to, in: filter.from..., displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") { filter = JournalFilter(categoryID: filter.categoryID) }
                        .disabled(!filter.isActive)
                }
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }
}

// MARK: - Timeline

struct JournalTimelineList: View {
    let entries: [JournalEntry]

    private var groups: [(day: Date, entries: [JournalEntry])] {
        let grouped = Dictionary(grouping: entries) { Calendar.current.startOfDay(for: $0.date) }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0]!.sorted { $0.date > $1.date }) }
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: Theme.Spacing.l, pinnedViews: []) {
            ForEach(groups, id: \.day) { group in
                HStack(alignment: .top, spacing: Theme.Spacing.m) {
                    DateBadge(date: group.day)
                    VStack(spacing: Theme.Spacing.s) {
                        ForEach(group.entries) { entry in
                            NavigationLink(value: entry) {
                                JournalEntryCard(entry: entry)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

/// Day marker in the timeline: weekday, day number, month.
struct DateBadge: View {
    let date: Date
    var body: some View {
        VStack(spacing: 2) {
            Text(date.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                .font(.system(.caption2, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.gold)
            Text(date.formatted(.dateTime.day()))
                .font(.system(.title2, design: .serif).weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            Text(date.formatted(.dateTime.month(.abbreviated)))
                .font(Typo.caption)
                .foregroundStyle(Theme.textSecondary)
            if !Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year) {
                Text(date.formatted(.dateTime.year()))
                    .font(.system(.caption2))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(width: 48)
        .padding(.top, 6)
        .accessibilityElement(children: .combine)
    }
}

struct JournalEntryCard: View {
    let entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                if let cat = entry.category {
                    Image(systemName: cat.symbol)
                        .foregroundStyle(Color(hexString: cat.colorHex))
                        .font(.caption)
                }
                Text(entry.displayTitle)
                    .font(Typo.headline)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                Spacer(minLength: 4)
                if entry.isFavorite {
                    Image(systemName: "star.fill").font(.caption).foregroundStyle(Theme.gold)
                        .accessibilityLabel("Favorite")
                }
                if let mood = entry.mood {
                    Image(systemName: mood.symbol).foregroundStyle(mood.tint)
                        .accessibilityLabel(mood.label)
                }
            }
            if !entry.body.isEmpty {
                Text(entry.excerpt)
                    .font(Typo.callout)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(3)
            }
            if !entry.photoAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(entry.sortedAttachments.prefix(4)) { a in
                            MediaThumbnail(fileName: a.fileName, isVideo: a.kind == .video, maxPixel: 240, cornerRadius: 10)
                                .frame(width: 64, height: 64)
                        }
                    }
                }
                .allowsHitTesting(false)
            }
            HStack(spacing: 8) {
                Text(entry.date.formatted(date: .omitted, time: .shortened))
                if !entry.locationName.isEmpty {
                    Label(entry.locationName, systemImage: "mappin").lineLimit(1)
                }
                if !entry.tags.isEmpty {
                    Text(entry.tags.prefix(3).map { "#\($0)" }.joined(separator: " ")).lineLimit(1)
                }
            }
            .font(Typo.caption)
            .foregroundStyle(Theme.textTertiary)
        }
        .cardStyle()
        .contentShape(Rectangle())
    }
}

// MARK: - Backup pill

/// Compact, honest backup status shown at the top of the journal.
struct BackupStatusPill: View {
    @EnvironmentObject private var backup: BackupManager

    var body: some View {
        NavigationLink(value: AppModule.backup) {
            HStack(spacing: 8) {
                Image(systemName: backup.isRunning ? "arrow.triangle.2.circlepath" : stateSymbol)
                    .foregroundStyle(tint)
                    .symbolEffect(.pulse, isActive: backup.isRunning)
                Text(text)
                    .font(Typo.caption.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(Theme.surface))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Backup status: \(text)")
    }

    private var stateSymbol: String {
        backup.isEnabled ? backup.overallState.symbol : "externaldrive.badge.xmark"
    }

    private var tint: Color {
        guard backup.isEnabled else { return Theme.danger }
        switch backup.overallState {
        case .failed: return Theme.danger
        case .savedLocally: return Theme.gold
        case .pending, .waitingForICloud: return Theme.accent
        case .completed: return Theme.jungle
        }
    }

    private var text: String {
        if !backup.isEnabled { return "Automatic backup is off" }
        if backup.isRunning { return "Backing up…" }
        let state = backup.overallState
        switch state {
        case .completed:
            if let last = backup.lastSuccess {
                return "Backed up \(last.formatted(.relative(presentation: .named)))"
            }
            return "Backups are on · \(backup.destination.label)"
        case .savedLocally: return "Saved locally only · choose iCloud or Files for a safe backup"
        case .waitingForICloud: return "Saved · waiting for iCloud to upload"
        case .pending: return "Backup pending"
        case .failed: return "Backup failed · tap to review"
        }
    }
}
