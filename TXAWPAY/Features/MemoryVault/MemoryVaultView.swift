import SwiftUI
import SwiftData
import PhotosUI

struct MemoryVaultView: View {
    @Query(sort: \Memory.date, order: .reverse) private var memories: [Memory]
    @State private var search = ""
    @State private var favoritesOnly = false
    @State private var collection: String?
    @State private var kind: MemoryKind?
    @State private var creating = false

    private var collections: [String] { Array(Set(memories.map(\.collection).filter { !$0.isEmpty })).sorted() }

    private var filtered: [Memory] {
        memories.filter { m in
            (!favoritesOnly || m.isFavorite)
                && (collection == nil || m.collection == collection)
                && (kind == nil || m.kind == kind)
                && (search.isEmpty || m.title.localizedCaseInsensitiveContains(search) || m.text.localizedCaseInsensitiveContains(search)
                    || m.tags.contains { $0.localizedCaseInsensitiveContains(search) } || m.locationName.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button { favoritesOnly.toggle() } label: { Chip(text: "Favorites", symbol: "heart.fill", color: Theme.gold, isSelected: favoritesOnly) }
                        ForEach(MemoryKind.allCases) { k in
                            Button { kind = kind == k ? nil : k } label: { Chip(text: k.label, symbol: k.symbol, isSelected: kind == k) }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }
                if !collections.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Button { collection = nil } label: { Chip(text: "All collections", symbol: "square.stack", color: Theme.earth, isSelected: collection == nil) }
                            ForEach(collections, id: \.self) { c in
                                Button { collection = collection == c ? nil : c } label: { Chip(text: c, color: Theme.earth, isSelected: collection == c) }
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }
                }

                if memories.isEmpty {
                    EmptyStateView(symbol: "sparkles.rectangle.stack", title: "A vault for what matters",
                                   message: "Photos, videos, words, places and dates you never want to lose.",
                                   actionTitle: "Save a memory") { creating = true }
                } else if filtered.isEmpty {
                    EmptyStateView(symbol: "magnifyingglass", title: "Nothing found", message: "Try another filter or search.")
                } else {
                    let groups = Dictionary(grouping: filtered) { DateMath.startOfMonth($0.date) }
                    ForEach(groups.keys.sorted(by: >), id: \.self) { month in
                        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                            Text(month.formatted(.dateTime.month(.wide).year())).font(Typo.title3).foregroundStyle(Theme.textPrimary)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                                ForEach(groups[month] ?? []) { m in
                                    NavigationLink(value: m) { MemoryTile(memory: m) }.buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .screenBackground()
        .navigationTitle("Memory Vault")
        .searchable(text: $search, prompt: "Search memories")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { creating = true } label: { Image(systemName: "plus") }.accessibilityLabel("New memory")
            }
        }
        .sheet(isPresented: $creating) { NavigationStack { MemoryEditor(memory: nil) } }
    }
}

struct MemoryTile: View {
    let memory: Memory
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let first = memory.sortedAttachments.first {
                MediaThumbnail(fileName: first.fileName, isVideo: first.kind == .video, maxPixel: 500, cornerRadius: Theme.Radius.medium)
                LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
            } else {
                RoundedRectangle(cornerRadius: Theme.Radius.medium).fill(Theme.surface)
                Image(systemName: memory.kind.symbol).font(.largeTitle).foregroundStyle(Theme.accent.opacity(0.25))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Image(systemName: memory.kind.symbol)
                    if memory.isFavorite { Image(systemName: "heart.fill").foregroundStyle(Theme.gold) }
                }
                .font(.caption)
                Text(memory.displayTitle).font(Typo.callout.weight(.semibold)).lineLimit(2)
                Text(memory.date.formatted(date: .abbreviated, time: .omitted)).font(.caption2)
            }
            .foregroundStyle(memory.sortedAttachments.isEmpty ? Theme.textPrimary : Color.white)
            .padding(10)
        }
        .frame(height: 170)
        .accessibilityElement(children: .combine)
    }
}

