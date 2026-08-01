import CloudKit
import Foundation

extension CloudKitService {
    func ensureChangeSubscriptions() async throws {
        async let privateSubscription: Void = ensureDatabaseSubscription(
            id: "longdy.private.database.changes",
            database: privateDatabase,
            alertBody: nil
        )
        async let sharedSubscription: Void = ensureDatabaseSubscription(
            id: "longdy.shared.database.changes.visible.v2",
            database: sharedDatabase,
            alertBody: "상대의 새로운 소식이 도착했어요."
        )
        async let privateMemorySubscription: Void = ensureRecordTypeSubscription(
            id: "longdy.private.memory.changes",
            recordType: RecordType.memoryNote,
            database: privateDatabase,
            alertBody: nil
        )
        _ = try await (
            privateSubscription,
            sharedSubscription,
            privateMemorySubscription
        )
    }

    func ensureDatabaseSubscription(id: String, database: CKDatabase, alertBody: String?) async throws {
        if (try? await fetchSubscription(id: id, database: database)) != nil {
            return
        }

        let subscription = CKDatabaseSubscription(subscriptionID: id)
        let notificationInfo = notificationInfo(alertBody: alertBody)
        subscription.notificationInfo = notificationInfo
        let _: CKSubscription? = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKSubscription?, Error>) in
            database.save(subscription) { subscription, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: subscription)
                }
            }
        }
    }

    func ensureRecordTypeSubscription(id: String, recordType: String, database: CKDatabase, alertBody: String?) async throws {
        if (try? await fetchSubscription(id: id, database: database)) != nil {
            return
        }

        let subscription = CKQuerySubscription(
            recordType: recordType,
            predicate: NSPredicate(value: true),
            subscriptionID: id,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        let notificationInfo = notificationInfo(alertBody: alertBody)
        subscription.notificationInfo = notificationInfo
        let _: CKSubscription? = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKSubscription?, Error>) in
            database.save(subscription) { subscription, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: subscription)
                }
            }
        }
    }

    func fetchSubscription(id: String, database: CKDatabase) async throws -> CKSubscription? {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKSubscription?, Error>) in
            database.fetch(withSubscriptionID: id) { subscription, error in
                if let error = error as? CKError, error.code == .unknownItem {
                    continuation.resume(returning: nil)
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: subscription)
                }
            }
        }
    }

    func isMissingRecordTypeError(_ error: Error) -> Bool {
        let message = error.localizedDescription
        return message.contains("Did not find record type")
            || message.contains("record type")
            && message.contains("not found")
    }

    private func notificationInfo(alertBody: String?) -> CKSubscription.NotificationInfo {
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        if let alertBody {
            notificationInfo.title = "Our Bridge"
            notificationInfo.alertBody = alertBody
            notificationInfo.soundName = "default"
        }
        return notificationInfo
    }
}
