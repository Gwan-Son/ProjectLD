import CoreLocation
import Foundation

extension AppViewModel {
    func requestCurrentLocationIfNeeded(for profile: LongdyUser?) {
        guard !hasRequestedCurrentLocation, let profile, profile.id == userId, appleSession != nil else { return }
        hasRequestedCurrentLocation = true

        Task {
            await refreshCurrentLocationAndWeather(for: profile)
        }
    }

    func loadWeather(for user: LongdyUser?) {
        guard let user, let _ = user.latitude, let _ = user.longitude else { return }
        Task {
            await loadWeatherAsync(for: user)
        }
    }

    @discardableResult
    func refreshCurrentLocationAndWeather(for profile: LongdyUser?) async -> Bool {
        guard let profile, profile.id == userId, let session = appleSession else { return false }

        do {
            let location = try await locationService.requestCurrentLocation()
            let latitude = roundedCoordinate(location.coordinate.latitude)
            let longitude = roundedCoordinate(location.coordinate.longitude)
            let cityName = await weatherService.cityName(
                latitude: latitude,
                longitude: longitude,
                fallback: profile.cityName
            )
            currentProfile = try await cloudKitService.updateUserLocation(
                session: session,
                latitude: latitude,
                longitude: longitude,
                timezoneId: TimeZone.current.identifier
            )
            currentProfile = try await cloudKitService.updateUserProfile(
                session: session,
                cityName: cityName,
                timezoneId: TimeZone.current.identifier
            )
            await refreshCoupleStatus()
            await fetchWeather(
                userId: profile.id,
                cityName: cityName,
                latitude: latitude,
                longitude: longitude
            )
            return true
        } catch let error as LocationError {
            weatherErrorMessage = error.longdyUserMessage
            await loadWeatherAsync(for: profile)
            return false
        } catch {
            weatherErrorMessage = error.longdyUserMessage
            return false
        }
    }

    func loadWeatherAsync(for user: LongdyUser?) async {
        guard let user, let latitude = user.latitude, let longitude = user.longitude else { return }
        await fetchWeather(
            userId: user.id,
            cityName: user.cityName,
            latitude: latitude,
            longitude: longitude
        )
    }

    func fetchWeather(userId: String, cityName: String, latitude: Double, longitude: Double) async {
        do {
            let weather = try await weatherService.currentWeather(latitude: latitude, longitude: longitude)
            weatherByUserId[userId] = weather
            if self.userId == userId { weatherErrorMessage = nil }
        } catch WeatherError.missingAPIKey {
            weatherByUserId[userId] = .placeholder(cityName: cityName)
        } catch {
            weatherByUserId[userId] = .placeholder(cityName: cityName)
            if self.userId == userId { weatherErrorMessage = error.longdyUserMessage }
        }
    }

    func roundedCoordinate(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}
