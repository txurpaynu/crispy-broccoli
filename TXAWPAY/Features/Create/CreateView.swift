import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

struct CreateView: View {
    @Query(sort: \CreativeProject.modifiedAt, order: .reverse) private var projects: [CreativeProject]
    @State private var statusFilter: ProjectStatus?
    @State private var categoryFilter: String?
    @State private var creating = false
    @State private var search = ""

    private var categories: [String] {
        Array(Set(CreativeProject.builtInCategories + projects.map(\.category))).sorted()
    }

    private var filtered: [CreativeProject] {
        projects.filter { p in
            (statusFilter == nil ? p.status != .archived : p.status == statusFilter)
                && (categoryFilter == nil || p.category == categoryFilter)
                && (search.isEmpty || p.name.localizedCaseInsensitiveContains(search) || p.summary.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                if !projects.isEmpty {
                    HStack(spacing: Theme.Spacing.s) {
                        StatTile(value: "\(projects.filter { $0.status == .inProgress }.count)", label: "In progress", symbol: "hammer")
                        StatTile(value: "\(projects.filter { $0.status == .idea }.count)", label: "Ideas", symbol: "lightbulb", tint: Theme.gold)
                        StatTile(value: "\(projects.filter { $0.status == .completed }.count)", label: "Completed", symbol: "checkmark.seal", tint: Theme.jungle)
                    }
                    .padding(.horizontal)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button { statusFilter = nil } label: { Chip(text: "Active", isSelected: statusFilter == nil) }
                        ForEach(ProjectStatus.allCases) { s in
                            Button { statusFilter = statusFilter == s ? nil : s } label: {
                                Chip(text: s.label, symbol: s.symbol, color: s.tint, isSelected: statusFilter == s)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }

                if projects.isEmpty {
                    EmptyStateView(symbol: "paintbrush.pointed", title: "Your creative workshop",
                                   message: "Games, characters, worlds, stories, art — give every idea a home and watch it grow.",
                                   actionTitle: "New project") { creating = true }
                } else if filtered.isEmpty {
                    EmptyStateView(symbol: "line.3.horizontal.decrease.circle", title: "Nothing in this view", message: "Try another filter.")
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: Theme.Spacing.m)], spacing: Theme.Spacing.m) {
                        ForEach(filtered) { p in
                            NavigationLink(value: p) { ProjectCard(project: p) }.buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .screenBackground()
        .navigationTitle("Create")
        .searchable(text: $search, prompt: "Search projects")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button("All categories") { categoryFilter = nil }
                    ForEach(categories, id: \.self) { c in Button(c) { categoryFilter = c } }
                } label: {
                    Image(systemName: categoryFilter == nil ? "folder" : "folder.fill")
                }
                .accessibilityLabel("Filter by category")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { creating = true } label: { Image(systemName: "plus") }.accessibilityLabel("New project")
            }
        }
        .sheet(isPresented: $creating) { NavigationStack { ProjectEditor(project: nil) } }
    }
}

struct ProjectCard: View {
    let project: CreativeProject
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if !project.coverFileName.isEmpty {
                    MediaThumbnail(fileName: project.coverFileName, maxPixel: 600, cornerRadius: 0)
                } else {
                    ZStack {
                        Theme.hydroGradient
                        Image(systemName: project.status.symbol).font(.largeTitle).foregroundStyle(Brand.warmIvory.opacity(0.8))
                    }
                }
            }
            .frame(height: 110)
            .clipped()
            VStack(alignment: .leading, spacing: 6) {
                Text(project.name).font(Typo.headline).foregroundStyle(Theme.textPrimary).lineLimit(2)
                Text(project.category).font(Typo.caption).foregroundStyle(Theme.textSecondary).lineLimit(1)
                HStack {
                    Chip(text: project.status.label, color: project.status.tint)
                    Spacer()
                    if !(project.milestones ?? []).isEmpty {
                        Text("\(Int(project.progress * 100))%").font(Typo.caption.weight(.semibold)).foregroundStyle(Theme.accent)
                    }
                }
                ProgressView(value: project.progress).tint(project.status.tint)
            }
            .padding(Theme.Spacing.m)
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
        .accessibilityElement(children: .combine)
    }
}

