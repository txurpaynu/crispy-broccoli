import SwiftUI
import SwiftData
import PhotosUI

/// Dedicated entry editor with autosave.
///
/// Saving model: the editor edits a `JournalEntry` directly. A new entry is
/// inserted into SwiftData as soon as it has a title or text. Every change is
/// saved after a short pause (`autosaveDelay`), which also schedules the
/// debounced Markdown backup; closing the editor saves and flushes the backup
/// immediately. Nothing typed is held only in memory for more than ~1 second.
struct JournalEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var backup: BackupManager
    @Query(sort: \JournalCategory.sortOrder) private var categories: [JournalCategory]

    @State private var entry: JournalEntry
    @State private var isNew: Bool
    @State private var originalDayKey: String?
    @State private var autosaveTask: Task<Void, Never>?
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var importingMedia = false
    @State private var showDetails = true
    @State private var showDeleteConfirm = false
    @State private var showLinks = false
    @State private var saveError: String?
    @State private var lastSaved: Date?
    /// Relationships are applied when the entry is first saved, so an empty draft
    /// is never attached to (and implicitly inserted via) another object.
    @State private var categoryID: UUID?
    @State private var pendingTrip: TravelTrip?
    @State private var pendingProject: CreativeProject?
    @StateObject private var location = LocationService()
    @FocusState private var focus: Field?

    enum Field { case title, body, reflection }
    private let autosaveDelay: UInt64 = 900_000_000

    init(entry: JournalEntry?, initialDate: Date? = nil, initialBody: String = "", initialTitle: String = "",
         trip: TravelTrip? = nil, project: CreativeProject? = nil) {
        _pendingTrip = State(initialValue: trip)
        _pendingProject = State(initialValue: project)
        _categoryID = State(initialValue: entry?.category?.id)
        if let entry {
            _entry = State(initialValue: entry)
            _isNew = State(initialValue: false)
            _originalDayKey = State(initialValue: DayKey.key(for: entry.date))
        } else {
            var date = Date()
            if let initialDate, !Calendar.current.isDateInToday(initialDate) {
                // Keep the chosen day, use the current time of day.
                let t = Calendar.current.dateComponents([.hour, .minute], from: Date())
                date = Calendar.current.date(bySettingHour: t.hour ?? 12, minute: t.minute ?? 0, second: 0, of: initialDate) ?? initialDate
            }
            _entry = State(initialValue: JournalEntry(title: initialTitle, body: initialBody, date: date))
            _isNew = State(initialValue: true)
            _originalDayKey = State(initialValue: nil)
        }
    }

    private var hasContent: Bool {
        !entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !entry.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !(entry.attachments ?? []).isEmpty
    }

    var body: some View {
        withDialogs(withObservers(editorScreen))
    }

    private var editorScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                header
                TextField("Title", text: $entry.title, axis: .vertical)
                    .font(.system(.title2, design: .serif).weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .focused($focus, equals: .title)
                    .submitLabel(.next)
                    .onSubmit { focus = .body }

                GoldDivider()

                ZStack(alignment: .topLeading) {
                    if entry.body.isEmpty {
                        Text(InspirationService.prompt().text)
                            .font(Typo.bodySerif)
                            .foregroundStyle(Theme.textTertiary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $entry.body)
                        .font(Typo.bodySerif)
                        .foregroundStyle(Theme.textPrimary)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 260)
                        .focused($focus, equals: .body)
                        .accessibilityLabel("Entry text")
                }

                attachmentsSection
                detailsSection
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(isNew ? "New entry" : "Edit entry")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar { toolbarContent }
    }

    private func withObservers<V: View>(_ view: V) -> some View {
        view
        .onChange(of: entry.title) { _, _ in scheduleAutosave() }
        .onChange(of: entry.body) { _, _ in scheduleAutosave() }
        .onChange(of: entry.reflection) { _, _ in scheduleAutosave() }
        .onChange(of: entry.date) { _, _ in scheduleAutosave() }
        .onChange(of: entry.moodRaw) { _, _ in scheduleAutosave() }
        .onChange(of: entry.tags) { _, _ in scheduleAutosave() }
        .onChange(of: entry.isFavorite) { _, _ in scheduleAutosave() }
        .onChange(of: entry.isImportant) { _, _ in scheduleAutosave() }
        .onChange(of: entry.locationName) { _, _ in scheduleAutosave() }
        .onChange(of: photoItems) { _, items in importPhotos(items) }
    }

    private func withDialogs<V: View>(_ view: V) -> some View {
        view
        .onAppear {
            if isNew { focus = .body }
            if categoryID == nil, isNew {
                let travel: JournalCategory? = pendingTrip != nil ? categories.first(where: { $0.name == "Travel Journal" }) : nil
                categoryID = travel?.id ?? categories.first?.id
            }
        }
        .onDisappear { finish() }
        .confirmationDialog("Delete this entry?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete entry", role: .destructive) { deleteEntry() }
        } message: {
            Text("The entry is removed from TXAWPAY. A copy of its backup file is kept in Version History.")
        }
        .sheet(isPresented: $showLinks) {
            EntryLinksSheet(entry: entry) { scheduleAutosave() }
        }
        .alert("Couldn't save", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    // MARK: Sections

    private var header: some View {
        HStack(spacing: Theme.Spacing.s) {
            DatePicker("Date", selection: $entry.date, in: ...Date.distantFuture)
                .labelsHidden()
                .datePickerStyle(.compact)
            Spacer()
            if let lastSaved {
                Label("Saved \(lastSaved.formatted(date: .omitted, time: .shortened))", systemImage: "checkmark")
                    .font(Typo.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .accessibilityLabel("Saved")
            }
        }
    }

    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            if !(entry.attachments ?? []).isEmpty {
                AttachmentGrid(attachments: entry.sortedAttachments) { attachment in
                    removeAttachment(attachment)
                }
            }
            HStack {
                PhotosPicker(selection: $photoItems, maxSelectionCount: 20, matching: .any(of: [.images, .videos])) {
                    Label(importingMedia ? "Adding…" : "Photos & videos", systemImage: "photo.on.rectangle.angled")
                }
                .disabled(importingMedia)
                Spacer()
                if importingMedia { ProgressView() }
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            Text("Mood").font(Typo.eyebrow).foregroundStyle(Theme.textSecondary)
            MoodPicker(selection: Binding(get: { entry.mood }, set: { entry.mood = $0 }))

            Text("Category").font(Typo.eyebrow).foregroundStyle(Theme.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(categories) { cat in
                        Button {
                            categoryID = cat.id
                            scheduleAutosave()
                        } label: {
                            Chip(text: cat.name, symbol: cat.symbol, color: Color(hexString: cat.colorHex),
                                 isSelected: categoryID == cat.id)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Text("Tags").font(Typo.eyebrow).foregroundStyle(Theme.textSecondary)
            TagEditor(tags: $entry.tags)

            Text("Location").font(Typo.eyebrow).foregroundStyle(Theme.textSecondary)
            HStack {
                TextField("Place name", text: $entry.locationName)
                Button {
                    Task { await useCurrentLocation() }
                } label: {
                    if location.isLocating { ProgressView() } else { Image(systemName: "location") }
                }
                .accessibilityLabel("Use current location")
                if !entry.locationName.isEmpty {
                    Button {
                        entry.locationName = ""; entry.latitude = nil; entry.longitude = nil
                    } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textTertiary) }
                    .accessibilityLabel("Clear location")
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.small).fill(Theme.surface))

            Text("Reflection (optional)").font(Typo.eyebrow).foregroundStyle(Theme.textSecondary)
            TextField("What did today teach you?", text: $entry.reflection, axis: .vertical)
                .lineLimit(3...10)
                .focused($focus, equals: .reflection)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.small).fill(Theme.surface))

            Toggle(isOn: $entry.isFavorite) { Label("Favorite", systemImage: "star") }
            Toggle(isOn: $entry.isImportant) { Label("Important moment", systemImage: "sparkle") }

            Button { showLinks = true } label: {
                Label(linkSummary, systemImage: "link")
            }
            .buttonStyle(SecondaryButtonStyle(fullWidth: true))
            .disabled(entry.modelContext == nil)
            if entry.modelContext == nil {
                Text("Write something first, then link this entry to a trip, project or people.")
                    .font(Typo.caption).foregroundStyle(Theme.textTertiary)
            }
        }
        .tint(Theme.accent)
    }

    private var linkSummary: String {
        var parts: [String] = []
        if let t = entry.trip ?? pendingTrip { parts.append(t.title) }
        if let p = entry.project ?? pendingProject { parts.append(p.name) }
        let people = entry.people ?? []
        if !people.isEmpty { parts.append("\(people.count) people") }
        return parts.isEmpty ? "Link to a trip, project or people" : "Linked: " + parts.joined(separator: ", ")
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if isNew && !hasContent {
                Button("Cancel") { dismiss() }
            } else {
                Menu {
                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Label("Delete entry", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("Done") { dismiss() }
                .fontWeight(.semibold)
        }
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Hide keyboard") { focus = nil }
        }
    }

    // MARK: Saving

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task {
            try? await Task.sleep(nanoseconds: autosaveDelay)
            guard !Task.isCancelled else { return }
            save()
        }
    }

    private func save(flush: Bool = false) {
        guard hasContent else { return }
        do {
            let chosen = categories.first { $0.id == categoryID }
            if entry.category?.id != chosen?.id { entry.category = chosen }
            if let trip = pendingTrip { entry.trip = trip; pendingTrip = nil }
            if let project = pendingProject { entry.project = project; pendingProject = nil }
            try JournalStore.save(entry, previousDayKey: originalDayKey, in: context)
            if isNew {
                isNew = false
                RecentsStore.shared.record(.journal, id: entry.id, title: entry.displayTitle)
            }
            originalDayKey = DayKey.key(for: entry.date)
            lastSaved = Date()
            if flush { backup.flushNow() }
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func finish() {
        autosaveTask?.cancel()
        // Only content-bearing entries are saved; an empty new entry is discarded.
        // An existing entry is never deleted just because its text was cleared.
        if hasContent {
            save(flush: true)
            router.showToast("Entry saved")
        }
    }

    private func deleteEntry() {
        autosaveTask?.cancel()
        if entry.modelContext != nil {
            do {
                try JournalStore.delete(entry, in: context)
                router.showToast("Entry deleted", symbol: "trash")
            } catch {
                saveError = error.localizedDescription
                return
            }
        }
        // Prevent finish() from re-saving a deleted entry.
        entry = JournalEntry()
        isNew = true
        dismiss()
    }

    // MARK: Media & location

    private func importPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        importingMedia = true
        Task {
            let (imported, failures) = await MediaImporter.importItems(items)
            if entry.modelContext == nil { context.insert(entry) }
            for item in imported {
                let attachment = JournalAttachment(kind: item.kind, fileName: item.fileName, originalFileName: item.originalName)
                context.insert(attachment)
                attachment.entry = entry
            }
            photoItems = []
            importingMedia = false
            if failures > 0 { router.showToast("\(failures) item(s) couldn't be added", symbol: "exclamationmark.triangle", isError: true) }
            save()
        }
    }

    private func removeAttachment(_ attachment: JournalAttachment) {
        MediaStore.shared.delete(attachment.fileName)
        context.delete(attachment)
        save()
    }

    private func useCurrentLocation() async {
        do {
            let place = try await location.currentPlace()
            entry.locationName = place.city.isEmpty ? place.name : "\(place.name), \(place.city)"
            entry.latitude = place.coordinate.latitude
            entry.longitude = place.coordinate.longitude
        } catch {
            router.showToast(error.localizedDescription, symbol: "location.slash", isError: true)
        }
    }
}

