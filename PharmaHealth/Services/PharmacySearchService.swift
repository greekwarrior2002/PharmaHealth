import Foundation
import CoreLocation
import MapKit

/// A lightweight value type representing a pharmacy returned by
/// `MKLocalSearch` or by a manual address-based search. Independent of
/// SwiftData so it can be moved through the UI before the user decides to
/// save it.
struct PharmacySearchResult: Identifiable, Equatable, Hashable {
    let id: UUID
    let name: String
    let address: String
    let phone: String
    let coordinate: CLLocationCoordinate2D?
    let distanceMeters: Double?

    init(
        id: UUID = UUID(),
        name: String,
        address: String,
        phone: String = "",
        coordinate: CLLocationCoordinate2D? = nil,
        distanceMeters: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.phone = phone
        self.coordinate = coordinate
        self.distanceMeters = distanceMeters
    }

    static func == (lhs: PharmacySearchResult, rhs: PharmacySearchResult) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension PharmacySearchResult {
    /// User-facing distance string. Locale-aware via `MeasurementFormatter`.
    var displayDistance: String? {
        guard let distanceMeters else { return nil }
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.numberFormatter.maximumFractionDigits = 1
        let measurement = Measurement(value: distanceMeters, unit: UnitLength.meters)
        return formatter.string(from: measurement)
    }
}

/// Authorization state surfaced to the UI without leaking CoreLocation types.
enum PharmacyLocationAuthorization {
    case notDetermined
    case denied
    case restricted
    case authorized
}

/// Encapsulates CoreLocation + MKLocalSearch behind a SwiftUI-friendly,
/// `@MainActor` observable API. Keeps the views clean and ensures location
/// updates are stopped immediately after we have what we need (battery).
@MainActor
final class PharmacySearchService: NSObject, ObservableObject {

    @Published private(set) var authorization: PharmacyLocationAuthorization = .notDetermined
    @Published private(set) var results: [PharmacySearchResult] = []
    @Published private(set) var isSearching: Bool = false
    @Published var lastError: String?

    private let locationManager: CLLocationManager
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?
    private var currentSearch: MKLocalSearch?

    /// Initializer accepts an injected manager primarily so tests can swap it.
    init(locationManager: CLLocationManager = CLLocationManager()) {
        self.locationManager = locationManager
        super.init()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        refreshAuthorization()
    }

    deinit {
        // Make doubly sure no location updates leak past the lifetime of the
        // service. `requestLocation` is one-shot but we belt-and-suspenders.
        locationManager.stopUpdatingLocation()
    }

    // MARK: - Authorization

    func refreshAuthorization() {
        authorization = Self.map(locationManager.authorizationStatus)
    }

    /// Requests when-in-use permission. Safe to call repeatedly; CoreLocation
    /// only prompts once.
    func requestWhenInUseAuthorization() {
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
    }

    // MARK: - Search

    /// Tries to fetch the user's current location (one-shot) and search for
    /// nearby pharmacies. Falls back to `nil` if permission is denied.
    func searchNearby(query: String = "Pharmacy") async {
        isSearching = true
        defer { isSearching = false }

        requestWhenInUseAuthorization()

        // Wait for the user's authorization decision if it's still pending.
        let location = await fetchCurrentLocation()
        guard let location else {
            // Permission denied or location unavailable — leave existing
            // results untouched so the manual search field still works.
            return
        }

        let region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 5_000,
            longitudinalMeters: 5_000
        )
        await runLocalSearch(query: query, region: region, originLocation: location)
    }