struct MemoryDetailView: View {
    @Bindable var memory: Memory
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                if !memory.sortedAttachments.isEmpty { AttachmentGrid(attachments: memory.sortedAttachments) }
                VStack(alignment: .leading, spacing: 6) {
                    Text(memory.date.formatted(date: .complete, time: .omitted)).font(Typo.eyebrow).foregroundStyle(Theme.gold)
                    Text(memory.displayTitle).font(Typo.largeTitle).foregroundStyle(Theme.textPrimary)
                    FlowLayout {
                        Chip(text: memory.kind.label, symbol: memory.kind.symbol)
                        if !memory.collection.isEmpty { Chip(text: memory.collection, symbol: "square.stack", color: Theme.earth) }
                        if !memory.locationName.isEmpty { Chip(text: memory.locationName, symbol: "mappin", color: Theme.earth) }
                    }
                }
                if !memory.text.isEmpty { Text(memory.text).font(Typo.bodySerif).foregroundStyle(Theme.textPrimary).textSelection(.enabled) }
                if !memory.tags.isEmpty { TagList(tags: memory.tags) }
                connections
            }
            .padding()
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { memory.isFavorite.toggle(); try? context.save() } label: {
                    Image(systemName: memory.isFavorite ? "heart.fill" : "heart")
                }
                .accessibilityLabel(memory.isFavorite ? "Remove favorite" : "Favorite")
                Menu {
                    Button { editing = true } label: { Label("Edit", systemImage: "pencil") }
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Delete", systemImage: "trash") }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(isPresented: $editing) { NavigationStack { MemoryEditor(memory: memory) } }
        .confirmationDialog("Delete this memory?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                for a in memory.attachments ?? [] { MediaStore.shared.delete(a.fileName) }
                RecentsStore.shared.remove(id: memory.id)
                context.delete(memory); try? context.save(); dismiss()
            }
        } message: { Text("Linked journal entries, trips, people and projects are not affected.") }
        .onAppear { RecentsStore.shared.record(.memory, id: memory.id, title: memory.displayTitle) }
    }

    @ViewBuilder
    private var connections: some View {
        let entries = memory.journalEntries ?? []
        let people = memory.people ?? []
        if !entries.isEmpty || !people.isEmpty || memory.trip != nil || memory.project != nil {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("Connected").font(Typo.eyebrow).foregroundStyle(Theme.textSecondary)
                if let t = memory.trip { NavigationLink(value: t) { NavRow(symbol: "airplane", title: t.title, subtitle: "Trip") } }
                if let p = memory.project { NavigationLink(value: p) { NavRow(symbol: "paintbrush.pointed", title: p.name, subtitle: "Project", tint: Theme.gold) } }
                ForEach(people) { p in NavigationLink(value: p) { NavRow(symbol: "person", title: p.name, subtitle: p.relationship, tint: Theme.earth) } }
                ForEach(entries) { e in NavigationLink(value: e) { NavRow(symbol: "book.closed", title: e.displayTitle, subtitle: e.date.formatted(date: .abbreviated, time: .omitted)) } }
            }
            .buttonStyle(.plain)
            .cardStyle()
        }
    }
}