struct MoodPicker: View {
    @Binding var selection: Mood?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Mood.allCases) { mood in
                    let selected = selection == mood
                    Button {
                        selection = selected ? nil : mood
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: mood.symbol)
                                .font(.title3)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(selected ? mood.tint : mood.tint.opacity(0.12)))
                                .foregroundStyle(selected ? Color.white : mood.tint)
                            Text(mood.label)
                                .font(.caption2)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(mood.label)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(.vertical, 2)
        }
    }
}

/// Links an entry to a trip, project and people (the modules working together).
struct EntryLinksSheet: View {
    @Bindable var entry: JournalEntry
    var onChange: () -> Void
    @Query(sort: \TravelTrip.startDate, order: .reverse) private var trips: [TravelTrip]
    @Query(sort: \CreativeProject.modifiedAt, order: .reverse) private var projects: [CreativeProject]
    @Query(sort: \Person.name) private var people: [Person]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip") {
                    Picker("Trip", selection: Binding(get: { entry.trip?.id }, set: { id in
                        entry.trip = trips.first { $0.id == id }; onChange()
                    })) {
                        Text("None").tag(UUID?.none)
                        ForEach(trips) { Text($0.title).tag(UUID?.some($0.id)) }
                    }
                }
                Section("Project") {
                    Picker("Project", selection: Binding(get: { entry.project?.id }, set: { id in
                        entry.project = projects.first { $0.id == id }; onChange()
                    })) {
                        Text("None").tag(UUID?.none)
                        ForEach(projects) { Text($0.name).tag(UUID?.some($0.id)) }
                    }
                }
                Section("People") {
                    if people.isEmpty {
                        Text("Add people in the People section to link them here.")
                            .foregroundStyle(Theme.textSecondary)
                    }
                    ForEach(people) { person in
                        let linked = (entry.people ?? []).contains { $0.id == person.id }
                        Button {
                            var list = entry.people ?? []
                            if linked { list.removeAll { $0.id == person.id } } else { list.append(person) }
                            entry.people = list
                            onChange()
                        } label: {
                            HStack {
                                AvatarView(fileName: person.photoFileName, initials: person.initials, size: 32)
                                Text(person.name).foregroundStyle(Theme.textPrimary)
                                Spacer()
                                if linked { Image(systemName: "checkmark").foregroundStyle(Theme.accent) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Links")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}
