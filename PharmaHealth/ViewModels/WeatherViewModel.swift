import Foundation
import CoreLocation
import SwiftUI

/// State of the dashboard weather card. The view renders directly from this
/// enum, so adding a new case is a compile-time TODO across the UI.
enum WeatherViewState: Equatable {
    case idle
    case loading
    case loaded(WeatherSnapshot)
    case denied
    case failed(String)
}

/// Owns: location authorization, a one-shot location fetch, and the weather
/// fetch + cache. Lives inside `DashboardView` as a `@StateObject` so it
/// re-uses one `CLLocationManager` for the whole session.
///
/// Caching: we persist the most recent successful snapshot in `UserDefaults`
/// (JSON) keyed by rounded lat/lon. While the cache is fresh (default 30 min)
/// we avoid hitting WeatherKit at all — important for both battery and the
/// per-device WeatherKit quota.
@MainActor
final class WeatherViewModel: NSObject, ObservableObject {

    @Published private(set) var state: WeatherViewState = .idle

    private let provider: WeatherProviding
    private let fallback: WeatherProviding
    private let cacheTTL: TimeInterval
    private let defaults: UserDefaults
    private let locationManager: CLLocationManager
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    private static let cacheKey = "WeatherViewModel.cachedSnapshot"

    init(
        provider: WeatherProviding = WeatherKitWeatherProvider(),
        fallback: WeatherProviding = MockWeatherProvider(),
        cacheTTL: TimeInterval = 60 * 30,
        defaults: UserDefaults = .standard,
        locationManager: CLLocationManager = CLLocationManager()
    ) {
        self.provider = provider
        self.fallback = fallback
        self.cacheTTL = cacheTTL
        self.defaults = defaults
        self.locationManager = locationManager
        super.init()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// Public entry point. Always cheap to call — uses cache when fresh and
    /// only requests location/network when truly needed.
    func refresh(force: Bool = false) async {
        if !force, let cached = cachedSnapshot(), !isCacheStale(cached) {
            state = .loaded(cached)
            return
        }

        state = .loading

        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            // Show last cached value if available, otherwise mark denied.
            if let cached = cachedSnapshot() {
                state = .loaded(cached)
            } else {
                state = .denied
            }
            return
        case .notDetermined:
            // The delegate will re-call refresh once the user decides. Show
            // cache if we have any so the UI isn't stuck on "loading".
            locationManager.requestWhenInUseAuthorization()
            if let cached = cachedSnapshot() {
                state = .loaded(cached)
            } else {
                state = .idle
            }
            return
        default:
            break
        }

        guard let location = await fetchOneShotLocation() else {
            // Permission resolved to denied or fix failed — fall back to cache.
            if let cached = cachedSnapshot() {
                state = .loaded(cached)
            } else {
                state = .denied
            }
            return
        }

        await fetchWeather(at: location)
    }

    /// Re-runs after the user grants permission via the prompt or via
    /// iOS Settings. Safe to call repeatedly.
    func retry() async {
        await refresh(force: true)
    }

    // MARK: - Network

    private func fetchWeather(at location: CLLocation) async {
        let coord = location.coordinate
        let placeName = await reverseGeocode(location: location)
        do {
            let snapshot = try await provider.current(for: coord, locationName: placeName)
            cache(snapshot)
            state = .loaded(snapshot)
        } catch {
            // WeatherKit not configured / network failure / quota → try
            // mock so the UI still has something benign to render.
            if let cached = cachedSnapshot() {
                state = .loaded(cached)
                return
            }
            do {
                let mock = try await fallback.current(for: coord, locationName: placeName)
                state = .loaded(mock)
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    private func reverseGeocode(location: CLLocation) async -> String? {
        let geocoder = CLGeocoder()
        let placemark = try? await geocoder.reverseGeocodeLocation(location).first
        return placemark?.locality ?? placemark?.subAdministrativeArea
    }

    // MARK: - Cache

    private func cachedSnapshot() -> WeatherSnapshot? {
        guard let data = defaults.data(forKey: Self.cacheKey) else { return nil }
        return try? JSONDecoder().decode(WeatherSnapshot.self, from: data)
    }

    private func cache(_ snapshot: WeatherSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Self.cacheKey)
    }

    private func isCacheStale(_ snapshot: WeatherSnapshot) -> Bool {
        Date.now.timeIntervalSince(snapshot.fetchedAt) > cacheTTL
    }

    // MARK: - Location (one-shot)

    private func fetchOneShotLocation() async -> CLLocation? {
        if let recent = locationManager.location,
           Date.now.timeIntervalSince(recent.timestamp) < 5 * 60 {
            return recent
        }
        return await withCheckedContinuation { continuation in
            locationContinuation = continuation
            locationManager.requestLocation()
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension WeatherViewModel: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                if locationContinuation != nil {
                    manager.requestLocation()
                } else {
                    await refresh(force: true)
                }
            case .denied, .restricted:
                locationContinuation?.resume(returning: nil)
                locationContinuation = nil
                if case .loaded = state { /* keep cached snapshot visible */ } else {
                    state = .denied
                }
            default:
                break
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
            manager.stopUpdatingLocation()
        }
    }
}
