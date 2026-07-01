import Foundation
@preconcurrency import CoreLocation
import MapKit

actor WeatherService {
    static let shared = WeatherService()

    private struct CacheEntry {
        let summary: WeatherSummary
        let expiresAt: Date
    }

    private var cache: [String: CacheEntry] = [:]
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func currentWeather(latitude: Double, longitude: Double) async throws -> WeatherSummary {
        let cacheKey = String(format: "ko-KR:%.2f,%.2f", latitude, longitude)
        if let cached = cache[cacheKey], cached.expiresAt > Date() {
            return cached.summary
        }

        guard let apiKey = Self.apiKey, !apiKey.isEmpty else {
            throw WeatherError.missingAPIKey
        }

        var components = URLComponents(string: "https://api.openweathermap.org/data/2.5/weather")
        components?.queryItems = [
            URLQueryItem(name: "lat", value: String(latitude)),
            URLQueryItem(name: "lon", value: String(longitude)),
            URLQueryItem(name: "appid", value: apiKey),
            URLQueryItem(name: "units", value: "metric"),
            URLQueryItem(name: "lang", value: "kr")
        ]
        guard let url = components?.url else { throw WeatherError.invalidURL }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WeatherError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw WeatherError.httpStatus(httpResponse.statusCode)
        }

        let payload = try JSONDecoder().decode(OpenWeatherResponse.self, from: data)
        let weather = payload.weather.first
        let cityName = await localizedCityName(
            latitude: latitude,
            longitude: longitude,
            fallback: payload.name
        )
        let summary = WeatherSummary(
            cityName: cityName,
            summary: weather?.description ?? "날씨 정보 없음",
            temperature: Int(payload.main.temp.rounded()),
            iconName: Self.iconName(for: weather?.id),
            updatedAt: Date(),
            feelsLike: Int(payload.main.feelsLike.rounded()),
            minimumTemperature: Int(payload.main.tempMin.rounded()),
            maximumTemperature: Int(payload.main.tempMax.rounded()),
            humidity: payload.main.humidity,
            pressure: payload.main.pressure,
            windSpeed: payload.wind?.speed,
            visibility: payload.visibility,
            cloudiness: payload.clouds?.all,
            sunrise: payload.sys?.sunrise.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            sunset: payload.sys?.sunset.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        )
        cache[cacheKey] = CacheEntry(summary: summary, expiresAt: Date().addingTimeInterval(15 * 60))
        return summary
    }

    func cityName(latitude: Double, longitude: Double, fallback: String = "현재 위치") async -> String {
        await localizedCityName(latitude: latitude, longitude: longitude, fallback: fallback)
    }

    private func localizedCityName(latitude: Double, longitude: Double, fallback: String) async -> String {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let fallbackName = fallback.isEmpty ? "현재 위치" : fallback
        if #available(iOS 26.0, *) {
            return await localizedCityNameWithMapKit(location: location, fallbackName: fallbackName)
        }
        return await localizedCityNameWithCoreLocation(location: location, fallbackName: fallbackName)
    }

    @available(iOS 26.0, *)
    private func localizedCityNameWithMapKit(location: CLLocation, fallbackName: String) async -> String {
        do {
            guard let request = MKReverseGeocodingRequest(location: location) else {
                return fallbackName
            }
            request.preferredLocale = Locale(identifier: "ko_KR")
            let representation = try await request.mapItems.first?.addressRepresentations
            return representation?.cityWithContext(.short)
                ?? representation?.cityName
                ?? fallbackName
        } catch {
            return fallbackName
        }
    }

    private func localizedCityNameWithCoreLocation(location: CLLocation, fallbackName: String) async -> String {
        await withCheckedContinuation { continuation in
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(
                location,
                preferredLocale: Locale(identifier: "ko_KR")
            ) { [geocoder] placemarks, _ in
                _ = geocoder
                let placemark = placemarks?.first
                let cityName = placemark?.locality
                    ?? placemark?.subAdministrativeArea
                    ?? placemark?.administrativeArea
                    ?? fallbackName
                continuation.resume(returning: cityName)
            }
        }
    }

    private static var apiKey: String? {
        let value = Bundle.main.object(forInfoDictionaryKey: "OPENWEATHER_API_KEY") as? String
        guard let value, !value.hasPrefix("$(") else { return nil }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func iconName(for conditionId: Int?) -> String {
        guard let conditionId else { return "partly-cloudy" }
        return switch conditionId {
        case 200...232: "thunderstorm"
        case 300...321: "shower"
        case 500...531: "rain"
        case 600...622: "snow"
        case 701...741: "fog"
        case 742...781: "wind"
        case 800: "sunny"
        case 801...802: "partly-cloudy"
        case 803...804: "cloudy"
        default: "partly-cloudy"
        }
    }
}

nonisolated private struct OpenWeatherResponse: Decodable {
    struct Main: Decodable {
        let temp: Double
        let feelsLike: Double
        let tempMin: Double
        let tempMax: Double
        let pressure: Int
        let humidity: Int

        enum CodingKeys: String, CodingKey {
            case temp, pressure, humidity
            case feelsLike = "feels_like"
            case tempMin = "temp_min"
            case tempMax = "temp_max"
        }
    }
    struct Weather: Decodable {
        let id: Int
        let description: String
    }
    struct Wind: Decodable { let speed: Double }
    struct Clouds: Decodable { let all: Int }
    struct System: Decodable {
        let sunrise: TimeInterval?
        let sunset: TimeInterval?
    }

    let weather: [Weather]
    let main: Main
    let name: String
    let visibility: Int?
    let wind: Wind?
    let clouds: Clouds?
    let sys: System?
}

enum WeatherError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: "OpenWeather API 키가 설정되지 않았어요."
        case .invalidURL: "날씨 요청 주소를 만들 수 없어요."
        case .invalidResponse: "날씨 서버 응답을 확인할 수 없어요."
        case .httpStatus(let code): "날씨 정보를 불러오지 못했어요. (\(code))"
        }
    }
}