struct ProjectEntryRoute: Hashable { let project: CreativeProject }

struct ProjectDetailView: View {
    @Bindable var project: CreativeProject
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: AppRouter
    @State private var tab = 0
    @State private var editing = false
    @State private var newMilestone = ""
    @State private var newUpdate = ""
    @State private var inspirationItems: [PhotosPickerItem] = []
    @State private var importingFile = false
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                header
                Picker("Section", selection: $tab) {
                    Text("Overview").tag(0)
                    Text("Milestones").tag(1)
                    Text("Gallery").tag(2)
                    Text("Files").tag(3)
                    Text("History").tag(4)
                }
                .pickerStyle(.segmented)

                switch tab {
                case 0: overview
                case 1: milestones
                case 2: gallery
                case 3: files
                default: history
                }
            }
            .padding()
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { editing = true } label: { Label("Edit", systemImage: "pencil") }
                    Menu("Status") {
                        ForEach(ProjectStatus.allCases) { s in
                            Button { setStatus(s) } label: { Label(s.label, systemImage: s.symbol) }
                        }
                    }
                    Button { router.open(ProjectEntryRoute(project: project)) } label: { Label("Write journal entry", systemImage: "square.and.pencil") }
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Delete project", systemImage: "trash") }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(isPresented: $editing) { NavigationStack { ProjectEditor(project: project) } }
        .confirmationDialog("Delete this project?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete project", role: .destructive) {
                for a in project.attachments ?? [] { MediaStore.shared.delete(a.fileName) }
                MediaStore.shared.delete(project.coverFileName)
                RecentsStore.shared.remove(id: project.id)
                context.delete(project); try? context.save(); dismiss()
            }
        } message: { Text("Milestones, notes and files are removed. Linked journal entries and memories are kept.") }
        .onChange(of: inspirationItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                let (imported, _) = await MediaImporter.importItems(items)
                for m in imported { addAttachment(kind: m.kind, fileName: m.fileName, name: m.originalName, role: .inspiration) }
                inspirationItems = []
            }
        }
        .fileImporter(isPresented: $importingFile, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result else { return }
            for url in urls {
                if let name = try? MediaStore.shared.importFile(at: url) {
                    addAttachment(kind: .file, fileName: name, name: url.lastPathComponent, role: .file)
                }
            }
        }
        .onAppear { RecentsStore.shared.record(.project, id: project.id, title: project.name) }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            ProgressRing(progress: project.progress, lineWidth: 7, tint: project.status.tint).frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name).font(Typo.title).foregroundStyle(Theme.textPrimary)
                HStack { Chip(text: project.status.label, symbol: project.status.symbol, color: project.status.tint); Chip(text: project.category, color: Theme.earth) }
                Text("Created \(project.createdAt.formatted(date: .abbreviated, time: .omitted)) · Updated \(project.modifiedAt.formatted(.relative(presentation: .named)))")
                    .font(Typo.caption).foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            if !project.coverFileName.isEmpty {
                MediaThumbnail(fileName: project.coverFileName, maxPixel: 1200).frame(height: 180)
            }
            if !project.summary.isEmpty { Text(project.summary).font(Typo.bodySerif).foregroundStyle(Theme.textPrimary) }
            VStack(alignment: .leading, spacing: 6) {
                Label("Notes", systemImage: "note.text").font(Typo.eyebrow).foregroundStyle(Theme.gold)
                TextField("Ideas, plans, lore, anything…", text: $project.notes, axis: .vertical)
                    .lineLimit(4...20)
                    .font(Typo.bodySerif)
                    .onChange(of: project.notes) { _, _ in project.modifiedAt = Date() }
            }
            .cardStyle()
            let entries = (project.journalEntries ?? []).sorted { $0.date > $1.date }
            let memories = project.memories ?? []
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                SectionHeader(title: "Related memories", actionTitle: "Write") { router.open(ProjectEntryRoute(project: project)) }
                if entries.isEmpty && memories.isEmpty {
                    Text("Journal entries and memories linked to this project appear here.").font(Typo.callout).foregroundStyle(Theme.textSecondary)
                }
                ForEach(entries) { e in NavigationLink(value: e) { JournalEntryCard(entry: e) }.buttonStyle(.plain) }
                ForEach(memories) { m in
                    NavigationLink(value: m) { NavRow(symbol: m.kind.symbol, title: m.displayTitle) }.buttonStyle(.plain)
                }
            }
        }
    }

    private var milestones: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            ForEach(project.sortedMilestones) { m in
                HStack {
                    Button {
                        m.isDone.toggle()
                        m.completedAt = m.isDone ? Date() : nil
                        if m.isDone { log("Completed “\(m.title)”", "checkmark.circle") }
                        project.modifiedAt = Date()
                        try? context.save()
                    } label: {
                        Image(systemName: m.isDone ? "checkmark.circle.fill" : "circle").font(.title3)
                            .foregroundStyle(m.isDone ? Theme.jungle : Theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    VStack(alignment: .leading) {
                        Text(m.title).strikethrough(m.isDone).foregroundStyle(Theme.textPrimary)
                        if let d = m.dueDate { Text(d.formatted(date: .abbreviated, time: .omitted)).font(Typo.caption).foregroundStyle(Theme.textSecondary) }
                    }
                    Spacer()
                    Button(role: .destructive) { context.delete(m); try? context.save() } label: { Image(systemName: "trash").font(.caption) }
                        .buttonStyle(.plain).foregroundStyle(Theme.textTertiary)
                        .accessibilityLabel("Delete milestone")
                }
                .cardStyle(padding: Theme.Spacing.m)
            }
            HStack {
                TextField("New milestone", text: $newMilestone).onSubmit(addMilestone)
                Button("Add", action: addMilestone).disabled(newMilestone.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .cardStyle(padding: Theme.Spacing.m)
        }
    }

    private var gallery: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PhotosPicker(selection: $inspirationItems, maxSelectionCount: 30, matching: .images) {
                Label("Add inspiration images", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(SecondaryButtonStyle())
            let images = (project.attachments ?? []).filter { $0.role == .inspiration }.sorted { $0.createdAt < $1.createdAt }
            if images.isEmpty {
                Text("Moodboards, references, colour studies — collect them here.").font(Typo.callout).foregroundStyle(Theme.textSecondary)
            } else {
                AttachmentGrid(attachments: images) { a in MediaStore.shared.delete(a.fileName); context.delete(a); try? context.save() }
            }
        }
    }

    private var files: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Button { importingFile = true } label: { Label("Attach files", systemImage: "paperclip") }
                .buttonStyle(SecondaryButtonStyle())
            let list = (project.attachments ?? []).filter { $0.role == .file }.sorted { $0.createdAt < $1.createdAt }
            if list.isEmpty {
                Text("Documents, scripts, sound files — anything related to the project.").font(Typo.callout).foregroundStyle(Theme.textSecondary)
            }
            ForEach(list) { a in
                HStack {
                    Image(systemName: "doc").foregroundStyle(Theme.accent)
                    Text(a.originalFileName.isEmpty ? a.fileName : a.originalFileName).lineLimit(1)
                    Spacer()
                    ShareLink(item: a.fileURL) { Image(systemName: "square.and.arrow.up") }
                    Button(role: .destructive) { MediaStore.shared.delete(a.fileName); context.delete(a); try? context.save() } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain).foregroundStyle(Theme.textTertiary)
                }
                .cardStyle(padding: Theme.Spacing.m)
            }
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                TextField("Log progress…", text: $newUpdate).onSubmit(addUpdate)
                Button("Add", action: addUpdate).disabled(newUpdate.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .cardStyle(padding: Theme.Spacing.m)
            ForEach((project.updates ?? []).sorted { $0.date > $1.date }) { u in
                HStack(alignment: .top) {
                    Image(systemName: u.symbol).foregroundStyle(Theme.gold).frame(width: 24)
                    VStack(alignment: .leading) {
                        Text(u.text).foregroundStyle(Theme.textPrimary)
                        Text(u.date.formatted(date: .abbreviated, time: .shortened)).font(Typo.caption).foregroundStyle(Theme.textTertiary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func addMilestone() {
        let title = newMilestone.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        let m = ProjectMilestone(title: title, sortOrder: (project.milestones ?? []).count)
        context.insert(m); m.project = project
        project.modifiedAt = Date()
        try? context.save()
        newMilestone = ""
    }

    private func addUpdate() {
        let text = newUpdate.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        log(text, "pencil.line")
        newUpdate = ""
    }

    private func log(_ text: String, _ symbol: String) {
        let u = ProjectUpdate(text: text, symbol: symbol)
        context.insert(u); u.project = project
        project.modifiedAt = Date()
        try? context.save()
    }

    private func setStatus(_ s: ProjectStatus) {
        guard s != project.status else { return }
        project.status = s
        project.completedAt = s == .completed ? Date() : nil
        log("Status changed to \(s.label)", s.symbol)
    }

    private func addAttachment(kind: AttachmentKind, fileName: String, name: String, role: AttachmentRole) {
        let a = JournalAttachment(kind: kind, fileName: fileName, originalFileName: name, role: role)
        context.insert(a); a.project = project
        project.modifiedAt = Date()
        try? context.save()
    }
}

struct ProjectEditor: View {
    let project: CreativeProject?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var all: [CreativeProject]
    @State private var name = ""
    @State private var summary = ""
    @State private var category = "Personal Projects"
    @State private var customCategory = ""
    @State private var status = ProjectStatus.idea
    @State private var cover = ""

    private var categories: [String] { Array(Set(CreativeProject.builtInCategories + all.map(\.category))).sorted() }

    var body: some View {
        Form {
            Section {
                TextField("Project name", text: $name)
                TextField("Description", text: $summary, axis: .vertical).lineLimit(2...6)
            }
            Section("Category") {
                Picker("Category", selection: $category) {
                    ForEach(categories, id: \.self) { Text($0).tag($0) }
                    Text("New category…").tag("__custom__")
                }
                if category == "__custom__" { TextField("Category name", text: $customCategory) }
            }
            Section("Status") {
                Picker("Status", selection: $status) { ForEach(ProjectStatus.allCases) { Label($0.label, systemImage: $0.symbol).tag($0) } }
            }
            Section("Cover image") {
                SinglePhotoPicker(fileName: $cover) {
                    if cover.isEmpty { Label("Choose cover", systemImage: "photo") }
                    else { MediaThumbnail(fileName: cover, maxPixel: 600).frame(height: 120) }
                }
            }
        }
        .navigationTitle(project == nil ? "New project" : "Edit project")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || (category == "__custom__" && customCategory.trimmingCharacters(in: .whitespaces).isEmpty))
            }
        }
        .onAppear {
            guard let project else { return }
            name = project.name; summary = project.summary; category = project.category; status = project.status; cover = project.coverFileName
        }
    }

    private func save() {
        let p = project ?? CreativeProject(name: "")
        let previousStatus = project?.status
        p.name = name.trimmingCharacters(in: .whitespaces)
        p.summary = summary
        p.category = category == "__custom__" ? customCategory.trimmingCharacters(in: .whitespaces) : category
        p.status = status
        p.coverFileName = cover
        p.modifiedAt = Date()
        if status == .completed && previousStatus != .completed { p.completedAt = Date() }
        if project == nil {
            context.insert(p)
            let u = ProjectUpdate(text: "Project created", symbol: "sparkles"); context.insert(u); u.project = p
        } else if let previousStatus, previousStatus != status {
            let u = ProjectUpdate(text: "Status changed to \(status.label)", symbol: status.symbol); context.insert(u); u.project = p
        }
        try? context.save()
        dismiss()
    }
}
