import SwiftUI

struct WeatherDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let user: LongdyUser
    let weather: WeatherSummary
    let onRefresh: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            skyBackground
                .opacity(0.56)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    topBar
                    hero
                    conditionPanel
                    detailGrid
                    updateText
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.light)
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 38, height: 38)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay {
                        Circle().stroke(.white.opacity(0.68), lineWidth: 0.8)
                    }
            }
            .accessibilityLabel("닫기")

            Spacer()

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 38, height: 38)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay {
                        Circle().stroke(.white.opacity(0.68), lineWidth: 0.8)
                    }
            }
            .accessibilityLabel("날씨 새로고침")
        }
        .foregroundStyle(WeatherPalette.primary)
    }

    private var hero: some View {
        VStack(spacing: 4) {
            Text(weather.cityName)
                .font(.system(size: 34, weight: .medium))

            if let temperature = weather.temperature {
                Text("\(temperature)°")
                    .font(.system(size: 96, weight: .thin))
                    .padding(.leading, 12)
            } else {
                Image(weather.iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
            }

            Text(weather.summary)
                .font(.title3.weight(.medium))

            if let low = weather.minimumTemperature, let high = weather.maximumTemperature {
                Text("최고 \(high)°  최저 \(low)°")
                    .font(.headline)
            }

            Text("\(user.friendlyName)의 현재 날씨")
                .font(.caption.weight(.medium))
                .foregroundStyle(WeatherPalette.muted)
                .padding(.top, 4)
        }
        .foregroundStyle(WeatherPalette.ink)
        .frame(maxWidth: .infinity)
    }

    private var conditionPanel: some View {
        weatherPanel {
            HStack(spacing: 18) {
                Image(weather.iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 78, height: 78)

                VStack(alignment: .leading, spacing: 7) {
                    Label("현재 상태", systemImage: "cloud.sun.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WeatherPalette.muted)
                    Text(conditionDescription)
                        .font(.body.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var detailGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            WeatherMetricCard(
                title: "체감 온도",
                systemImage: "thermometer.medium",
                value: weather.feelsLike.map { "\($0)°" } ?? "--",
                detail: "실제로 느껴지는 온도"
            )
            WeatherMetricCard(
                title: "습도",
                systemImage: "humidity.fill",
                value: weather.humidity.map { "\($0)%" } ?? "--",
                detail: humidityDescription
            )
            WeatherMetricCard(
                title: "바람",
                systemImage: "wind",
                value: weather.windSpeed.map { String(format: "%.1f m/s", $0) } ?? "--",
                detail: "현재 풍속"
            )
            WeatherMetricCard(
                title: "가시거리",
                systemImage: "eye.fill",
                value: visibilityText,
                detail: "멀리 보이는 거리"
            )
            WeatherMetricCard(
                title: "기압",
                systemImage: "gauge.with.dots.needle.50percent",
                value: weather.pressure.map { "\($0) hPa" } ?? "--",
                detail: "해면 기압"
            )
            WeatherMetricCard(
                title: "구름",
                systemImage: "cloud.fill",
                value: weather.cloudiness.map { "\($0)%" } ?? "--",
                detail: "하늘을 덮은 정도"
            )
            WeatherMetricCard(
                title: "일출",
                systemImage: "sunrise.fill",
                value: timeText(weather.sunrise),
                detail: "해가 뜨는 시간"
            )
            WeatherMetricCard(
                title: "일몰",
                systemImage: "sunset.fill",
                value: timeText(weather.sunset),
                detail: "해가 지는 시간"
            )
        }
    }

    private var updateText: some View {
        Group {
            if let updatedAt = weather.updatedAt {
                Text("마지막 업데이트 \(updatedAt.formatted(date: .omitted, time: .shortened))")
            } else {
                Text("날씨 정보를 불러오는 중이에요")
            }
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(WeatherPalette.muted.opacity(0.78))
    }

    private var conditionDescription: String {
        guard let temperature = weather.temperature else {
            return "위치와 날씨 정보를 확인하고 있어요."
        }
        if let feelsLike = weather.feelsLike {
            return "현재 \(temperature)°, 체감 \(feelsLike)°예요. \(weather.summary) 상태가 이어지고 있어요."
        }
        return "현재 \(temperature)°이고 \(weather.summary) 상태예요."
    }

    private var humidityDescription: String {
        guard let humidity = weather.humidity else { return "현재 습도" }
        return switch humidity {
        case ..<40: "공기가 건조해요"
        case 70...: "습도가 높은 편이에요"
        default: "비교적 쾌적해요"
        }
    }

    private var visibilityText: String {
        guard let visibility = weather.visibility else { return "--" }
        return String(format: "%.1f km", Double(visibility) / 1000)
    }

    private func timeText(_ date: Date?) -> String {
        guard let date else { return "--" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: user.timezoneId)
        formatter.dateFormat = "a h:mm"
        return formatter.string(from: date)
    }

    private var skyBackground: LinearGradient {
        let colors: [Color]
        switch weather.iconName {
        case "sunny":
            colors = [WeatherPalette.apricot, WeatherPalette.background]
        case "rain", "shower", "thunderstorm":
            colors = [WeatherPalette.mauve, WeatherPalette.background]
        case "snow":
            colors = [WeatherPalette.surface, WeatherPalette.blush]
        default:
            colors = [WeatherPalette.blush, WeatherPalette.background]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    private func weatherPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .background(WeatherPalette.surface.opacity(0.28))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.66), lineWidth: 0.8)
            }
    }
}

private struct WeatherMetricCard: View {
    let title: String
    let systemImage: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title.uppercased(), systemImage: systemImage)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(WeatherPalette.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(WeatherPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(WeatherPalette.muted.opacity(0.86))
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 126, alignment: .topLeading)
        .background(.ultraThinMaterial)
        .background(WeatherPalette.surface.opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.66), lineWidth: 0.8)
        }
    }
}
