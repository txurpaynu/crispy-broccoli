import SwiftUI
import SwiftData

/// Picks a year that actually has content.
struct YearbookPickerView: View {
    @Query private var entries: [JournalEntry]
    @Query private var trips: [TravelTrip]
    @Query private var memories: [Memory]

    private var years: [Int] {
        var set = Set(entries.filter { !$0.isDemo }.map { DateMath.year(of: $0.date) })
        set.formUnion(trips.map { DateMath.year(of: $0.startDate) })
        set.formUnion(memories.map { DateMath.year(of: $0.date) })
        set.insert(DateMath.year(of: Date()))
        return set.sorted(by: >)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.m) {
                HydroCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TXAWPAY Yearbook").font(.system(.title, design: .serif).weight(.semibold)).foregroundStyle(.white)
                        Text("A look back at a year of your life, built only from what you recorded.")
                            .font(Typo.callout).foregroundStyle(.white.opacity(0.85))
                    }
                }
                ForEach(years, id: \.self) { y in
                    NavigationLink(value: YearbookRoute(year: y)) {
                        HStack {
                            Text(String(y)).font(.system(.title, design: .serif).weight(.semibold)).foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Text("\(entries.filter { !$0.isDemo && DateMath.year(of: $0.date) == y }.count) entries")
                                .font(Typo.caption).foregroundStyle(Theme.textSecondary)
                            Image(systemName: "chevron.right").foregroundStyle(Theme.textTertiary)
                        }
                        .cardStyle()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .screenBackground()
        .navigationTitle("Yearbook")
    }
}

/// Everything the yearbook shows, gathered from real records only.
struct YearbookData {
    var year: Int
    var entryCount = 0
    var wordCount = 0
    var topMoods: [(Mood, Int)] = []
    var highlights: [JournalEntry] = []
    var trips: [TravelTrip] = []
    var countries: [String] = []
    var cities: [String] = []
    var projectsCompleted: [CreativeProject] = []
    var projectsStarted = 0
    var goalsCompleted: [LearningGoal] = []
    var studyMinutes = 0
    var workouts = 0
    var people: [Person] = []
    var memories: [Memory] = []
    var photos: [JournalAttachment] = []

    var isEmpty: Bool {
        entryCount == 0 && trips.isEmpty && projectsCompleted.isEmpty && goalsCompleted.isEmpty && memories.isEmpty && studyMinutes == 0
    }

