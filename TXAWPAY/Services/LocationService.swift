import Foundation
import CoreLocation
import MapKit

/// One-shot "use my current location" with reverse geocoding.
/// Location is only requested when the user taps a location button.
@MainActor
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    struct Place: Equatable {
        var name: String
        var city: String
        var country: String
        var countryCode: String
        var coordinate: CLLocationCoordinate2D

        static func == (a: Place, b: Place) -> Bool {
            a.name == b.name && a.coordinate.latitude == b.coordinate.latitude && a.coordinate.longitude == b.coordinate.longitude
        }
    }

    enum LocationError: LocalizedError {
        case denied, unavailable
        var errorDescription: String? {
            switch self {
            case .denied: "Location access is off. You can allow it in Settings › TXAWPAY › Location."
            case .unavailable: "Your location couldn't be determined right now."
            }
        }
    }

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?
    @Published var isLocating = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func currentPlace() async throws -> Place {
        isLocating = true
        defer { isLocating = false }
        let location = try await requestLocation()
        return await Self.describe(location.coordinate)
    }

    private func requestLocation() async throws -> CLLocation {
        switch manager.authorizationStatus {
        case .denied, .restricted: throw LocationError.denied
        default: break
        }
        return try await withCheckedThrowingContinuation { cont in
            continuation?.resume(throwing: LocationError.unavailable)
            continuation = cont
            if manager.authorizationStatus == .notDetermined {
                manager.requestWhenInUseAuthorization()
            } else {
                manager.requestLocation()
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                if self.continuation != nil { manager.requestLocation() }
            case .denied, .restricted:
                self.continuation?.resume(throwing: LocationError.denied)
                self.continuation = nil
            default: break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let loc = locations.last else { return }
            self.continuation?.resume(returning: loc)
            self.continuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.continuation?.resume(throwing: LocationError.unavailable)
            self.continuation = nil
        }
    }

    /// Reverse geocodes a coordinate (needs network; falls back to coordinates offline).
    static func describe(_ coordinate: CLLocationCoordinate2D) async -> Place {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        if let mark = try? await CLGeocoder().reverseGeocodeLocation(location).first {
            let name = mark.name ?? mark.locality ?? "Pinned place"
            return Place(name: name, city: mark.locality ?? "", country: mark.country ?? "",
                         countryCode: mark.isoCountryCode ?? "", coordinate: coordinate)
        }
        return Place(name: String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude),
                     city: "", country: "", countryCode: "", coordinate: coordinate)
    }

    /// Searches places by name with MapKit (needs network).
    static func search(_ query: String, near region: MKCoordinateRegion? = nil) async -> [MKMapItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let region { request.region = region }
        return (try? await MKLocalSearch(request: request).start().mapItems) ?? []
    }
}

enum CountryInfo {
    /// All ISO region codes with localized names, sorted by name.
    static let all: [(code: String, name: String)] = {
        Locale.Region.isoRegions
            .filter { $0.identifier.count == 2 && $0.identifier.allSatisfy(\.isLetter) }
            .compactMap { region in
                guard let name = Locale.current.localizedString(forRegionCode: region.identifier) else { return nil }
                return (region.identifier, name)
            }
            .sorted { $0.1 < $1.1 }
    }()

    static func name(for code: String) -> String {
        Locale.current.localizedString(forRegionCode: code) ?? code
    }

    static func flag(for code: String) -> String {
        guard code.count == 2 else { return "🏳️" }
        let base: UInt32 = 127397
        return code.uppercased().unicodeScalars.compactMap { UnicodeScalar(base + $0.value) }.map(String.init).joined()
    }
}
