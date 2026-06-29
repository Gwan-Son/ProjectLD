import Foundation

struct LongdyUser: Identifiable, Equatable, Codable {
    let id: String
    var email: String
    var displayName: String
    var nickname: String
    var timezoneId: String
    var cityName: String
    var latitude: Double?
    var longitude: Double?
    var locationUpdatedAt: Date?
    var partnerCoupleId: String?
    var createdAt: Date

    var friendlyName: String {
        nickname.isEmpty ? displayName : nickname
    }
}

struct Couple: Identifiable, Equatable, Codable {
    let id: String
    var memberIds: [String]
    var memberProfiles: [LongdyUser] = []
    var inviteCode: String
    var nextMeetDate: Date?
    var anniversaryDate: Date?
    var createdAt: Date
}

enum Mood: String, CaseIterable, Identifiable, Codable {
    case clear = "맑음"
    case calm = "편안"
    case tired = "지침"
    case lonely = "외로움"
    case sensitive = "예민"
    case excited = "설렘"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .clear: "mood-clear"
        case .calm: "mood-calm"
        case .tired: "mood-tired"
        case .lonely: "mood-lonely"
        case .sensitive: "mood-sensitive"
        case .excited: "mood-excited"
        }
    }
}

enum LongdyStatus: String, CaseIterable, Identifiable, Codable {
    case working = "일하는 중"
    case moving = "이동 중"
    case resting = "쉬는 중"
    case bedtime = "잘 준비 중"
    case callable = "지금 통화 가능"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .working: "status-working"
        case .moving: "status-moving"
        case .resting: "status-resting"
        case .bedtime: "status-bedtime"
        case .callable: "status-callable"
        }
    }
}

struct CheckIn: Identifiable, Equatable, Codable {
    let id: String
    var userId: String
    var mood: Mood
    var status: LongdyStatus
    var createdAt: Date
    var expiresAt: Date?

    nonisolated var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt <= Date()
    }
}

enum EventType: String, CaseIterable, Identifiable, Codable {
    case mine = "내 일정"
    case partner = "상대 일정"
    case meet = "다음 만남"
    case anniversary = "기념일"

    var id: String { rawValue }
}

struct CoupleEvent: Identifiable, Equatable, Codable {
    let id: String
    var ownerUserId: String
    var title: String
    var startAt: Date
    var endAt: Date
    var type: EventType
    var memo: String
}

enum CareRepeatRule: String, CaseIterable, Identifiable, Codable {
    case once = "오늘만"
    case daily = "매일"
    case weekdays = "평일"
    case weekends = "주말"
    case weekly = "매주"

    var id: String { rawValue }

    nonisolated func applies(to date: Date, createdAt: Date) -> Bool {
        let calendar = Calendar.current
        switch self {
        case .once:
            return calendar.isDate(date, inSameDayAs: createdAt)
        case .daily:
            return true
        case .weekdays:
            return !calendar.isDateInWeekend(date)
        case .weekends:
            return calendar.isDateInWeekend(date)
        case .weekly:
            return calendar.component(.weekday, from: date) == calendar.component(.weekday, from: createdAt)
        }
    }
}

struct CareItem: Identifiable, Equatable, Codable {
    let id: String
    var userId: String
    var dateKey: String
    var title: String
    var iconName: String
    var repeatRule: CareRepeatRule
    var reminderHour: Int?
    var reminderMinute: Int?
    var note: String
    var doneDateKeys: [String]
    var createdAt: Date

    var isDoneToday: Bool {
        doneDateKeys.contains(DateKey.dateKey())
    }

    var reminderText: String? {
        guard let reminderHour, let reminderMinute else { return nil }
        return String(format: "%02d:%02d", reminderHour, reminderMinute)
    }
}

enum CareCategoryFallback {
    case meal
    case water
    case medicine
    case rest
    case sleep
    case walk

    init(rawValue: String) {
        switch rawValue {
        case "밥 챙기기": self = .meal
        case "물 마시기": self = .water
        case "약 챙기기": self = .medicine
        case "일찍 자기": self = .sleep
        case "가볍게 걷기": self = .walk
        default: self = .rest
        }
    }

    var title: String {
        switch self {
        case .meal: "밥 챙기기"
        case .water: "물 마시기"
        case .medicine: "약 챙기기"
        case .rest: "잠깐 쉬기"
        case .sleep: "일찍 자기"
        case .walk: "가볍게 걷기"
        }
    }

