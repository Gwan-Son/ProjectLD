import Foundation
import UserNotifications

actor PartnerNotificationService {
    static let shared = PartnerNotificationService()

    enum UpdateKind {
        case mood
        case photo
        case event

        var body: String {
            switch self {
            case .mood: "상대가 지금 기분을 공유했어요."
            case .photo: "오늘의 한 장이 도착했어요."
            case .event: "새로운 일정이 캘린더에 추가됐어요."
            }
        }

        var categoryIdentifier: String {
            switch self {
            case .mood: "PARTNER_MOOD"
            case .photo: "PARTNER_PHOTO"
            case .event: "PARTNER_EVENT"
            }
        }
    }

    private let center = UNUserNotificationCenter.current()

    func requestAuthorizationIfNeeded() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func send(_ kind: UpdateKind) async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
                || settings.authorizationStatus == .ephemeral else { return }

        let content = UNMutableNotificationContent()
        content.title = "Our Bridge"
        content.body = kind.body
        content.sound = .default
        content.threadIdentifier = "partner-updates"
        content.categoryIdentifier = kind.categoryIdentifier

        let request = UNNotificationRequest(
            identifier: "partner-\(kind.categoryIdentifier)-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }
}

@MainActor
final class CloudKitChangeCoordinator {
    static let shared = CloudKitChangeCoordinator()

    var handler: (() async -> Bool)?

    func handleChange() async -> Bool {
        await handler?() ?? false
    }
}