    @MainActor
    static func build(year: Int, context: ModelContext) -> YearbookData {
        func all<T: PersistentModel>(_ t: T.Type) -> [T] { (try? context.fetch(FetchDescriptor<T>())) ?? [] }
        let (start, end) = DateMath.yearRange(year)
        func inYear(_ d: Date) -> Bool { d >= start && d < end }
        var data = YearbookData(year: year)

        let entries = all(JournalEntry.self).filter { !$0.isDemo && inYear($0.date) }
        data.entryCount = entries.count
        data.wordCount = entries.reduce(0) { $0 + $1.wordCount }
        let moods = Dictionary(grouping: entries.compactMap(\.mood), by: { $0 }).mapValues(\.count)
        data.topMoods = moods.sorted { $0.value > $1.value }.prefix(3).map { ($0.key, $0.value) }
        data.highlights = entries.filter { $0.isImportant || $0.isFavorite }.sorted { $0.date < $1.date }

        data.trips = all(TravelTrip.self).filter { !$0.isDemo && inYear($0.startDate) && ($0.status == .completed || $0.status == .ongoing) }
            .sorted { $0.startDate < $1.startDate }
        let places = all(TravelDestination.self).filter { !$0.isDemo && $0.status == .visited && ($0.visitedDate.map(inYear) ?? ($0.trip.map { inYear($0.startDate) } ?? false)) }
        var countryCodes = Set(data.trips.map(\.countryCode).filter { !$0.isEmpty })
        countryCodes.formUnion(places.map(\.countryCode).filter { !$0.isEmpty })
        data.countries = countryCodes.map { "\(CountryInfo.flag(for: $0)) \(CountryInfo.name(for: $0))" }.sorted()
        data.cities = Array(Set(places.compactMap { $0.kind == .city ? $0.name : ($0.city.isEmpty ? nil : $0.city) })).sorted()

        let projects = all(CreativeProject.self).filter { !$0.isDemo }
        data.projectsCompleted = projects.filter { $0.status == .completed && ($0.completedAt.map(inYear) ?? false) }
        data.projectsStarted = projects.filter { inYear($0.createdAt) }.count
        data.goalsCompleted = all(LearningGoal.self).filter { !$0.isDemo && $0.isCompleted && ($0.completedAt.map(inYear) ?? false) }
        data.studyMinutes = all(StudySession.self).filter { !$0.isDemo && inYear($0.date) }.reduce(0) { $0 + $1.durationMinutes }
        data.workouts = all(Workout.self).filter { !$0.isDemo && !$0.isTemplate && $0.isCompleted && inYear($0.date) }.count

        data.memories = all(Memory.self).filter { !$0.isDemo && inYear($0.date) }.sorted { $0.date < $1.date }
        // People who appear in this year's entries or memories.
        var peopleByID: [UUID: Person] = [:]
        for e in entries { for p in e.people ?? [] { peopleByID[p.id] = p } }
        for m in data.memories { for p in m.people ?? [] { peopleByID[p.id] = p } }
        data.people = peopleByID.values.sorted { $0.name < $1.name }

        // Photos: favourites/important entries and favourite memories first.
        let preferred = data.highlights.flatMap(\.photoAttachments) + data.memories.filter(\.isFavorite).flatMap(\.sortedAttachments).filter { $0.kind == .photo }
        let rest = entries.flatMap(\.photoAttachments) + data.memories.flatMap(\.sortedAttachments).filter { $0.kind == .photo }
        var seen = Set<UUID>()
        data.photos = (preferred + rest).filter { seen.insert($0.id).inserted }.prefix(12).map { $0 }
        return data
    }

    /// Markdown version for sharing.
    func markdown() -> String {
        var s = "# TXAWPAY Yearbook \(year)\n\n"
        s += "- Journal entries: \(entryCount) (\(wordCount) words)\n"
        if !topMoods.isEmpty { s += "- Most frequent moods: \(topMoods.map { "\($0.0.label) (\($0.1))" }.joined(separator: ", "))\n" }
        s += "- Trips: \(trips.count)\n- Countries: \(countries.count)\n- Cities: \(cities.count)\n"
        s += "- Projects completed: \(projectsCompleted.count) · started: \(projectsStarted)\n"
        s += "- Learning goals completed: \(goalsCompleted.count) · study time: \(DateMath.minutesText(studyMinutes))\n"
        s += "- Workouts: \(workouts)\n\n"
        if !highlights.isEmpty {
            s += "## Journal highlights\n\n"
            for e in highlights { s += "- **\(e.date.formatted(date: .abbreviated, time: .omitted))** — \(e.displayTitle)\n" }
            s += "\n"
        }
        if !trips.isEmpty { s += "## Journeys\n\n" + trips.map { "- \($0.title)\($0.destination.isEmpty ? "" : " — \($0.destination)")" }.joined(separator: "\n") + "\n\n" }
        if !countries.isEmpty { s += "## Countries\n\n" + countries.joined(separator: ", ") + "\n\n" }
        if !projectsCompleted.isEmpty { s += "## Creations\n\n" + projectsCompleted.map { "- \($0.name)" }.joined(separator: "\n") + "\n\n" }
        if !goalsCompleted.isEmpty { s += "## Learned\n\n" + goalsCompleted.map { "- \($0.skillName)" }.joined(separator: "\n") + "\n\n" }
        if !people.isEmpty { s += "## People\n\n" + people.map(\.name).joined(separator: ", ") + "\n\n" }
        if !memories.isEmpty { s += "## Memories\n\n" + memories.map { "- \($0.date.formatted(date: .abbreviated, time: .omitted)) — \($0.displayTitle)" }.joined(separator: "\n") + "\n" }
        return s
    }
}

