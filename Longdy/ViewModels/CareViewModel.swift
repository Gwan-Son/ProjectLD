import Combine
import Foundation
import UserNotifications

@MainActor
final class CareViewModel: ObservableObject {
    @Published var title = ""
    @Published var selectedIconName = "drink-water"
    @Published var repeatRule: CareRepeatRule = .once
    @Published var reminderEnabled = false
    @Published var reminderTime = Date()
    @Published var note = ""
    @Published var errorMessage: String?

    private let repository: any CareRepository

    init(repository: any CareRepository = DependencyContainer.live.careRepository) {
        self.repository = repository
    }

    var todayDateKey: String { DateKey.dateKey() }

    func makePendingCareItem(userId: String?) -> CareItem? {
        do {
            errorMessage = nil
            let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanTitle.isEmpty else { throw LongdyError.invalidInput("챙김 이름을 입력해 주세요.") }
            guard let userId else { throw LongdyError.missingUser }

            let reminder = reminderEnabled ? Calendar.current.dateComponents([.hour, .minute], from: reminderTime) : nil
            let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
            let item = CareItem(
                id: "careItem-\(UUID().uuidString)",
                userId: userId,
                dateKey: todayDateKey,
                title: cleanTitle,
                iconName: selectedIconName,
                repeatRule: repeatRule,
                reminderHour: reminder?.hour,
                reminderMinute: reminder?.minute,
                note: cleanNote,
                doneDateKeys: [],
                createdAt: Date(),
                syncState: .pending
            )
            resetComposer()
            return item
        } catch {
            errorMessage = error.longdyUserMessage
            return nil
        }
    }

    func persistCareItem(coupleId: String?, item: CareItem) async -> CareItem {
        var result = item
        result.syncState = .pending
        do {
            errorMessage = nil
            guard let coupleId else { throw LongdyError.missingCouple }
            _ = try await repository.saveCareItem(
                coupleId: coupleId,
                itemId: item.id,
                dateKey: item.dateKey,
                userId: item.userId,
                title: item.title,
                iconName: item.iconName,
                repeatRule: item.repeatRule,
                reminderHour: item.reminderHour,
                reminderMinute: item.reminderMinute,
                note: item.note
            )
            if let hour = item.reminderHour, let minute = item.reminderMinute {
                await scheduleNotification(
                    itemId: item.id,
                    title: item.title,
                    hour: hour,
                    minute: minute,
                    repeatRule: item.repeatRule
                )
            }
            result.syncState = nil
            return result
        } catch {
            result.syncState = .failed
            errorMessage = error.longdyUserMessage
            return result
        }
    }

    private func resetComposer() {
            title = ""
            note = ""
            reminderEnabled = false
    }

    func toggleCareItem(coupleId: String?, item: CareItem) async -> Bool {
        do {
            errorMessage = nil
            guard let coupleId else { throw LongdyError.missingCouple }
            try await repository.updateCareItem(coupleId: coupleId, itemId: item.id, dateKey: todayDateKey, isDone: !item.isDoneToday)
            CoupleDataRefreshCoordinator.shared.requestRefresh()
            return true
        } catch {
            errorMessage = error.longdyUserMessage
            return false
        }
    }

    func editCareItem(
        coupleId: String?,
        item: CareItem,
        title: String,
        iconName: String,
        repeatRule: CareRepeatRule,
        reminderEnabled: Bool,
        reminderTime: Date,
        note: String
    ) async -> Bool {
        do {
            errorMessage = nil
            guard let coupleId else { throw LongdyError.missingCouple }
            let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanTitle.isEmpty else { throw LongdyError.invalidInput("챙김 이름을 입력해 주세요.") }

            let reminder = reminderEnabled
                ? Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
                : nil
            try await repository.updateCareItemDetails(
                coupleId: coupleId,
                itemId: item.id,
                title: cleanTitle,
                iconName: iconName,
                repeatRule: repeatRule,
                reminderHour: reminder?.hour,
                reminderMinute: reminder?.minute,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines)
            )

            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: notificationIdentifiers(for: item.id))
            if reminderEnabled, let hour = reminder?.hour, let minute = reminder?.minute {
                await scheduleNotification(
                    itemId: item.id,
                    title: cleanTitle,
                    hour: hour,
                    minute: minute,
                    repeatRule: repeatRule
                )
            }
            CoupleDataRefreshCoordinator.shared.requestRefresh()
            return errorMessage == nil
        } catch {
            errorMessage = error.longdyUserMessage
            return false
        }
    }

    func deleteCareItem(coupleId: String?, item: CareItem) async -> Bool {
        do {
            errorMessage = nil
            guard let coupleId else { throw LongdyError.missingCouple }
            try await repository.deleteCareItem(coupleId: coupleId, itemId: item.id)
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: notificationIdentifiers(for: item.id))
            CoupleDataRefreshCoordinator.shared.requestRefresh()
            return true
        } catch {
            errorMessage = error.longdyUserMessage
            return false
        }
    }

    private func scheduleNotification(itemId: String, title: String, hour: Int, minute: Int, repeatRule: CareRepeatRule) async {
        do {
            let center = UNUserNotificationCenter.current()
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else { return }

            let content = UNMutableNotificationContent()
            content.title = "Longdy 챙김"
            content.body = title
            content.sound = .default

            for weekday in notificationWeekdays(for: repeatRule) {
                var components = DateComponents()
                components.hour = hour
                components.minute = minute
                components.weekday = weekday
                if repeatRule == .once {
                    let today = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                    components.year = today.year
                    components.month = today.month
                    components.day = today.day
                }

                let repeats = repeatRule != .once
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
                let requestId = weekday.map { "\(itemId)-\($0)" } ?? itemId
                let request = UNNotificationRequest(identifier: requestId, content: content, trigger: trigger)
                try await center.add(request)
            }
        } catch {
            errorMessage = error.longdyUserMessage
        }
    }

    private func notificationWeekdays(for repeatRule: CareRepeatRule) -> [Int?] {
        switch repeatRule {
        case .once, .daily:
            return [nil]
        case .weekdays:
            return [2, 3, 4, 5, 6]
        case .weekends:
            return [1, 7]
        case .weekly:
            return [Calendar.current.component(.weekday, from: Date())]
        }
    }

    private func notificationIdentifiers(for itemId: String) -> [String] {
        [itemId] + (1...7).map { "\(itemId)-\($0)" }
    }
}
