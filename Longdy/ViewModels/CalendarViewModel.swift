import Combine
import Foundation

@MainActor
final class CalendarViewModel: ObservableObject {
    @Published var showingAdd = false
    @Published var editingEvent: CoupleEvent?
    @Published var selectedDate = Date()
    @Published var visibleMonth = Date()
    @Published var errorMessage: String?

    private let repository: any CalendarRepository

    init(repository: any CalendarRepository = DependencyContainer.live.calendarRepository) {
        self.repository = repository
    }

    var weekdaySymbols: [String] { ["일", "월", "화", "수", "목", "금", "토"] }

    var selectedDateTitle: String {
        selectedDate.formatted(.dateTime.month(.wide).day().weekday(.wide))
    }

    var monthCalendarDates: [Date] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: visibleMonth),
              let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
              let lastWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.end.addingTimeInterval(-1)) else {
            return []
        }

        var days: [Date] = []
        var date = firstWeek.start
        while date < lastWeek.end {
            days.append(date)
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date.addingTimeInterval(86_400)
        }
        return days
    }

    func moveMonth(by value: Int) {
        let calendar = Calendar.current
        visibleMonth = calendar.date(byAdding: .month, value: value, to: visibleMonth) ?? visibleMonth
        if calendar.isDate(visibleMonth, equalTo: Date(), toGranularity: .month) {
            selectedDate = Date()
        } else {
            selectedDate = calendar.dateInterval(of: .month, for: visibleMonth)?.start ?? visibleMonth
        }
    }

    func eventsForSelectedDate(from events: [CoupleEvent]) -> [CoupleEvent] {
        events
            .filter { occurs($0, on: selectedDate) }
            .sorted { $0.startAt < $1.startAt }
    }

    func eventTypes(on date: Date, events: [CoupleEvent]) -> [EventType] {
        Array(Set(events.filter { occurs($0, on: date) }.map(\.type)))
            .sorted { $0.rawValue < $1.rawValue }
    }

    private func occurs(_ event: CoupleEvent, on date: Date) -> Bool {
        let calendar = Calendar.current
        guard let day = calendar.dateInterval(of: .day, for: date) else {
            return calendar.isDate(event.startAt, inSameDayAs: date)
        }
        if event.startAt == event.endAt {
            return calendar.isDate(event.startAt, inSameDayAs: date)
        }
        return event.startAt < day.end && event.endAt > day.start
    }

    func ownerName(for event: CoupleEvent, currentUserId: String?, members: [LongdyUser]) -> String {
        if event.ownerUserId == currentUserId {
            return "내 일정"
        }
        return members.first { $0.id == event.ownerUserId }?.friendlyName ?? "상대 일정"
    }

    func saveEvent(userId: String?, coupleId: String?, title: String, startAt: Date, endAt: Date, type: EventType, memo: String) async -> CoupleEvent? {
        do {
            errorMessage = nil
            guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw LongdyError.invalidInput("일정 제목이 필요해요.") }
            guard endAt >= startAt else { throw LongdyError.invalidInput("끝 시간이 시작 시간보다 빠를 수 없어요.") }
            guard let userId else { throw LongdyError.missingUser }
            guard let coupleId else { throw LongdyError.missingCouple }
            let event = try await repository.saveEvent(coupleId: coupleId, ownerUserId: userId, title: title, startAt: startAt, endAt: endAt, type: type, memo: memo)
            CoupleDataRefreshCoordinator.shared.requestRefresh()
            return event
        } catch {
            errorMessage = error.longdyUserMessage
            return nil
        }
    }

    func updateEvent(coupleId: String?, currentUserId: String?, event: CoupleEvent, title: String, startAt: Date, endAt: Date, type: EventType, memo: String) async -> CoupleEvent? {
        do {
            errorMessage = nil
            guard event.ownerUserId == currentUserId else {
                throw LongdyError.invalidInput("상대가 등록한 일정은 수정할 수 없어요.")
            }
            guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw LongdyError.invalidInput("일정 제목이 필요해요.") }
            guard endAt >= startAt else { throw LongdyError.invalidInput("끝 시간이 시작 시간보다 빠를 수 없어요.") }
            guard let coupleId else { throw LongdyError.missingCouple }
            let updatedEvent = try await repository.updateEvent(coupleId: coupleId, eventId: event.id, title: title, startAt: startAt, endAt: endAt, type: type, memo: memo)
            CoupleDataRefreshCoordinator.shared.requestRefresh()
            return updatedEvent
        } catch {
            errorMessage = error.longdyUserMessage
            return nil
        }
    }

    func deleteEvent(coupleId: String?, currentUserId: String?, event: CoupleEvent) async -> Bool {
        do {
            errorMessage = nil
            guard event.ownerUserId == currentUserId else {
                throw LongdyError.invalidInput("상대가 등록한 일정은 삭제할 수 없어요.")
            }
            guard let coupleId else { throw LongdyError.missingCouple }
            try await repository.deleteEvent(coupleId: coupleId, eventId: event.id)
            CoupleDataRefreshCoordinator.shared.requestRefresh()
            return true
        } catch {
            errorMessage = error.longdyUserMessage
            return false
        }
    }
}