    /// Manual address/name search. Doesn't require location authorization.
    func searchByText(_ query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSearching = true
        defer { isSearching = false }

        // Use the device's last known location to bias results when available,
        // but never block on permission for a manual query.
        let bias = locationManager.location
        let region: MKCoordinateRegion
        if let bias {
            region = MKCoordinateRegion(
                center: bias.coordinate,
                latitudinalMeters: 50_000,
                longitudinalMeters: 50_000
            )
        } else {
            // Broad fallback when we have no location bias.
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                span: MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 360)
            )
        }

        await runLocalSearch(query: trimmed, region: region, originLocation: bias)
    }

    private func runLocalSearch(
        query: String,
        region: MKCoordinateRegion,
        originLocation: CLLocation?
    ) async {
        currentSearch?.cancel()

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region
        request.resultTypes = [.pointOfInterest]

        let search = MKLocalSearch(request: request)
        currentSearch = search

        do {
            let response = try await search.start()
            let mapped: [PharmacySearchResult] = response.mapItems.map { item in
                let coord = item.placemark.coordinate
                let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                let distance = originLocation.map { $0.distance(from: location) }
                return PharmacySearchResult(
                    name: item.name ?? item.placemark.name ?? "Pharmacy",
                    address: Self.formatAddress(item.placemark),
                    phone: item.phoneNumber ?? "",
                    coordinate: coord,
                    distanceMeters: distance
                )
            }
            self.results = mapped.sorted {
                ($0.distanceMeters ?? .greatestFiniteMagnitude)
                    < ($1.distanceMeters ?? .greatestFiniteMagnitude)
            }
        } catch let error as MKError where error.code == .loadingThrottled {
            // Quietly drop throttled searches.
        } catch is CancellationError {
            // User started a new search before this one finished — ignore.
        } catch {
            self.lastError = error.localizedDescription
        }
    }

    // MARK: - One-shot location helper

    /// Returns the user's current location once and immediately stops updates.
    /// Returns `nil` if authorization is denied/restricted or the request fails.
    private func fetchCurrentLocation() async -> CLLocation? {
        // If we already have a recent fix, reuse it (battery saver).
        if let recent = locationManager.location,
           Date.now.timeIntervalSince(recent.timestamp) < 60 {
            return recent
        }

        // Authorization may still be `.notDetermined` if we just prompted —
        // CLLocationManager will surface the change via the delegate, which
        // resumes the continuation in `locationManagerDidChangeAuthorization`.
        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            return nil
        default:
            break
        }

        return await withCheckedContinuation { continuation in
            locationContinuation = continuation
            locationManager.requestLocation()
        }
    }

    // MARK: - Helpers

    private static func map(_ status: CLAuthorizationStatus) -> PharmacyLocationAuthorization {
        switch status {
        case .notDetermined: return .notDetermined
        case .denied:        return .denied
        case .restricted:    return .restricted
        case .authorizedAlways, .authorizedWhenInUse: return .authorized
        @unknown default:    return .notDetermined
        }
    }

    private static func formatAddress(_ placemark: MKPlacemark) -> String {
        var parts: [String] = []
        if let n = placemark.subThoroughfare, let s = placemark.thoroughfare {
            parts.append("\(n) \(s)")
        } else if let s = placemark.thoroughfare {
            parts.append(s)
        }
        if let city = placemark.locality { parts.append(city) }
        if let state = placemark.administrativeArea { parts.append(state) }
        if let postal = placemark.postalCode { parts.append(postal) }
        return parts.joined(separator: ", ")
    }
}

// MARK: - CLLocationManagerDelegate

extension PharmacySearchService: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.refreshAuthorization()
            // Permission resolved while we were awaiting a location — request
            // it now (or finish the continuation with nil if denied).
            if locationContinuation != nil {
                switch manager.authorizationStatus {
                case .authorizedWhenInUse, .authorizedAlways:
                    manager.requestLocation()
                case .denied, .restricted:
                    locationContinuation?.resume(returning: nil)
                    locationContinuation = nil
                default:
                    break
                }
            }
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        let location = locations.last
        Task { @MainActor in
            self.locationContinuation?.resume(returning: location)
            self.locationContinuation = nil
            // Battery: stop immediately after the one-shot we requested.
            manager.stopUpdatingLocation()
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        Task { @MainActor in
            self.locationContinuation?.resume(returning: nil)
            self.locationContinuation = nil
            self.lastError = error.localizedDescription
            manager.stopUpdatingLocation()
        }
    }
}
