import Foundation
import CoreLocation

/// Coarse weather condition the app cares about. Apple's WeatherKit provides
/// a much richer enum, but the home-screen card only needs a few buckets.
enum WeatherCondition: String, Codable {
    case clear
    case cloudy
    case rain
    case snow
    case storm
    case fog
    case hot
    case cold
    case unknown
}

/// A single weather reading the home-screen card displays. Always represents
/// "current weather" — no forecasts. Stored as a value type so it can be
/// cached in `UserDefaults` as JSON.
struct WeatherSnapshot: Codable, Equatable {
    var temperatureCelsius: Double
    var condition: WeatherCondition
    /// SF Symbol name; resolved by Apple's WeatherKit when available, or by a
    /// heuristic mapping in the mock provider.
    var sfSymbol: String
    var locationName: String?
    var fetchedAt: Date

    /// Helper for views that need a localized temperature string.
    func displayTemperature(in locale: Locale = .current) -> String {
        let measurement = Measurement(value: temperatureCelsius, unit: UnitTemperature.celsius)
        let formatter = MeasurementFormatter()
        formatter.locale = locale
        formatter.unitOptions = .temperatureWithoutUnit
        formatter.numberFormatter.maximumFractionDigits = 0
        let value = formatter.string(from: measurement)
        let unit = locale.measurementSystem == .us ? "°F" : "°C"
        // `temperatureWithoutUnit` strips the unit, but the value is auto-converted.
        return "\(value)\(unit)"
    }

    /// Short user-facing condition word.
    var conditionLabel: String {
        switch condition {
        case .clear:   return "Sunny"
        case .cloudy:  return "Cloudy"
        case .rain:    return "Rain"
        case .snow:    return "Snow"
        case .storm:   return "Storm"
        case .fog:     return "Fog"
        case .hot:     return "Hot"
        case .cold:    return "Cold"
        case .unknown: return "—"
        }
    }
}

/// Abstract provider so the dashboard doesn't care whether the data came from
/// WeatherKit, a mock, or a future alternative source. Coordinates are
/// required — callers handle the location-permission flow.
protocol WeatherProviding: Sendable {
    func current(
        for coordinate: CLLocationCoordinate2D,
        locationName: String?
    ) async throws -> WeatherSnapshot
}
