import SwiftUI
import SwiftData
import PhotosUI

struct PeopleView: View {
    @Query(sort: \Person.name) private var people: [Person]
    @Query private var dates: [ImportantDate]
    @State private var creating = false
    @State private var search = ""

    private struct Upcoming: Identifiable {
        let id: String; let person: Person?; let title: String; let date: Date; let symbol: String
    }

    private var upcoming: [Upcoming] {
        var list: [Upcoming] = []
        for p in people {
            if let b = p.birthday, let next = DateMath.nextOccurrence(of: b, repeatsYearly: true) {
                list.append(Upcoming(id: "b\(p.id)", person: p, title: "\(p.name)'s birthday", date: next, symbol: "gift"))
            }
        }
        for d in dates {
            if let next = d.nextOccurrence {
                list.append(Upcoming(id: "d\(d.id)", person: d.person, title: d.title, date: next, symbol: d.kind.symbol))
            }
        }
        return list.filter { DateMath.daysUntil($0.date) <= 60 }.sorted { $0.date < $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                if !upcoming.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        SectionHeader(title: "Coming up", subtitle: "Birthdays, anniversaries and important dates")
                        ForEach(upcoming.prefix(6)) { u in
                            HStack(spacing: Theme.Spacing.m) {
                                IconBadge(symbol: u.symbol, tint: Theme.gold, size: 36)
                                VStack(alignment: .leading) {
                                    Text(u.title).foregroundStyle(Theme.textPrimary)
                                    Text(u.date.formatted(date: .long, time: .omitted)).font(Typo.caption).foregroundStyle(Theme.textSecondary)
                                }
                                Spacer()
                                Text(DateMath.relativeDayText(u.date)).font(Typo.caption.weight(.semibold)).foregroundStyle(Theme.accent)
                            }
                        }
                    }
                    .cardStyle()
                }

                let filtered = people.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.relationship.localizedCaseInsensitiveContains(search) }
                if people.isEmpty {
                    EmptyStateView(symbol: "person.2", title: "The people who matter",
                                   message: "Remember birthdays, shared moments and the little things. Private to you — never shared.",
                                   actionTitle: "Add a person") { creating = true }
                } else {
                    let groups = Dictionary(grouping: filtered) { $0.relationship.isEmpty ? "Other" : $0.relationship }
                    ForEach(groups.keys.sorted(), id: \.self) { key in
                        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                            SectionHeader(title: key)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 12)], spacing: 16) {
                                ForEach(groups[key] ?? []) { p in
                                    NavigationLink(value: p) {
                                        VStack(spacing: 6) {
                                            AvatarView(fileName: p.photoFileName, initials: p.initials, size: 72)
                                            Text(p.name).font(Typo.callout).foregroundStyle(Theme.textPrimary).lineLimit(2).multilineTextAlignment(.center)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .screenBackground()
        .navigationTitle("People")
        .searchable(text: $search, prompt: "Search people")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { creating = true } label: { Image(systemName: "person.badge.plus") }.accessibilityLabel("Add person")
            }
        }
        .sheet(isPresented: $creating) { NavigationStack { PersonEditor(person: nil) } }
    }
}

struct PersonDetailView: View {
    @Bindable var person: Person
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var addingDate = false
    @State private var editingDate: ImportantDate?
    @State private var confirmDelete = false
    @State private var photoItems: [PhotosPickerItem] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                VStack(spacing: Theme.Spacing.s) {
                    AvatarView(fileName: person.photoFileName, initials: person.initials, size: 110)
                    Text(person.name).font(Typo.largeTitle).foregroundStyle(Theme.textPrimary)
                    if !person.relationship.isEmpty { Chip(text: person.relationship, color: Theme.earth) }
                    if let b = person.birthday {
                        Label("Birthday \(b.formatted(.dateTime.day().month(.wide)))", systemImage: "gift")
                            .font(Typo.callout).foregroundStyle(Theme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)

                if !person.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Notes", systemImage: "note.text").font(Typo.eyebrow).foregroundStyle(Theme.gold)
                        Text(person.notes).font(Typo.bodySerif)
                    }
                    .cardStyle()
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    SectionHeader(title: "Important dates", actionTitle: "Add") { addingDate = true }
                    let list = (person.importantDates ?? []).sorted { ($0.nextOccurrence ?? .distantFuture) < ($1.nextOccurrence ?? .distantFuture) }
                    if list.isEmpty { Text("Anniversaries, milestones, special days.").font(Typo.callout).foregroundStyle(Theme.textSecondary) }
                    ForEach(list) { d in
                        Button { editingDate = d } label: {
                            HStack {
                                Image(systemName: d.kind.symbol).foregroundStyle(Theme.gold)
                                VStack(alignment: .leading) {
                                    Text(d.title).foregroundStyle(Theme.textPrimary)
                                    Text(d.date.formatted(date: .long, time: .omitted)).font(Typo.caption).foregroundStyle(Theme.textSecondary)
                                }
                                Spacer()
                                if d.remind { Image(systemName: "bell").font(.caption).foregroundStyle(Theme.textTertiary) }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .cardStyle()

                let entries = (person.journalEntries ?? []).sorted { $0.date > $1.date }
                let memories = (person.memories ?? []).sorted { $0.date > $1.date }
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    SectionHeader(title: "Shared memories")
                    if entries.isEmpty && memories.isEmpty {
                        Text("Link journal entries or memories to \(person.name) and they'll gather here.")
                            .font(Typo.callout).foregroundStyle(Theme.textSecondary)
                    }
                    ForEach(memories) { m in
                        NavigationLink(value: m) { NavRow(symbol: m.kind.symbol, title: m.displayTitle, subtitle: m.date.formatted(date: .abbreviated, time: .omitted), tint: Theme.gold) }
                            .buttonStyle(.plain)
                    }
                    ForEach(entries) { e in NavigationLink(value: e) { JournalEntryCard(entry: e) }.buttonStyle(.plain) }
                }

                HStack {
                    SectionHeader(title: "Photos")
                    PhotosPicker(selection: $photoItems, maxSelectionCount: 20, matching: .images) { Label("Add", systemImage: "plus") }
                }
                let photos = (person.attachments ?? []).sorted { $0.createdAt < $1.createdAt }
                if !photos.isEmpty {
                    AttachmentGrid(attachments: photos) { a in MediaStore.shared.delete(a.fileName); context.delete(a); try? context.save() }
                }
            }
            .padding()
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { editing = true } label: { Label("Edit", systemImage: "pencil") }
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Delete", systemImage: "trash") }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(isPresented: $editing) { NavigationStack { PersonEditor(person: person) } }
        .sheet(isPresented: $addingDate) { ImportantDateEditor(date: nil, person: person) }
        .sheet(item: $editingDate) { ImportantDateEditor(date: $0, person: person) }
        .confirmationDialog("Delete \(person.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                for a in person.attachments ?? [] { MediaStore.shared.delete(a.fileName) }
                MediaStore.shared.delete(person.photoFileName)
                RecentsStore.shared.remove(id: person.id)
                context.delete(person); try? context.save()
                Task { await NotificationService.shared.refreshAll(context: context) }
                dismiss()
            }
        } message: { Text("Their important dates and photos are removed. Journal entries and memories are kept.") }
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                let (imported, _) = await MediaImporter.importItems(items)
                for m in imported {
                    let a = JournalAttachment(kind: m.kind, fileName: m.fileName, originalFileName: m.originalName)
                    context.insert(a); a.person = person
                }
                try? context.save(); photoItems = []
            }
        }
        .onAppear { RecentsStore.shared.record(.person, id: person.id, title: person.name) }
    }
}

