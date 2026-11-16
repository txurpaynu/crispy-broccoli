import SwiftUI
import SwiftData

struct JournalCategoriesView: View {
    @Query(sort: \JournalCategory.sortOrder) private var categories: [JournalCategory]
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var router: AppRouter
    @State private var editing: JournalCategory?
    @State private var creating = false
    @State private var pendingDelete: JournalCategory?

    var body: some View {
        List {
            Section {
                ForEach(categories) { cat in
                    NavigationLink(value: cat) {
                        HStack {
                            IconBadge(symbol: cat.symbol, tint: Color(hexString: cat.colorHex), size: 34)
                            VStack(alignment: .leading) {
                                Text(cat.name).foregroundStyle(Theme.textPrimary)
                                Text("\((cat.entries ?? []).count) entries").font(Typo.caption).foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                    .swipeActions {
                        if !cat.isBuiltIn {
                            Button(role: .destructive) { pendingDelete = cat } label: { Label("Delete", systemImage: "trash") }
                        }
                        Button { editing = cat } label: { Label("Edit", systemImage: "pencil") }.tint(Theme.accent)
                    }
                }
                .onMove(perform: move)
            } footer: {
                Text("Built-in categories can be renamed but not deleted. Deleting a custom category keeps its entries; they simply become uncategorised.")
            }
        }
        .screenBackground()
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { creating = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("New category")
            }
            ToolbarItem(placement: .topBarLeading) { EditButton() }
        }
        .sheet(isPresented: $creating) {
            CategoryEditor(category: nil, nextOrder: categories.count)
        }
        .sheet(item: $editing) { cat in
            CategoryEditor(category: cat, nextOrder: categories.count)
        }
        .confirmationDialog("Delete category?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let cat = pendingDelete {
                    let affected = cat.entries ?? []
                    context.delete(cat)
                    try? context.save()
                    // Entries now have no category; rewrite their backup files.
                    for e in affected { BackupManager.shared?.entryChanged(e) }
                    router.showToast("Category deleted")
                }
                pendingDelete = nil
            }
        } message: {
            Text("Entries in this category are kept.")
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = categories
        ordered.move(fromOffsets: source, toOffset: destination)
        for (i, c) in ordered.enumerated() { c.sortOrder = i }
        try? context.save()
    }
}

struct CategoryEditor: View {
    let category: JournalCategory?
    let nextOrder: Int
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var all: [JournalCategory]
    @State private var name = ""
    @State private var symbol = "book.closed"
    @State private var color = PaletteChoice.turquoise.rawValue

    private let symbols = ["book.closed", "airplane", "paintbrush.pointed", "heart", "leaf", "moon.stars", "sun.max", "music.note",
                           "gamecontroller", "camera", "fork.knife", "figure.walk", "graduationcap", "briefcase", "house", "drop"]

    private var validation: String? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return "Give the category a name." }
        if all.contains(where: { $0.name.lowercased() == trimmed.lowercased() && $0.id != category?.id }) {
            return "A category with this name already exists."
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    ValidationHint(message: name.isEmpty ? nil : validation)
                }
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(symbols, id: \.self) { s in
                            Button { symbol = s } label: {
                                IconBadge(symbol: s, tint: symbol == s ? Color(hexString: color) : Theme.textTertiary, size: 38)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(s)
                        }
                    }
                }
                Section("Colour") {
                    HStack {
                        ForEach(PaletteChoice.allCases) { c in
                            Button { color = c.rawValue } label: {
                                Circle().fill(c.color).frame(width: 30, height: 30)
                                    .overlay(Circle().strokeBorder(Color.white, lineWidth: color == c.rawValue ? 3 : 0))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(c.rawValue)
                        }
                    }
                }
            }
            .navigationTitle(category == nil ? "New category" : "Edit category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(validation != nil)
                }
            }
            .onAppear {
                if let category { name = category.name; symbol = category.symbol; color = category.colorHex }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let category {
            category.name = trimmed; category.symbol = symbol; category.colorHex = color
            for e in category.entries ?? [] { BackupManager.shared?.entryChanged(e) }
        } else {
            context.insert(JournalCategory(name: trimmed, symbol: symbol, colorHex: color, sortOrder: nextOrder))
        }
        try? context.save()
        dismiss()
    }
}

struct JournalCategoryEntriesView: View {
    let category: JournalCategory

    var body: some View {
        let entries = (category.entries ?? []).sorted { $0.date > $1.date }
        ScrollView {
            if entries.isEmpty {
                EmptyStateView(symbol: category.symbol, title: "Nothing here yet", message: "Entries you file under \(category.name) appear here.")
            } else {
                JournalTimelineList(entries: entries).padding(.vertical)
            }
        }
        .screenBackground()
        .navigationTitle(category.name)
    }
}

/// On This Day, previous years, photo memories and important moments.
struct OnThisDayView: View {
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]

    var body: some View {
        let onThisDay = JournalStore.onThisDay(entries)
        let important = entries.filter(\.isImportant)
        let withPhotos = entries.filter { !$0.photoAttachments.isEmpty }
        let cal = Calendar.current
        let thisWeekPastYears = entries.filter { e in
            guard cal.component(.year, from: e.date) < cal.component(.year, from: Date()) else { return false }
            return cal.component(.weekOfYear, from: e.date) == cal.component(.weekOfYear, from: Date())
        }

        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                section("On this day", subtitle: Date().formatted(.dateTime.day().month(.wide)), entries: onThisDay,
                        empty: "Nothing from this date in previous years yet. Keep writing; it will be here next year.")
                section("This week in previous years", subtitle: nil, entries: thisWeekPastYears.filter { !onThisDay.contains($0) },
                        empty: nil)

                if !withPhotos.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        SectionHeader(title: "Photo memories")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(withPhotos.prefix(20)) { e in
                                    NavigationLink(value: e) {
                                        ZStack(alignment: .bottomLeading) {
                                            MediaThumbnail(fileName: e.photoAttachments[0].fileName, maxPixel: 500)
                                                .frame(width: 150, height: 190)
                                            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                                                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
                                            Text(e.date.formatted(date: .abbreviated, time: .omitted))
                                                .font(Typo.caption.weight(.semibold))
                                                .foregroundStyle(.white)
                                                .padding(10)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                section("Important moments", subtitle: nil, entries: Array(important.prefix(20)),
                        empty: "Mark an entry as an important moment and it will be gathered here.")
            }
            .padding()
        }
        .screenBackground()
        .navigationTitle("On This Day")
    }

    @ViewBuilder
    private func section(_ title: String, subtitle: String?, entries: [JournalEntry], empty: String?) -> some View {
        if !entries.isEmpty || empty != nil {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                SectionHeader(title: title, subtitle: subtitle)
                if entries.isEmpty, let empty {
                    Text(empty).font(Typo.callout).foregroundStyle(Theme.textSecondary).cardStyle()
                }
                ForEach(entries) { e in
                    NavigationLink(value: e) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(e.date.formatted(.dateTime.year()))
                                .font(Typo.eyebrow).foregroundStyle(Theme.gold)
                            JournalEntryCard(entry: e)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
