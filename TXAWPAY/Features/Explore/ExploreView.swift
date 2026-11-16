import SwiftUI
import SwiftData
import MapKit

struct ExploreView: View {
    enum ExploreSection: String, CaseIterable, Identifiable {
        case trips = "Trips", places = "Places", countries = "Countries"
        var id: String { rawValue }
    }

    @Query(sort: \TravelTrip.startDate, order: .reverse) private var trips: [TravelTrip]
    @Query(sort: \TravelDestination.createdAt, order: .reverse) private var places: [TravelDestination]
    @EnvironmentObject private var router: AppRouter
    @State private var section: ExploreSection = .trips
    @State private var newTrip = false
    @State private var newPlace = false
    @State private var newCountry = false
    @State private var camera: MapCameraPosition = .automatic
    @State private var mapExpanded = false

    private var mappedPlaces: [TravelDestination] { places.filter(\.hasCoordinate) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                worldMap
                stats
                Picker("Section", selection: $section) {
                    ForEach(ExploreSection.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                switch section {
                case .trips: tripsList
                case .places: placesList
                case .countries: CountriesSection(places: places, onAdd: { newCountry = true })
                }
            }
            .padding(.vertical)
        }
        .screenBackground()
        .navigationTitle("Explore")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { newTrip = true } label: { Label("New trip", systemImage: "airplane") }
                    Button { newPlace = true } label: { Label("New place", systemImage: "mappin.and.ellipse") }
                    Button { newCountry = true } label: { Label("Mark a country", systemImage: "globe.americas") }
                } label: { Image(systemName: "plus") }
                .accessibilityLabel("Add")
            }
        }
        .sheet(isPresented: $newTrip) { TripEditor(trip: nil) }
        .sheet(isPresented: $newPlace) { PlaceEditor(place: nil, trip: nil) }
        .sheet(isPresented: $newCountry) { CountryMarker() }
        .fullScreenCover(isPresented: $mapExpanded) { FullMapView(places: mappedPlaces) }
    }

    private var worldMap: some View {
        ZStack(alignment: .bottomTrailing) {
            Map(position: $camera) {
                ForEach(mappedPlaces) { p in
                    Annotation(p.name, coordinate: CLLocationCoordinate2D(latitude: p.latitude!, longitude: p.longitude!)) {
                        PlacePin(status: p.status)
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous).strokeBorder(Theme.gold.opacity(0.4)))

            Button { mapExpanded = true } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .padding(10)
                    .background(.regularMaterial, in: Circle())
            }
            .padding(10)
            .accessibilityLabel("Open full map")
        }
        .padding(.horizontal)
        .overlay {
            if mappedPlaces.isEmpty {
                Text("Places you save appear on the map")
                    .font(Typo.caption.weight(.medium))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
            }
        }
    }

    private var stats: some View {
        let visitedCountries = Set(places.filter { $0.status == .visited && !$0.countryCode.isEmpty }.map(\.countryCode))
            .union(trips.filter { $0.status == .completed && !$0.countryCode.isEmpty }.map(\.countryCode))
        let cities = Set(places.filter { $0.status == .visited && ($0.kind == .city || !$0.city.isEmpty) }
            .map { $0.kind == .city ? $0.name : $0.city })
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.s) {
                StatTile(value: "\(visitedCountries.count)", label: "Countries visited", symbol: "globe.americas").frame(width: 130)
                StatTile(value: "\(cities.count)", label: "Cities visited", symbol: "building.2", tint: Theme.earth).frame(width: 130)
                StatTile(value: "\(trips.count)", label: "Trips recorded", symbol: "airplane", tint: Theme.jungle).frame(width: 130)
                StatTile(value: "\(trips.filter(\.isUpcoming).count)", label: "Upcoming trips", symbol: "calendar", tint: Theme.accent).frame(width: 130)
                StatTile(value: "\(places.filter { $0.status == .wishlist }.count)", label: "Wishlist", symbol: "star", tint: Theme.gold).frame(width: 130)
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var tripsList: some View {
        if trips.isEmpty {
            EmptyStateView(symbol: "airplane", title: "No trips yet",
                           message: "Record journeys you've taken or plan the ones you're dreaming about.",
                           actionTitle: "Add a trip") { newTrip = true }
        } else {
            LazyVStack(spacing: Theme.Spacing.m) {
                ForEach(trips) { trip in
                    NavigationLink(value: trip) { TripCard(trip: trip) }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var placesList: some View {
        if places.filter({ $0.kind != .country }).isEmpty {
            EmptyStateView(symbol: "mappin.and.ellipse", title: "No places yet",
                           message: "Save cities and special spots — places you've been or want to see.",
                           actionTitle: "Add a place") { newPlace = true }
        } else {
            LazyVStack(spacing: Theme.Spacing.s) {
                ForEach(places.filter { $0.kind != .country }) { p in
                    NavigationLink(value: p) {
                        HStack(spacing: Theme.Spacing.m) {
                            IconBadge(symbol: p.kind.symbol, tint: p.status.tint, size: 38)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.name).font(Typo.headline).foregroundStyle(Theme.textPrimary)
                                Text([p.city, p.country].filter { !$0.isEmpty }.joined(separator: ", ").ifEmpty(p.status.label))
                                    .font(Typo.caption).foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            Chip(text: p.status.label, color: p.status.tint)
                        }
                        .cardStyle(padding: Theme.Spacing.m)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }
}

extension String {
    func ifEmpty(_ fallback: String) -> String { isEmpty ? fallback : self }
}

struct PlacePin: View {
    let status: PlaceStatus
    var body: some View {
        Image(systemName: status == .wishlist ? "star.fill" : "mappin")
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 26, height: 26)
            .background(Circle().fill(status.tint))
            .overlay(Circle().strokeBorder(.white, lineWidth: 2))
            .shadow(radius: 3)
    }
}

struct TripCard: View {
    let trip: TravelTrip
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                if !trip.coverFileName.isEmpty {
                    MediaThumbnail(fileName: trip.coverFileName, maxPixel: 900, cornerRadius: 0)
                        .frame(height: 140)
                } else {
                    Image("HydroTexture").resizable().scaledToFill().frame(height: 140).clipped()
                }
                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 2) {
                    Text(trip.countryCode.isEmpty ? "" : CountryInfo.flag(for: trip.countryCode))
                    Text(trip.title).font(Typo.title3).foregroundStyle(.white)
                }
                .padding()
            }
            .frame(height: 140)
            .clipped()
            HStack {
                Label(trip.status.label, systemImage: trip.status.symbol)
                    .foregroundStyle(Theme.accent)
                Spacer()
                if trip.hasDates {
                    Text("\(trip.startDate.formatted(date: .abbreviated, time: .omitted)) – \(trip.endDate.formatted(date: .abbreviated, time: .omitted))")
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .font(Typo.caption)
            .padding(Theme.Spacing.m)
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
        .accessibilityElement(children: .combine)
    }
}

struct FullMapView: View {
    let places: [TravelDestination]
    @Environment(\.dismiss) private var dismiss
    @State private var selected: TravelDestination?
    @State private var camera: MapCameraPosition = .automatic

    var body: some View {
        NavigationStack {
            Map(position: $camera, selection: $selected) {
                ForEach(places) { p in
                    Marker(p.name, systemImage: p.status == .wishlist ? "star.fill" : "mappin",
                           coordinate: CLLocationCoordinate2D(latitude: p.latitude!, longitude: p.longitude!))
                        .tint(p.status.tint)
                        .tag(p)
                }
            }
            .mapControls { MapCompass(); MapScaleView() }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Your map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .safeAreaInset(edge: .bottom) {
                if let selected {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selected.name).font(Typo.headline)
                        Text(selected.status.label).font(Typo.caption).foregroundStyle(Theme.textSecondary)
                        if !selected.notes.isEmpty { Text(selected.notes).font(Typo.callout).lineLimit(3) }
                    }
                    .cardStyle()
                    .padding()
                }
            }
        }
    }
}

// MARK: - Countries

struct CountriesSection: View {
    let places: [TravelDestination]
    let onAdd: () -> Void
    @Environment(\.modelContext) private var context

    var body: some View {
        let countries = places.filter { $0.kind == .country }
        let visited = countries.filter { $0.status == .visited }
        let wish = countries.filter { $0.status == .wishlist }
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            if countries.isEmpty {
                EmptyStateView(symbol: "globe.europe.africa", title: "Mark your world",
                               message: "Mark countries you've visited and the ones you dream of.", actionTitle: "Mark a country", action: onAdd)
            } else {
                group("Visited", visited)
                group("Want to visit", wish)
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func group(_ title: String, _ list: [TravelDestination]) -> some View {
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                SectionHeader(title: title, subtitle: "\(list.count)")
                FlowLayout(spacing: 8) {
                    ForEach(list.sorted { $0.name < $1.name }) { c in
                        NavigationLink(value: c) {
                            Text("\(CountryInfo.flag(for: c.countryCode)) \(c.name)")
                                .font(Typo.callout)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(Capsule().fill(Theme.surface))
                                .foregroundStyle(Theme.textPrimary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct CountryMarker: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var places: [TravelDestination]
    @State private var search = ""
    @State private var status = PlaceStatus.visited

    var body: some View {
        NavigationStack {
            List {
                Picker("Mark as", selection: $status) {
                    Text("Visited").tag(PlaceStatus.visited)
                    Text("Want to visit").tag(PlaceStatus.wishlist)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                ForEach(CountryInfo.all.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }, id: \.code) { c in
                    let existing = places.first { $0.kind == .country && $0.countryCode == c.code }
                    Button {
                        if let existing {
                            existing.status = status
                        } else {
                            let p = TravelDestination(name: c.name, kind: .country, status: status)
                            p.countryCode = c.code; p.country = c.name
                            context.insert(p)
                        }
                        try? context.save()
                    } label: {
                        HStack {
                            Text("\(CountryInfo.flag(for: c.code))  \(c.name)").foregroundStyle(Theme.textPrimary)
                            Spacer()
                            if let existing { Chip(text: existing.status.label, color: existing.status.tint) }
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "Search countries")
            .navigationTitle("Mark countries")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
