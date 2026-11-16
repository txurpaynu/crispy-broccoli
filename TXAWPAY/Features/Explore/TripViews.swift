import SwiftUI
import SwiftData
import MapKit
import PhotosUI

struct TripDetailView: View {
    @Bindable var trip: TravelTrip
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: AppRouter
    @State private var editing = false
    @State private var addingPlace = false
    @State private var confirmDelete = false
    @State private var photoItems: [PhotosPickerItem] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                header
                if !trip.destination.isEmpty || trip.hasDates {
                    HStack(spacing: Theme.Spacing.s) {
                        if !trip.destination.isEmpty { Chip(text: trip.destination, symbol: "mappin", color: Theme.earth) }
                        Chip(text: trip.status.label, symbol: trip.status.symbol)
                        if trip.hasDates {
                            let days = (Calendar.current.dateComponents([.day], from: trip.startDate, to: trip.endDate).day ?? 0) + 1
                            Chip(text: "\(days) days", symbol: "calendar", color: Theme.gold)
                        }
                    }
                }
                if !trip.itinerary.isEmpty { textCard("Itinerary", "list.bullet", trip.itinerary) }
                placesSection
                journalSection
                photosSection
                if !trip.notes.isEmpty { textCard("Notes", "note.text", trip.notes) }
                if !trip.memoriesText.isEmpty { textCard("Travel memories", "sparkles", trip.memoriesText) }
                memoriesSection
            }
            .padding()
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(trip.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { editing = true } label: { Label("Edit trip", systemImage: "pencil") }
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Delete trip", systemImage: "trash") }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(isPresented: $editing) { TripEditor(trip: trip) }
        .sheet(isPresented: $addingPlace) { PlaceEditor(place: nil, trip: trip) }
        .confirmationDialog("Delete this trip?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete trip", role: .destructive) {
                for a in trip.attachments ?? [] { MediaStore.shared.delete(a.fileName) }
                MediaStore.shared.delete(trip.coverFileName)
                RecentsStore.shared.remove(id: trip.id)
                context.delete(trip)
                try? context.save()
                dismiss()
            }
        } message: {
            Text("Its places and photos are removed. Linked journal entries and memories are kept.")
        }
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                let (imported, _) = await MediaImporter.importItems(items)
                for m in imported {
                    let a = JournalAttachment(kind: m.kind, fileName: m.fileName, originalFileName: m.originalName)
                    context.insert(a); a.trip = trip
                }
                trip.modifiedAt = Date()
                try? context.save()
                photoItems = []
            }
        }
        .onAppear { RecentsStore.shared.record(.trip, id: trip.id, title: trip.title) }
    }

    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            if !trip.coverFileName.isEmpty {
                MediaThumbnail(fileName: trip.coverFileName, maxPixel: 1200, cornerRadius: Theme.Radius.large).frame(height: 200)
            } else {
                Image("HeroLandscape").resizable().scaledToFill().frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
            }
            LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
            VStack(alignment: .leading) {
                if !trip.countryCode.isEmpty { Text(CountryInfo.flag(for: trip.countryCode)).font(.largeTitle) }
                Text(trip.title).font(Typo.largeTitle).foregroundStyle(.white)
                if trip.hasDates {
                    Text("\(trip.startDate.formatted(date: .long, time: .omitted)) – \(trip.endDate.formatted(date: .long, time: .omitted))")
                        .font(Typo.caption).foregroundStyle(.white.opacity(0.85))
                }
            }
            .padding()
        }
        .frame(height: 200)
    }

    private func textCard(_ title: String, _ symbol: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol).font(Typo.eyebrow).foregroundStyle(Theme.gold)
            Text(text).font(Typo.bodySerif).foregroundStyle(Theme.textPrimary)
        }
        .cardStyle()
    }

    private var placesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(title: "Places", actionTitle: "Add") { addingPlace = true }
            let places = trip.sortedPlaces
            if places.isEmpty {
                Text("Add the places you visited or plan to visit on this trip.").font(Typo.callout).foregroundStyle(Theme.textSecondary)
            } else {
                if places.contains(where: \.hasCoordinate) {
                    Map {
                        ForEach(places.filter(\.hasCoordinate)) { p in
                            Marker(p.name, coordinate: CLLocationCoordinate2D(latitude: p.latitude!, longitude: p.longitude!)).tint(p.status.tint)
                        }
                    }
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
                    .allowsHitTesting(false)
                }
                ForEach(places) { p in
                    NavigationLink(value: p) {
                        HStack {
                            Image(systemName: p.kind.symbol).foregroundStyle(p.status.tint)
                            Text(p.name).foregroundStyle(Theme.textPrimary)
                            Spacer()
                            if let d = p.visitedDate { Text(d.formatted(date: .abbreviated, time: .omitted)).font(Typo.caption).foregroundStyle(Theme.textSecondary) }
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .cardStyle()
    }

    private var journalSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(title: "Journal", actionTitle: "Write") { router.open(TripEntryRoute(trip: trip)) }
            let entries = (trip.journalEntries ?? []).sorted { $0.date < $1.date }
            if entries.isEmpty {
                Text("Entries linked to this trip appear here, in travel order.").font(Typo.callout).foregroundStyle(Theme.textSecondary)
            }
            ForEach(entries) { e in
                NavigationLink(value: e) { JournalEntryCard(entry: e) }.buttonStyle(.plain)
            }
        }
    }

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                SectionHeader(title: "Photos")
                PhotosPicker(selection: $photoItems, maxSelectionCount: 30, matching: .any(of: [.images, .videos])) {
                    Label("Add", systemImage: "plus").font(Typo.callout.weight(.medium))
                }
            }
            let entryPhotos = (trip.journalEntries ?? []).flatMap(\.sortedAttachments)
            let all = (trip.attachments ?? []).sorted { $0.createdAt < $1.createdAt } + entryPhotos
            if all.isEmpty {
                Text("Add photos from this trip, or attach them to its journal entries.").font(Typo.callout).foregroundStyle(Theme.textSecondary)
            } else {
                AttachmentGrid(attachments: all) { a in
                    guard a.trip?.id == trip.id else { return } // entry photos are managed from the entry
                    MediaStore.shared.delete(a.fileName); context.delete(a); try? context.save()
                }
            }
        }
    }

    @ViewBuilder
    private var memoriesSection: some View {
        let memories = trip.memories ?? []
        if !memories.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                SectionHeader(title: "Memories")
                ForEach(memories) { m in
                    NavigationLink(value: m) { NavRow(symbol: m.kind.symbol, title: m.displayTitle, subtitle: m.date.formatted(date: .abbreviated, time: .omitted)) }
                        .buttonStyle(.plain)
                }
            }
            .cardStyle()
        }
    }
}

