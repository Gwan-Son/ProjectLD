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

    private let service = CloudKitService.shared

    var todayDateKey: String { DateKey.dateKey() }

    func addCareItem(userId: String?, coupleId: String?) async -> CareItem? {
        do {
            errorMessage = nil
            let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanTitle.isEmpty else { throw LongdyError.invalidInput("챙김 이름을 입력해 주세요.") }
            guard let userId else { throw LongdyError.missingUser }
            guard let coupleId else { throw LongdyError.missingCouple }

            let reminder = reminderEnabled ? Calendar.current.dateComponents([.hour, .minute], from: reminderTime) : nil
            let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
            let itemId = try await service.saveCareItem(
                coupleId: coupleId,
                dateKey: todayDateKey,
                userId: userId,
                title: cleanTitle,
                iconName: selectedIconName,
                repeatRule: repeatRule,
                reminderHour: reminder?.hour,
                reminderMinute: reminder?.minute,
                note: cleanNote
            )
            if reminderEnabled, let hour = reminder?.hour, let minute = reminder?.minute {
                await scheduleNotification(itemId: itemId, title: cleanTitle, hour: hour, minute: minute, repeatRule: repeatRule)
            }
            let item = CareItem(
                id: itemId,
                userId: userId,
                dateKey: todayDateKey,
                title: cleanTitle,
                iconName: selectedIconName,
                repeatRule: repeatRule,
                reminderHour: reminder?.hour,
                reminderMinute: reminder?.minute,
                note: cleanNote,
                doneDateKeys: [],
                createdAt: Date()
            )
            NotificationCenter.default.post(name: .longdyShouldRefreshCoupleData, object: nil)
            title = ""
            note = ""
            reminderEnabled = false
            return item
        } catch {
            errorMessage = error.longdyUserMessage
            return nil
        }
    }

    func toggleCareItem(coupleId: String?, item: CareItem) async -> Bool {
        do {
            errorMessage = nil
            guard let coupleId else { throw LongdyError.missingCouple }
            try await service.updateCareItem(coupleId: coupleId, itemId: item.id, dateKey: todayDateKey, isDone: !item.isDoneToday)
            NotificationCenter.default.post(name: .longdyShouldRefreshCoupleData, object: nil)
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
            try await service.updateCareItemDetails(
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
            NotificationCenter.default.post(name: .longdyShouldRefreshCoupleData, object: nil)
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
            try await service.deleteCareItem(coupleId: coupleId, itemId: item.id)
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: notificationIdentifiers(for: item.id))
            NotificationCenter.default.post(name: .longdyShouldRefreshCoupleData, object: nil)
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
