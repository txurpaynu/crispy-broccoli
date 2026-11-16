import SwiftUI
import SwiftData
import PhotosUI

/// One sheet, one text field, one tap to save — for any kind of capture.
struct QuickCaptureView: View {
    @State var kind: CaptureKind
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: AppRouter
    @Query(sort: \JournalCategory.sortOrder) private var categories: [JournalCategory]

    @State private var text = ""
    @State private var mood: Mood?
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var importedMedia: [MediaImporter.Imported] = []
    @State private var importing = false
    @State private var place: LocationService.Place?
    @State private var placeName = ""
    @State private var dueToday = true
    @State private var error: String?
    @StateObject private var location = LocationService()
    @FocusState private var focused: Bool

    init(initialKind: CaptureKind) {
        _kind = State(initialValue: initialKind)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(CaptureKind.allCases) { k in
                            Button { kind = k } label: {
                                Chip(text: k.label, symbol: k.symbol, isSelected: kind == k)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }

                TextField(placeholder, text: $text, axis: .vertical)
                    .font(Typo.bodySerif)
                    .lineLimit(kind == .task || kind == .place ? 1...3 : 3...10)
                    .focused($focused)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.medium).fill(Theme.surface))
                    .padding(.horizontal)

                extras.padding(.horizontal)

                if let error { ValidationHint(message: error).padding(.horizontal) }
                Spacer(minLength: 0)
            }
            .padding(.top)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Quick capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).fontWeight(.semibold).disabled(!canSave || importing)
                }
            }
            .onAppear { focused = true }
            .onChange(of: photoItems) { _, items in
                guard !items.isEmpty else { return }
                importing = true
                Task {
                    let (media, failed) = await MediaImporter.importItems(items)
                    importedMedia += media
                    if failed > 0 { error = "\(failed) item(s) couldn't be added." }
                    photoItems = []
                    importing = false
                }
            }
        }
    }

    private var placeholder: String {
        switch kind {
        case .thought: "What's on your mind?"
        case .journal: "Write a few lines about now…"
        case .photo: "Add a caption (optional)"
        case .place: "Name this place"
        case .memory: "What do you want to remember?"
        case .task: "What needs doing?"
        case .projectIdea: "Describe the idea"
        }
    }

    private var canSave: Bool {
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        switch kind {
        case .photo: return !importedMedia.isEmpty
        case .place: return hasText || place != nil
        default: return hasText || !importedMedia.isEmpty
        }
    }

    @ViewBuilder
    private var extras: some View {
        switch kind {
        case .journal, .thought:
            if kind == .journal { MoodPicker(selection: $mood) }
            mediaRow
        case .photo, .memory:
            mediaRow
        case .place:
            HStack {
                Button {
                    Task {
                        do {
                            let p = try await location.currentPlace()
                            place = p
                            if text.isEmpty { text = p.name }
                        } catch { self.error = error.localizedDescription }
                    }
                } label: {
                    Label(location.isLocating ? "Locating…" : (place == nil ? "Use current location" : "Location added"),
                          systemImage: place == nil ? "location" : "checkmark")
                }
                .buttonStyle(SecondaryButtonStyle())
                if let place { Text(place.country).font(Typo.caption).foregroundStyle(Theme.textSecondary) }
            }
        case .task:
            Toggle("Due today", isOn: $dueToday)
        case .projectIdea:
            Text("Saved to Create as a new project with the status Idea.")
                .font(Typo.caption).foregroundStyle(Theme.textSecondary)
        }
    }

    private var mediaRow: some View {
        HStack {
            PhotosPicker(selection: $photoItems, maxSelectionCount: 10, matching: .any(of: [.images, .videos])) {
                Label(importing ? "Adding…" : "Photos", systemImage: "photo")
            }
            .buttonStyle(SecondaryButtonStyle())
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(importedMedia, id: \.fileName) { m in
                        MediaThumbnail(fileName: m.fileName, isVideo: m.kind == .video, maxPixel: 160, cornerRadius: 8)
                            .frame(width: 44, height: 44)
                    }
                }
            }
        }
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            switch kind {
            case .journal:
                let entry = JournalEntry(title: "", body: trimmed, date: Date())
                entry.mood = mood
                entry.category = categories.first
                context.insert(entry)
                attachMedia { $0.entry = entry }
                try JournalStore.save(entry, previousDayKey: nil, in: context)
                BackupManager.shared?.flushNow()
                router.showToast("Saved to your journal")
            case .thought, .memory, .photo:
                let m = Memory(title: "", text: trimmed,
                               kind: kind == .thought ? .thought : (importedMedia.isEmpty ? .text : (importedMedia.first?.kind == .video ? .video : .photo)),
                               date: Date())
                context.insert(m)
                attachMedia { $0.memory = m }
                try context.save()
                router.showToast(kind == .thought ? "Thought saved to Memory Vault" : "Memory saved")
            case .place:
                let p = TravelDestination(name: trimmed.isEmpty ? (place?.name ?? "Place") : trimmed, kind: .place, status: .saved)
                p.latitude = place?.coordinate.latitude
                p.longitude = place?.coordinate.longitude
                p.city = place?.city ?? ""
                p.country = place?.country ?? ""
                p.countryCode = place?.countryCode ?? ""
                context.insert(p)
                try context.save()
                router.showToast("Place saved to Explore")
            case .task:
                context.insert(TaskItem(title: trimmed, dueDate: dueToday ? Calendar.current.startOfDay(for: Date()) : nil))
                try context.save()
                router.showToast("Task added")
            case .projectIdea:
                let firstLine = trimmed.split(separator: "\n").first.map(String.init) ?? trimmed
                let project = CreativeProject(name: String(firstLine.prefix(60)), summary: trimmed, status: .idea)
                context.insert(project)
                let update = ProjectUpdate(text: "Idea captured", symbol: "lightbulb")
                context.insert(update); update.project = project
                try context.save()
                router.showToast("Idea saved to Create")
            }
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func attachMedia(_ assign: (JournalAttachment) -> Void) {
        for m in importedMedia {
            let a = JournalAttachment(kind: m.kind, fileName: m.fileName, originalFileName: m.originalName)
            context.insert(a)
            assign(a)
        }
    }
}