/// Opens a new journal entry already linked to a trip.
struct TripEntryRoute: Hashable { let trip: TravelTrip }

struct TripEditor: View {
    let trip: TravelTrip?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var destination = ""
    @State private var countryCode = ""
    @State private var hasDates = true
    @State private var start = Date()
    @State private var end = Date().addingTimeInterval(86400 * 5)
    @State private var status = TripStatus.planned
    @State private var itinerary = ""
    @State private var notes = ""
    @State private var memoriesText = ""
    @State private var cover = ""

    private var error: String? {
        if title.trimmingCharacters(in: .whitespaces).isEmpty { return "Give the trip a name." }
        if hasDates && end < start { return "The end date is before the start date." }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Trip name (e.g. Japan in spring)", text: $title)
                    TextField("Destination", text: $destination)
                    Picker("Country", selection: $countryCode) {
                        Text("None").tag("")
                        ForEach(CountryInfo.all, id: \.code) { Text("\(CountryInfo.flag(for: $0.code)) \($0.name)").tag($0.code) }
                    }
                    Picker("Status", selection: $status) { ForEach(TripStatus.allCases) { Label($0.label, systemImage: $0.symbol).tag($0) } }
                }
                Section {
                    Toggle("Dates", isOn: $hasDates)
                    if hasDates {
                        DatePicker("Start", selection: $start, displayedComponents: .date)
                        DatePicker("End", selection: $end, in: start..., displayedComponents: .date)
                    }
                }
                Section("Cover photo") {
                    SinglePhotoPicker(fileName: $cover) {
                        if cover.isEmpty { Label("Choose cover", systemImage: "photo") }
                        else { MediaThumbnail(fileName: cover, maxPixel: 600).frame(height: 120) }
                    }
                }
                Section("Itinerary") { TextField("Day by day plan", text: $itinerary, axis: .vertical).lineLimit(3...12) }
                Section("Notes") { TextField("Notes", text: $notes, axis: .vertical).lineLimit(2...8) }
                Section("Travel memories") { TextField("What you want to remember", text: $memoriesText, axis: .vertical).lineLimit(2...8) }
                if let error, !title.isEmpty { ValidationHint(message: error) }
            }
            .navigationTitle(trip == nil ? "New trip" : "Edit trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(error != nil) }
            }
            .onAppear {
                guard let trip else { return }
                title = trip.title; destination = trip.destination; countryCode = trip.countryCode; hasDates = trip.hasDates
                start = trip.startDate; end = trip.endDate; status = trip.status; itinerary = trip.itinerary; notes = trip.notes
                memoriesText = trip.memoriesText; cover = trip.coverFileName
            }
        }
    }

    private func save() {
        let t = trip ?? TravelTrip(title: "")
        t.title = title.trimmingCharacters(in: .whitespaces)
        t.destination = destination; t.countryCode = countryCode; t.hasDates = hasDates
        t.startDate = start; t.endDate = max(start, end); t.status = status
        t.itinerary = itinerary; t.notes = notes; t.memoriesText = memoriesText
        if t.coverFileName != cover, !t.coverFileName.isEmpty, trip != nil { /* old cover already deleted by picker */ }
        t.coverFileName = cover
        t.modifiedAt = Date()
        if trip == nil { context.insert(t) }
        // A completed trip with a country counts that country as visited.
        if status == .completed, !countryCode.isEmpty {
            let existing = (try? context.fetch(FetchDescriptor<TravelDestination>()))?.first { $0.kind == .country && $0.countryCode == countryCode }
            if let existing { existing.status = .visited }
            else {
                let c = TravelDestination(name: CountryInfo.name(for: countryCode), kind: .country, status: .visited)
                c.countryCode = countryCode; c.country = c.name; c.visitedDate = start
                context.insert(c)
            }
        }
        try? context.save()
        dismiss()
    }
}