/// Add or edit a person. Used pushed (Home quick action) or inside a sheet's NavigationStack.
struct PersonEditor: View {
    let person: Person?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: AppRouter
    @State private var name = ""
    @State private var relationship = ""
    @State private var hasBirthday = false
    @State private var birthday = Date()
    @State private var remind = false
    @State private var notes = ""
    @State private var photo = ""

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    SinglePhotoPicker(fileName: $photo) {
                        VStack {
                            AvatarView(fileName: photo, initials: String(name.prefix(1)).uppercased(), size: 84)
                            Text("Photo").font(Typo.caption)
                        }
                    }
                    Spacer()
                }
            }
            Section {
                TextField("Name", text: $name).textContentType(.name)
                TextField("Relationship", text: $relationship)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(Person.relationshipSuggestions, id: \.self) { r in
                            Button { relationship = r } label: { Chip(text: r, isSelected: relationship == r) }.buttonStyle(.plain)
                        }
                    }
                }
            }
            Section {
                Toggle("Birthday", isOn: $hasBirthday)
                if hasBirthday {
                    DatePicker("Date", selection: $birthday, displayedComponents: .date)
                    Toggle("Remind me on the day", isOn: $remind)
                }
            }
            Section("Notes") { TextField("Things to remember", text: $notes, axis: .vertical).lineLimit(3...10) }
        }
        .navigationTitle(person == nil ? "New person" : "Edit person")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let p = person ?? Person(name: "")
                    p.name = name.trimmingCharacters(in: .whitespaces); p.relationship = relationship
                    p.birthday = hasBirthday ? birthday : nil; p.birthdayReminder = hasBirthday && remind
                    p.notes = notes; p.photoFileName = photo
                    if person == nil { context.insert(p) }
                    try? context.save()
                    Task {
                        if p.birthdayReminder { await NotificationService.shared.requestPermission() }
                        await NotificationService.shared.refreshAll(context: context)
                    }
                    router.showToast(person == nil ? "\(p.name) added" : "Saved")
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            guard let person else { return }
            name = person.name; relationship = person.relationship; hasBirthday = person.birthday != nil
            birthday = person.birthday ?? Date(); remind = person.birthdayReminder; notes = person.notes; photo = person.photoFileName
        }
    }
}

struct ImportantDateEditor: View {
    let date: ImportantDate?
    let person: Person?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var day = Date()
    @State private var kind = ImportantDateKind.anniversary
    @State private var yearly = true
    @State private var remind = false
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                DatePicker("Date", selection: $day, displayedComponents: .date)
                Picker("Type", selection: $kind) { ForEach(ImportantDateKind.allCases) { Label($0.label, systemImage: $0.symbol).tag($0) } }
                Toggle("Repeats every year", isOn: $yearly)
                Toggle("Remind me", isOn: $remind)
                TextField("Notes", text: $notes, axis: .vertical)
                if let date {
                    Button("Delete date", role: .destructive) {
                        context.delete(date); try? context.save()
                        Task { await NotificationService.shared.refreshAll(context: context) }
                        dismiss()
                    }
                }
            }
            .navigationTitle(date == nil ? "Important date" : "Edit date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let d = date ?? ImportantDate(title: "", date: day)
                        d.title = title.trimmingCharacters(in: .whitespaces); d.date = day; d.kind = kind
                        d.repeatsYearly = yearly; d.remind = remind; d.notes = notes
                        if date == nil { context.insert(d); d.person = person }
                        try? context.save()
                        Task {
                            if remind { await NotificationService.shared.requestPermission() }
                            await NotificationService.shared.refreshAll(context: context)
                        }
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                guard let date else { return }
                title = date.title; day = date.date; kind = date.kind; yearly = date.repeatsYearly; remind = date.remind; notes = date.notes
            }
        }
    }
}