struct YearbookView: View {
    let year: Int
    @Environment(\.modelContext) private var context
    @Environment(\.displayScale) private var displayScale
    @State private var data: YearbookData?
    @State private var pdfURL: URL?
    @State private var mdURL: URL?
    @State private var exporting = false

    var body: some View {
        ScrollView {
            if let data {
                if data.isEmpty {
                    EmptyStateView(symbol: "book.pages", title: "Nothing recorded for \(String(year)) yet",
                                   message: "Your yearbook is built only from what you write and save. It never invents memories.")
                } else {
                    YearbookContent(data: data).padding()
                }
            } else {
                ProgressView().padding(.top, 80)
            }
        }
        .screenBackground()
        .navigationTitle("Yearbook \(String(year))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if let pdfURL { ShareLink(item: pdfURL) { Label("Share as PDF", systemImage: "doc.richtext") } }
                    if let mdURL { ShareLink(item: mdURL) { Label("Share as Markdown", systemImage: "doc.text") } }
                    if pdfURL == nil { Button { makeExports() } label: { Label(exporting ? "Preparing…" : "Prepare export", systemImage: "square.and.arrow.up") } }
                } label: { Image(systemName: "square.and.arrow.up") }
                .disabled(data?.isEmpty ?? true)
                .accessibilityLabel("Export yearbook")
            }
        }
        .task {
            data = YearbookData.build(year: year, context: context)
            makeExports()
        }
    }

    /// Renders the yearbook to a single-page PDF with ImageRenderer.
    @MainActor
    private func makeExports() {
        guard let data, !data.isEmpty, !exporting else { return }
        exporting = true
        defer { exporting = false }
        let dir = FileManager.default.temporaryDirectory
        let md = dir.appendingPathComponent("TXAWPAY Yearbook \(year).md")
        try? Data(data.markdown().utf8).write(to: md, options: .atomic)
        mdURL = md

        let renderer = ImageRenderer(content:
            YearbookContent(data: data, forExport: true)
                .frame(width: 612)
                .padding(24)
                .background(Theme.background)
                .environment(\.colorScheme, .light)
        )
        renderer.scale = displayScale
        let pdf = dir.appendingPathComponent("TXAWPAY Yearbook \(year).pdf")
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: size)
            guard let ctx = CGContext(pdf as CFURL, mediaBox: &box, nil) else { return }
            ctx.beginPDFPage(nil)
            draw(ctx)
            ctx.endPDFPage()
            ctx.closePDF()
        }
        pdfURL = FileManager.default.fileExists(atPath: pdf.path) ? pdf : nil
    }
}

