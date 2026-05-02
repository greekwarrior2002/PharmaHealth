import Foundation
import CoreLocation
#if canImport(WeatherKit)
import WeatherKit
#endif

/// Apple WeatherKit implementation of `WeatherProviding`. Compiled in only on
/// platforms that ship WeatherKit (iOS 16+). The runtime call still requires
/// the WeatherKit capability to be enabled on the App ID and an active paid
/// developer team — without that, the call throws and the view model falls
/// back to either cached or mock data.
struct WeatherKitWeatherProvider: WeatherProviding {

    func current(
        for coordinate: CLLocationCoordinate2D,
        locationName: String?
    ) async throws -> WeatherSnapshot {
        #if canImport(WeatherKit)
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let weather = try await WeatherService.shared.weather(for: location)
        let current = weather.currentWeather
        return WeatherSnapshot(
            temperatureCelsius: current.temperature.converted(to: .celsius).value,
            condition: Self.map(current.condition),
            sfSymbol: current.symbolName,
            locationName: locationName,
            fetchedAt: .now
        )
        #else
        throw NSError(
            domain: "Weather",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "WeatherKit is not available on this platform."]
        )
        #endif
    }

    #if canImport(WeatherKit)
    private static func map(_ condition: WeatherKit.WeatherCondition) -> WeatherCondition {
        switch condition {
        case .clear, .mostlyClear:
            return .clear
        case .hot:
            return .hot
        case .cloudy, .mostlyCloudy, .partlyCloudy:
            return .cloudy
        case .drizzle, .rain, .heavyRain, .freezingDrizzle, .freezingRain,
             .sunShowers:
            return .rain
        case .snow, .heavySnow, .flurries, .sunFlurries, .blowingSnow,
             .blizzard, .wintryMix, .sleet:
            return .snow
        case .thunderstorms, .scatteredThunderstorms, .strongStorms,
             .tropicalStorm, .hurricane:
            return .storm
        case .foggy, .haze, .smoky, .breezy, .windy, .blowingDust:
            return .fog
        case .frigid:
            return .cold
        @unknown default:
            return .unknown
        }
    }
    #endif
}
