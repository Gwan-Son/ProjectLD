import Foundation

enum BridgeProgressCalculator {
    static func calculate(
        date: Date = Date(),
        userId: String?,
        partnerId: String?,
        checkIns: [CheckIn],
        memories: [MemoryNote],
        careItems: [CareItem],
        bridgeActivities: [BridgeActivity],
        calendar: Calendar = .current
    ) -> DailyBridgeProgress {
        let dateKey = DateKey.dateKey(for: date)

        func hasTodayCheckIn(_ id: String?) -> Bool {
            guard let id else { return false }
            return checkIns.contains {
                $0.userId == id && calendar.isDate($0.createdAt, inSameDayAs: date)
            }
        }

        func hasTodayPhoto(_ id: String?) -> Bool {
            guard let id else { return false }
            return memories.contains { $0.userId == id && $0.dateKey == dateKey }
        }

        func hasCompletedCare(_ id: String?) -> Bool {
            guard let id else { return false }
            return careItems.contains { $0.userId == id && $0.doneDateKeys.contains(dateKey) }
        }

        func hasViewedCalendar(_ id: String?) -> Bool {
            guard let id else { return false }
            return bridgeActivities.contains {
                $0.userId == id && $0.kind == .calendarViewed && $0.dateKey == dateKey
            }
        }

        let moodPoints = (hasTodayCheckIn(userId) ? 10 : 0) + (hasTodayCheckIn(partnerId) ? 10 : 0)
        let photoPoints = (hasTodayPhoto(userId) ? 15 : 0) + (hasTodayPhoto(partnerId) ? 15 : 0)
        let carePoints = (hasCompletedCare(userId) ? 15 : 0) + (hasCompletedCare(partnerId) ? 15 : 0)
        let calendarPoints = (hasViewedCalendar(userId) ? 10 : 0) + (hasViewedCalendar(partnerId) ? 10 : 0)

        return DailyBridgeProgress(milestones: [
            BridgeMilestone(
                id: "mood",
                title: "마음 건네기",
                detail: "두 사람의 오늘 기분 공유",
                earnedPoints: moodPoints,
                goalPoints: 20
            ),
            BridgeMilestone(
                id: "photo",
                title: "장면 나누기",
                detail: "두 사람의 오늘의 한 장",
                earnedPoints: photoPoints,
                goalPoints: 30
            ),
            BridgeMilestone(
                id: "care",
                title: "서로 챙기기",
                detail: "두 사람이 챙김 하나씩 완료",
                earnedPoints: carePoints,
                goalPoints: 30
            ),
            BridgeMilestone(
                id: "calendar",
                title: "오늘 일정 확인하기",
                detail: "두 사람이 오늘 캘린더 확인",
                earnedPoints: calendarPoints,
                goalPoints: 20
            )
        ])
    }
}