    var iconName: String {
        switch self {
        case .meal: "meal"
        case .water: "drink-water"
        case .medicine: "medicine"
        case .rest: "rest"
        case .sleep: "sleep"
        case .walk: "walk"
        }
    }
}

struct MemoryNote: Identifiable, Equatable, Codable {
    let id: String
    var userId: String
    var text: String
    var storageURL: String?
    var dateKey: String
    var createdAt: Date
}

struct BridgeMilestone: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let earnedPoints: Int
    let goalPoints: Int

    var isComplete: Bool {
        earnedPoints == goalPoints
    }
}

struct DailyBridgeProgress: Equatable {
    let milestones: [BridgeMilestone]

    var points: Int {
        milestones.reduce(0) { $0 + $1.earnedPoints }
    }

    var goalPoints: Int {
        milestones.reduce(0) { $0 + $1.goalPoints }
    }

    var fraction: Double {
        guard goalPoints > 0 else { return 0 }
        return min(Double(points) / Double(goalPoints), 1)
    }

    var stageTitle: String {
        switch points {
        case 100...: "오늘의 다리 완성"
        case 75..<100: "거의 이어졌어요"
        case 50..<75: "절반을 건너왔어요"
        case 25..<50: "서로에게 가는 중"
        case 1..<25: "다리 놓기 시작"
        default: "첫 발판을 기다리는 중"
        }
    }

    var assetName: String {
        switch points {
        case 100...: "bridge-stage-5"
        case 75..<100: "bridge-stage-4"
        case 50..<75: "bridge-stage-3"
        case 25..<50: "bridge-stage-2"
        case 1..<25: "bridge-stage-1"
        default: "bridge-stage-0"
        }
    }
}

enum BridgeActivityKind: String, Codable {
    case calendarViewed
}

struct BridgeActivity: Identifiable, Equatable, Codable {
    let id: String
    var userId: String
    var kind: BridgeActivityKind
    var dateKey: String
    var createdAt: Date
}

enum HomeCardKind: String, CaseIterable, Identifiable, Codable {
    case nextMeeting
    case connectedBridge
    case timeAndWeather
    case mood
    case recentMoments

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nextMeeting: "다음 만남"
        case .connectedBridge: "연결된 다리"
        case .timeAndWeather: "시간·날씨"
        case .mood: "기분 공유"
        case .recentMoments: "최근의 순간들"
        }
    }

    var systemImage: String {
        switch self {
        case .nextMeeting: "calendar.badge.clock"
        case .connectedBridge: "link"
        case .timeAndWeather: "clock"
        case .mood: "face.smiling"
        case .recentMoments: "photo.on.rectangle"
        }
    }
}

struct WeatherSummary: Equatable, Codable {
    var cityName: String
    var summary: String
    var temperature: Int?
    var iconName: String
    var updatedAt: Date?
    var feelsLike: Int?
    var minimumTemperature: Int?
    var maximumTemperature: Int?
    var humidity: Int?
    var pressure: Int?
    var windSpeed: Double?
    var visibility: Int?
    var cloudiness: Int?
    var sunrise: Date?
    var sunset: Date?

    static func placeholder(cityName: String) -> WeatherSummary {
        WeatherSummary(
            cityName: cityName,
            summary: "날씨 준비 중",
            temperature: nil,
            iconName: "partly-cloudy",
            updatedAt: nil,
            feelsLike: nil,
            minimumTemperature: nil,
            maximumTemperature: nil,
            humidity: nil,
            pressure: nil,
            windSpeed: nil,
            visibility: nil,
            cloudiness: nil,
            sunrise: nil,
            sunset: nil
        )
    }
}

enum LongdyError: LocalizedError {
    case missingUser
    case missingCouple
    case invalidInviteCode
    case coupleFull
    case invalidInput(String)

    var errorDescription: String? {
        switch self {
        case .missingUser: "로그인이 필요해요."
        case .missingCouple: "커플 연결이 필요해요."
        case .invalidInviteCode: "초대 코드를 찾을 수 없어요."
        case .coupleFull: "이미 두 명이 연결된 코드예요."
        case .invalidInput(let message): message
        }
    }
}

enum DateKey {
    static func dateKey(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