// MARK: - Places

struct PlaceDetailView: View {
    @Bindable var place: TravelDestination
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var confirmDelete = false
    @State private var photoItems: [PhotosPickerItem] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                if place.hasCoordinate {
                    Map(initialPosition: .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: place.latitude!, longitude: place.longitude!),
                                                                     span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))) {
                        Marker(place.name, coordinate: CLLocationCoordinate2D(latitude: place.latitude!, longitude: place.longitude!)).tint(place.status.tint)
                    }
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large))
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(place.kind == .country ? "\(CountryInfo.flag(for: place.countryCode)) \(place.name)" : place.name)
                        .font(Typo.largeTitle).foregroundStyle(Theme.textPrimary)
                    HStack {
                        Chip(text: place.status.label, color: place.status.tint)
                        Chip(text: place.kind.label, symbol: place.kind.symbol, color: Theme.textSecondary)
                        if let d = place.visitedDate { Chip(text: d.formatted(date: .abbreviated, time: .omitted), symbol: "calendar", color: Theme.gold) }
                    }
                    let line = [place.city, place.country].filter { !$0.isEmpty && $0 != place.name }.joined(separator: ", ")
                    if !line.isEmpty { Text(line).foregroundStyle(Theme.textSecondary) }
                }
                if let trip = place.trip {
                    NavigationLink(value: trip) { NavRow(symbol: "airplane", title: trip.title, subtitle: "Part of trip") }
                        .buttonStyle(.plain).cardStyle()
                }
                if !place.notes.isEmpty {
                    Text(place.notes).font(Typo.bodySerif).foregroundStyle(Theme.textPrimary).cardStyle()
                }
                HStack {
                    SectionHeader(title: "Photos")
                    PhotosPicker(selection: $photoItems, maxSelectionCount: 20, matching: .images) {
                        Label("Add", systemImage: "plus").font(Typo.callout.weight(.medium))
                    }
                }
                let photos = (place.attachments ?? []).sorted { $0.createdAt < $1.createdAt }
                if photos.isEmpty {
                    Text("No photos yet.").font(Typo.callout).foregroundStyle(Theme.textSecondary)
                } else {
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
        .sheet(isPresented: $editing) { PlaceEditor(place: place, trip: place.trip) }
        .confirmationDialog("Delete this place?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                for a in place.attachments ?? [] { MediaStore.shared.delete(a.fileName) }
                context.delete(place); try? context.save(); dismiss()
            }
        }
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                let (imported, _) = await MediaImporter.importItems(items)
                for m in imported {
                    let a = JournalAttachment(kind: m.kind, fileName: m.fileName, originalFileName: m.originalName)
                    context.insert(a); a.place = place
                }
                try? context.save()
                photoItems = []
            }
        }
    }
}

