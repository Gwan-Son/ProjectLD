import Foundation

struct LongdyUser: Identifiable, Equatable {
    let id: String
    var email: String
    var displayName: String
    var nickname: String
    var timezoneId: String
    var cityName: String
    var partnerCoupleId: String?
    var createdAt: Date

    var friendlyName: String {
        nickname.isEmpty ? displayName : nickname
    }
}

struct Couple: Identifiable, Equatable {
    let id: String
    var memberIds: [String]
    var inviteCode: String
    var nextMeetDate: Date?
    var anniversaryDate: Date?
    var createdAt: Date
}

enum Mood: String, CaseIterable, Identifiable {
    case clear = "맑음"
    case calm = "편안"
    case tired = "지침"
    case lonely = "외로움"
    case sensitive = "예민"
    case excited = "설렘"

    var id: String { rawValue }
}

enum LongdyStatus: String, CaseIterable, Identifiable {
    case working = "일하는 중"
    case moving = "이동 중"
    case resting = "쉬는 중"
    case bedtime = "잘 준비 중"
    case callable = "지금 통화 가능"

    var id: String { rawValue }
}

enum CallIntent: String, CaseIterable, Identifiable {
    case available = "가능"
    case later = "나중에"
    case unavailable = "오늘 어려움"

    var id: String { rawValue }
}

struct CheckIn: Identifiable, Equatable {
    let id: String
    var userId: String
    var mood: Mood
    var fatigue: Int
    var missLevel: Int
    var status: LongdyStatus
    var canCall: CallIntent
    var note: String
    var createdAt: Date
    var expiresAt: Date?

    var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt <= Date()
    }
}

enum EventType: String, CaseIterable, Identifiable {
    case mine = "내 일정"
    case partner = "상대 일정"
    case meet = "다음 만남"
    case anniversary = "기념일"

    var id: String { rawValue }
}

struct CoupleEvent: Identifiable, Equatable {
    let id: String
    var ownerUserId: String
    var title: String
    var startAt: Date
    var endAt: Date
    var type: EventType
    var memo: String
}

struct Availability: Identifiable, Equatable {
    let id: String
    var userId: String
    var startAt: Date
    var endAt: Date
    var label: String
    var createdAt: Date
}

enum CareRepeatRule: String, CaseIterable, Identifiable {
    case once = "오늘만"
    case daily = "매일"
    case weekdays = "평일"
    case weekends = "주말"
    case weekly = "매주"

    var id: String { rawValue }

    func applies(to date: Date, createdAt: Date) -> Bool {
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

struct CareItem: Identifiable, Equatable {
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
        case .meal: "fork.knife"
        case .water: "drop"
        case .medicine: "cross.case"
        case .rest: "cup.and.saucer"
        case .sleep: "moon"
        case .walk: "figure.walk"
        }
    }
}

enum MemoryType: String, CaseIterable, Identifiable {
    case text = "text"
    case photo = "photo"
    case audio = "audio"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .text: "텍스트"
        case .photo: "사진"
        case .audio: "음성"
        }
    }
}

struct MemoryNote: Identifiable, Equatable {
    let id: String
    var userId: String
    var type: MemoryType
    var text: String
    var storageURL: String?
    var createdAt: Date
}

struct WeatherSummary: Equatable {
    var cityName: String
    var summary: String
    var temperature: Int
}

enum LongdyError: LocalizedError {
    case firebaseNotConfigured
    case missingUser
    case missingCouple
    case invalidInviteCode
    case coupleFull
    case invalidInput(String)

    var errorDescription: String? {
        switch self {
        case .firebaseNotConfigured: "Firebase 설정 파일이 필요해요."
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