struct YearbookContent: View {
    let data: YearbookData
    var forExport = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    AppMark(size: 44)
                    Text("TXAWPAY Yearbook").font(Typo.eyebrow).tracking(2).foregroundStyle(Theme.gold)
                }
                Text(String(data.year)).font(.system(size: 64, weight: .semibold, design: .serif)).foregroundStyle(Theme.textPrimary)
                GoldDivider()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                StatTile(value: "\(data.entryCount)", label: "Journal entries", symbol: "book.closed")
                StatTile(value: "\(data.wordCount)", label: "Words written", symbol: "text.quote", tint: Theme.earth)
                StatTile(value: "\(data.trips.count)", label: "Journeys", symbol: "airplane", tint: Theme.jungle)
                StatTile(value: "\(data.countries.count)", label: "Countries", symbol: "globe.americas", tint: Theme.gold)
                StatTile(value: "\(data.projectsCompleted.count)", label: "Projects completed", symbol: "checkmark.seal", tint: Theme.gold)
                StatTile(value: DateMath.minutesText(data.studyMinutes), label: "Time learning", symbol: "graduationcap", tint: Color(hex: 0x6F6A9A))
            }

            if !data.topMoods.isEmpty {
                section("How the year felt") {
                    HStack { ForEach(data.topMoods, id: \.0) { m, c in Chip(text: "\(m.label) · \(c)", symbol: m.symbol, color: m.tint) } }
                }
            }
            if !data.photos.isEmpty && !forExport {
                section("Selected photographs") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                        ForEach(data.photos) { p in MediaThumbnail(fileName: p.fileName, maxPixel: 400, cornerRadius: 8).aspectRatio(1, contentMode: .fill) }
                    }
                }
            }
            if forExport && !data.photos.isEmpty {
                // ImageRenderer can't run async loaders; draw thumbnails synchronously for export.
                section("Selected photographs") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                        ForEach(data.photos) { p in
                            if let img = MediaStore.shared.thumbnail(for: p.fileName, maxPixel: 300) {
                                Image(uiImage: img).resizable().scaledToFill().frame(height: 120).clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }
            if !data.highlights.isEmpty {
                section("Journal highlights") {
                    ForEach(data.highlights.prefix(forExport ? 20 : 12)) { e in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(e.date.formatted(.dateTime.day().month(.wide))).font(Typo.caption).foregroundStyle(Theme.gold)
                            Text(e.displayTitle).font(Typo.headline).foregroundStyle(Theme.textPrimary)
                            if !e.body.isEmpty { Text(e.excerpt).font(Typo.caption).foregroundStyle(Theme.textSecondary).lineLimit(2) }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            if !data.trips.isEmpty || !data.countries.isEmpty {
                section("Journeys") {
                    ForEach(data.trips) { t in
                        Label("\(t.title)\(t.destination.isEmpty ? "" : " — \(t.destination)")", systemImage: "airplane").foregroundStyle(Theme.textPrimary)
                    }
                    if !data.countries.isEmpty { Text(data.countries.joined(separator: "  ")).font(Typo.callout).foregroundStyle(Theme.textSecondary) }
                    if !data.cities.isEmpty { Text("Cities: " + data.cities.joined(separator: ", ")).font(Typo.caption).foregroundStyle(Theme.textSecondary) }
                }
            }
            if !data.projectsCompleted.isEmpty || data.projectsStarted > 0 {
                section("Creations") {
                    ForEach(data.projectsCompleted) { p in Label(p.name, systemImage: "checkmark.seal").foregroundStyle(Theme.textPrimary) }
                    Text("\(data.projectsStarted) project\(data.projectsStarted == 1 ? "" : "s") started this year").font(Typo.caption).foregroundStyle(Theme.textSecondary)
                }
            }
            if !data.goalsCompleted.isEmpty || data.studyMinutes > 0 {
                section("Learning") {
                    ForEach(data.goalsCompleted) { g in Label(g.skillName, systemImage: g.category.symbol).foregroundStyle(Theme.textPrimary) }
                    Text("\(DateMath.minutesText(data.studyMinutes)) of study · \(data.workouts) workouts").font(Typo.caption).foregroundStyle(Theme.textSecondary)
                }
            }
            if !data.people.isEmpty {
                section("People in your story") {
                    FlowLayout { ForEach(data.people) { p in Chip(text: p.name, symbol: "person", color: Theme.earth) } }
                }
            }
            if !data.memories.isEmpty {
                section("Memories") {
                    ForEach(data.memories.prefix(15)) { m in
                        HStack {
                            Image(systemName: m.kind.symbol).foregroundStyle(Theme.accent)
                            Text(m.displayTitle).foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Text(m.date.formatted(.dateTime.day().month(.abbreviated))).font(Typo.caption).foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
            }
            Text("Compiled from your own records in TXAWPAY.").font(Typo.caption).foregroundStyle(Theme.textTertiary)
        }
    }

    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(title).font(Typo.title3).foregroundStyle(Theme.textPrimary)
            content()
        }
        .cardStyle()
    }
}