struct PlaceEditor: View {
    let place: TravelDestination?
    let trip: TravelTrip?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var city = ""
    @State private var country = ""
    @State private var countryCode = ""
    @State private var kind = PlaceKind.place
    @State private var status = PlaceStatus.saved
    @State private var notes = ""
    @State private var hasDate = false
    @State private var visited = Date()
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var searching = false
    @StateObject private var location = LocationService()
    @State private var locationError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Find on map") {
                    HStack {
                        TextField("Search a place or address", text: $query).onSubmit(search).submitLabel(.search)
                        if searching { ProgressView() }
                    }
                    ForEach(results, id: \.self) { item in
                        Button {
                            apply(item)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(item.name ?? "Place").foregroundStyle(Theme.textPrimary)
                                Text(item.placemark.title ?? "").font(Typo.caption).foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                    Button {
                        Task {
                            do {
                                let p = try await location.currentPlace()
                                coordinate = p.coordinate
                                if name.isEmpty { name = p.name }
                                city = p.city; country = p.country; countryCode = p.countryCode
                            } catch { locationError = error.localizedDescription }
                        }
                    } label: { Label("Use current location", systemImage: "location") }
                    if let locationError { ValidationHint(message: locationError) }
                    if coordinate != nil { Label("Location set on map", systemImage: "checkmark.circle").foregroundStyle(Theme.jungle) }
                }
                Section {
                    TextField("Name", text: $name)
                    TextField("City", text: $city)
                    TextField("Country", text: $country)
                    Picker("Type", selection: $kind) { ForEach(PlaceKind.allCases) { Text($0.label).tag($0) } }
                    Picker("Status", selection: $status) { ForEach(PlaceStatus.allCases) { Text($0.label).tag($0) } }
                    Toggle("Visit date", isOn: $hasDate)
                    if hasDate { DatePicker("Visited", selection: $visited, displayedComponents: .date) }
                }
                Section("Notes") { TextField("Notes", text: $notes, axis: .vertical).lineLimit(2...8) }
            }
            .navigationTitle(place == nil ? "New place" : "Edit place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                guard let place else { if trip != nil { status = .visited }; return }
                name = place.name; city = place.city; country = place.country; countryCode = place.countryCode
                kind = place.kind; status = place.status; notes = place.notes
                hasDate = place.visitedDate != nil; visited = place.visitedDate ?? Date()
                if let lat = place.latitude, let lon = place.longitude { coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon) }
            }
        }
    }

    private func search() {
        guard !query.isEmpty else { return }
        searching = true
        Task {
            results = await LocationService.search(query)
            if results.isEmpty { locationError = "No results. Map search needs an internet connection." } else { locationError = nil }
            searching = false
        }
    }

    private func apply(_ item: MKMapItem) {
        name = item.name ?? name
        city = item.placemark.locality ?? ""
        country = item.placemark.country ?? ""
        countryCode = item.placemark.isoCountryCode ?? ""
        coordinate = item.placemark.coordinate
        results = []
    }

    private func save() {
        let p = place ?? TravelDestination(name: "")
        p.name = name.trimmingCharacters(in: .whitespaces); p.city = city; p.country = country; p.countryCode = countryCode
        p.kind = kind; p.status = status; p.notes = notes; p.visitedDate = hasDate ? visited : nil
        p.latitude = coordinate?.latitude; p.longitude = coordinate?.longitude
        if place == nil { context.insert(p); p.trip = trip }
        try? context.save()
        dismiss()
    }
}
