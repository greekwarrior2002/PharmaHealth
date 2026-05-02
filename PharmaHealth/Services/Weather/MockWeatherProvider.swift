import Foundation
import CoreLocation

/// Deterministic provider used in SwiftUI previews and as a safety net when
/// WeatherKit isn't available (e.g. the developer team hasn't enabled the
/// WeatherKit capability). Always returns a pleasant, neutral snapshot so the
/// dashboard layout is exercised end-to-end.
struct MockWeatherProvider: WeatherProviding {
    func current(
        for coordinate: CLLocationCoordinate2D,
        locationName: String?
    ) async throws -> WeatherSnapshot {
        WeatherSnapshot(
            temperatureCelsius: 22,
            condition: .clear,
            sfSymbol: "sun.max.fill",
            locationName: locationName,
            fetchedAt: .now
        )
    }
}