struct MemoryEditor: View {
    let memory: Memory?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TravelTrip.startDate, order: .reverse) private var trips: [TravelTrip]
    @Query(sort: \CreativeProject.name) private var projects: [CreativeProject]
    @Query(sort: \Person.name) private var people: [Person]
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]
    @Query private var allMemories: [Memory]

    @State private var title = ""
    @State private var text = ""
    @State private var date = Date()
    @State private var kind = MemoryKind.text
    @State private var tags: [String] = []
    @State private var collection = ""
    @State private var location = ""
    @State private var favorite = false
    @State private var tripID: UUID?
    @State private var projectID: UUID?
    @State private var personIDs: Set<UUID> = []
    @State private var entryIDs: Set<UUID> = []
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var newMedia: [MediaImporter.Imported] = []
    @State private var importing = false

    private var collections: [String] { Array(Set(allMemories.map(\.collection).filter { !$0.isEmpty })).sorted() }

    var body: some View {
        Form {
            Section {
                TextField("Title", text: $title)
                TextField("What happened? What do you want to remember?", text: $text, axis: .vertical).lineLimit(3...12)
                DatePicker("Date", selection: $date, displayedComponents: .date)
                Picker("Type", selection: $kind) { ForEach(MemoryKind.allCases) { Label($0.label, systemImage: $0.symbol).tag($0) } }
                Toggle("Favorite", isOn: $favorite)
            }
            Section("Photos & videos") {
                PhotosPicker(selection: $photoItems, maxSelectionCount: 20, matching: .any(of: [.images, .videos])) {
                    Label(importing ? "Adding…" : "Add media", systemImage: "photo.on.rectangle")
                }
                if !newMedia.isEmpty { Text("\(newMedia.count) new item(s) will be added").font(Typo.caption) }
            }
            Section("Organise") {
                TagEditor(tags: $tags)
                TextField("Collection (e.g. Summer 2026)", text: $collection)
                if !collections.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack { ForEach(collections, id: \.self) { c in Button { collection = c } label: { Chip(text: c, isSelected: collection == c) }.buttonStyle(.plain) } }
                    }
                }
                TextField("Place", text: $location)
            }
            Section("Connect") {
                Picker("Trip", selection: $tripID) { Text("None").tag(UUID?.none); ForEach(trips) { Text($0.title).tag(UUID?.some($0.id)) } }
                Picker("Project", selection: $projectID) { Text("None").tag(UUID?.none); ForEach(projects) { Text($0.name).tag(UUID?.some($0.id)) } }
                if !people.isEmpty {
                    DisclosureGroup("People (\(personIDs.count))") {
                        ForEach(people) { p in toggleRow(p.name, personIDs.contains(p.id)) { personIDs.formSymmetricDifference([p.id]) } }
                    }
                }
                if !entries.isEmpty {
                    DisclosureGroup("Journal entries (\(entryIDs.count))") {
                        ForEach(entries.prefix(50)) { e in
                            toggleRow("\(e.date.formatted(date: .abbreviated, time: .omitted)) · \(e.displayTitle)", entryIDs.contains(e.id)) {
                                entryIDs.formSymmetricDifference([e.id])
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(memory == nil ? "New memory" : "Edit memory")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(importing || (title.trimmingCharacters(in: .whitespaces).isEmpty && text.trimmingCharacters(in: .whitespaces).isEmpty
                                            && newMedia.isEmpty && (memory?.attachments ?? []).isEmpty))
            }
        }
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            importing = true
            Task {
                let (media, _) = await MediaImporter.importItems(items)
                newMedia += media
                if kind == .text, let first = media.first { kind = first.kind == .video ? .video : .photo }
                photoItems = []; importing = false
            }
        }
        .onAppear {
            guard let memory else { return }
            title = memory.title; text = memory.text; date = memory.date; kind = memory.kind; tags = memory.tags
            collection = memory.collection; location = memory.locationName; favorite = memory.isFavorite
            tripID = memory.trip?.id; projectID = memory.project?.id
            personIDs = Set((memory.people ?? []).map(\.id)); entryIDs = Set((memory.journalEntries ?? []).map(\.id))
        }
    }

    private func toggleRow(_ title: String, _ on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack { Text(title).foregroundStyle(Theme.textPrimary).lineLimit(1); Spacer(); if on { Image(systemName: "checkmark").foregroundStyle(Theme.accent) } }
        }
    }

    private func save() {
        let m = memory ?? Memory()
        m.title = title.trimmingCharacters(in: .whitespaces); m.text = text; m.date = date; m.kind = kind; m.tags = tags
        m.collection = collection.trimmingCharacters(in: .whitespaces); m.locationName = location; m.isFavorite = favorite
        m.modifiedAt = Date()
        if memory == nil { context.insert(m) }
        m.trip = trips.first { $0.id == tripID }
        m.project = projects.first { $0.id == projectID }
        m.people = people.filter { personIDs.contains($0.id) }
        m.journalEntries = entries.filter { entryIDs.contains($0.id) }
        for media in newMedia {
            let a = JournalAttachment(kind: media.kind, fileName: media.fileName, originalFileName: media.originalName)
            context.insert(a); a.memory = m
        }
        try? context.save()
        dismiss()
    }
}
