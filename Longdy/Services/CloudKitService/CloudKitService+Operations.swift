import CloudKit
import Foundation

extension CloudKitService {
    func fetchRecord(recordID: CKRecord.ID) async throws -> CKRecord? {
        try await fetchRecord(recordID: recordID, database: privateDatabase)
    }

    func fetchRecord(recordID: CKRecord.ID, database: CKDatabase) async throws -> CKRecord? {
        try await withCheckedThrowingContinuation { continuation in
            database.fetch(withRecordID: recordID) { record, error in
                if let ckError = error as? CKError, ckError.code == .unknownItem {
                    continuation.resume(returning: nil)
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: record)
                }
            }
        }
    }

    func fetchSharedRecordZones() async throws -> [CKRecordZone] {
        try await withCheckedThrowingContinuation { continuation in
            sharedDatabase.fetchAllRecordZones { zones, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: zones ?? [])
                }
            }
        }
    }

    func fetchRequiredRecord(recordID: CKRecord.ID, database: CKDatabase) async throws -> CKRecord {
        guard let record = try await fetchRecord(recordID: recordID, database: database) else {
            throw LongdyError.invalidInput("공유된 커플 공간을 찾을 수 없어요.")
        }
        return record
    }

    func accept(metadata: CKShare.Metadata) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let operation = CKAcceptSharesOperation(shareMetadatas: [metadata])
            operation.acceptSharesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            container.add(operation)
        }
    }

    func ensureAccountAvailable() async throws {
        let status = try await fetchAccountStatus()
        guard status == .available else {
            throw LongdyError.invalidInput("iCloud 계정을 사용할 수 없어요. iCloud 로그인과 CloudKit 설정을 확인해 주세요.")
        }
    }

    func ensureCoupleZone() async throws {
        try await withCheckedThrowingContinuation { continuation in
            privateDatabase.save(CKRecordZone(zoneID: coupleZoneID)) { _, error in
                if let ckError = error as? CKError, ckError.code == .serverRecordChanged {
                    continuation.resume()
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func updateUserCoupleRoot(session: AppleSession, coupleRootRecordName: String) async throws {
        let record = try await fetchRecord(recordID: currentUserProfileRecordID)
            ?? CKRecord(recordType: RecordType.userProfile, recordID: currentUserProfileRecordID)
        let now = Date()
        let displayName = profileName(
            preferred: stringValue(record[UserProfileField.displayName]),
            session: session
        )
        let nickname = profileName(
            preferred: stringValue(record[UserProfileField.nickname]),
            fallback: displayName,
            session: session
        )
        record[UserProfileField.appleUserId] = session.appleUserId as CKRecordValue
        record[UserProfileField.email] = session.email as CKRecordValue?
        record[UserProfileField.displayName] = displayName as CKRecordValue
        record[UserProfileField.nickname] = nickname as CKRecordValue
        record[UserProfileField.cityName] = (record[UserProfileField.cityName] as? String ?? "Seoul") as CKRecordValue
        record[UserProfileField.timezoneId] = (record[UserProfileField.timezoneId] as? String ?? TimeZone.current.identifier) as CKRecordValue
        record[UserProfileField.coupleRootRecordName] = coupleRootRecordName as CKRecordValue
        if record[UserProfileField.createdAt] == nil {
            record[UserProfileField.createdAt] = now as CKRecordValue
        }
        record[UserProfileField.updatedAt] = now as CKRecordValue
        _ = try await save(record)
    }

    func clearUserCoupleRoot(session: AppleSession) async throws {
        let record = try await fetchRecord(recordID: currentUserProfileRecordID)
            ?? CKRecord(recordType: RecordType.userProfile, recordID: currentUserProfileRecordID)
        let now = Date()
        let displayName = profileName(
            preferred: stringValue(record[UserProfileField.displayName]),
            session: session
        )
        let nickname = profileName(
            preferred: stringValue(record[UserProfileField.nickname]),
            fallback: displayName,
            session: session
        )
        record[UserProfileField.appleUserId] = session.appleUserId as CKRecordValue
        record[UserProfileField.email] = session.email as CKRecordValue?
        record[UserProfileField.displayName] = displayName as CKRecordValue
        record[UserProfileField.nickname] = nickname as CKRecordValue
        record[UserProfileField.cityName] = (record[UserProfileField.cityName] as? String ?? "Seoul") as CKRecordValue
        record[UserProfileField.timezoneId] = (record[UserProfileField.timezoneId] as? String ?? TimeZone.current.identifier) as CKRecordValue
        record[UserProfileField.coupleRootRecordName] = nil
        if record[UserProfileField.createdAt] == nil {
            record[UserProfileField.createdAt] = now as CKRecordValue
        }
        record[UserProfileField.updatedAt] = now as CKRecordValue
        _ = try await save(record)
    }

    func save(_ record: CKRecord) async throws -> CKRecord {
        try await save(record, database: privateDatabase)
    }

    func save(_ record: CKRecord, database: CKDatabase) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { continuation in
            database.save(record) { savedRecord, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let savedRecord {
                    continuation.resume(returning: savedRecord)
                } else {
                    continuation.resume(throwing: LongdyError.invalidInput("CloudKit 프로필 저장에 실패했어요."))
                }
            }
        }
    }

    func delete(recordID: CKRecord.ID, database: CKDatabase) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            database.delete(withRecordID: recordID) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func deleteIfExists(recordID: CKRecord.ID, database: CKDatabase) async throws {
        do {
            try await delete(recordID: recordID, database: database)
        } catch let error as CKError where error.code == .unknownItem {
            return
        }
    }

    func deleteUnpairedPrivateCoupleRootIfNeeded(coupleId: String, session: AppleSession) async throws {
        guard !coupleId.hasPrefix("shared|") else { return }
        let ref = coupleReference(from: coupleId)
        guard let currentRoot = try await fetchRecord(recordID: ref.recordID, database: ref.database) else { return }
        let ownerId = stringValue(currentRoot[CoupleRootField.ownerAppleUserId])
        let partnerId = stringValue(currentRoot[CoupleRootField.partnerAppleUserId])
        guard ownerId == session.appleUserId, partnerId == nil else { return }
        try await deleteIfExists(recordID: ref.recordID, database: ref.database)
    }

    func savePublicInviteCode(code: String, ownerAppleUserId: String, shareURL: URL?) async throws {
        guard let shareURL else {
            throw LongdyError.invalidInput("초대 링크 생성에 실패했어요. 다시 시도해 주세요.")
        }
        let recordID = CKRecord.ID(recordName: inviteCodeRecordName(code))
        let record = CKRecord(recordType: RecordType.inviteCode, recordID: recordID)
        let now = Date()
        record[InviteCodeField.code] = code as CKRecordValue
        record[InviteCodeField.ownerAppleUserId] = ownerAppleUserId as CKRecordValue
        record[InviteCodeField.shareURL] = shareURL.absoluteString as CKRecordValue
        record[InviteCodeField.expiresAt] = Calendar.current.date(byAdding: .hour, value: 24, to: now)! as CKRecordValue
        record[InviteCodeField.createdAt] = now as CKRecordValue
        do {
            _ = try await save(record, database: publicDatabase)
        } catch let error as CKError where error.code == .permissionFailure {
            throw LongdyError.invalidInput("CloudKit Public Database의 InviteCode 쓰기 권한이 필요해요. iCloud Console에서 Authenticated 역할의 Create/Write 권한을 켜 주세요.")
        }
    }

    func fetchRequiredInviteCode(code: String) async throws -> CKRecord {
        guard let record = try await fetchRecord(
            recordID: CKRecord.ID(recordName: inviteCodeRecordName(code)),
            database: publicDatabase
        ) else {
            throw LongdyError.invalidInviteCode
        }
        return record
    }

    func inviteCodeRecordName(_ code: String) -> String {
        "inviteCode-\(code)"
    }


    func updateCoupleDate(coupleId: String, key: String, date: Date) async throws {
        let ref = coupleReference(from: coupleId)
        let record = try await fetchRequiredRecord(recordID: ref.recordID, database: ref.database)
        record[key] = date as CKRecordValue
        record[CoupleRootField.updatedAt] = Date() as CKRecordValue
        _ = try await save(record, database: ref.database)
    }

    func attachToCoupleRoot(_ record: CKRecord, ref: (database: CKDatabase, recordID: CKRecord.ID)) {
        record.parent = CKRecord.Reference(recordID: ref.recordID, action: .none)
        record[SharedField.coupleRootRecordName] = ref.recordID.recordName as CKRecordValue
    }

    func fillEvent(_ record: CKRecord, coupleRootRecordName: String, ownerUserId: String, title: String, startAt: Date, endAt: Date, type: EventType, memo: String) {
        record[SharedField.coupleRootRecordName] = coupleRootRecordName as CKRecordValue
        if !ownerUserId.isEmpty {
            record["ownerUserId"] = ownerUserId as CKRecordValue
        }
        record["title"] = title as CKRecordValue
        record["startAt"] = startAt as CKRecordValue
        record["endAt"] = endAt as CKRecordValue
        record["type"] = type.rawValue as CKRecordValue
        record["memo"] = memo as CKRecordValue
        if record[SharedField.createdAt] == nil {
            record[SharedField.createdAt] = Date() as CKRecordValue
        }
        record[SharedField.updatedAt] = Date() as CKRecordValue
    }

    func modify(recordsToSave: [CKRecord], recordIDsToDelete: [CKRecord.ID]) async throws -> [CKRecord] {
        try await withCheckedThrowingContinuation { continuation in
            let operation = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: recordIDsToDelete)
            operation.savePolicy = .changedKeys
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: recordsToSave)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            privateDatabase.add(operation)
        }
    }

    var currentUserProfileRecordID: CKRecord.ID {
        CKRecord.ID(recordName: "currentUserProfile")
    }

    var coupleZoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: "LongdyCoupleZone", ownerName: CKCurrentUserDefaultName)
    }

    func coupleReference(for recordID: CKRecord.ID, databaseScope: CKDatabase.Scope) -> String {
        [
            databaseScope == .shared ? "shared" : "private",
            recordID.zoneID.ownerName,
            recordID.zoneID.zoneName,
            recordID.recordName
        ].joined(separator: "|")
    }

    func coupleReference(from value: String) -> (database: CKDatabase, recordID: CKRecord.ID) {
        let parts = value.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 4 else {
            return (privateDatabase, CKRecord.ID(recordName: value, zoneID: coupleZoneID))
        }
        let database = parts[0] == "shared" ? sharedDatabase : privateDatabase
        let zoneID = CKRecordZone.ID(zoneName: parts[2], ownerName: parts[1])
        return (database, CKRecord.ID(recordName: parts[3], zoneID: zoneID))
    }

    func databaseScope(fromCoupleReference value: String) -> CKDatabase.Scope {
        value.hasPrefix("shared|") ? .shared : .private
    }

    static func makeInviteCode() -> String {
        String((0..<6).map { _ in "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".randomElement() ?? "A" })
    }

    static func normalizedInviteCode(_ value: String) -> String {
        value
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }
            .map { character -> Character in
                switch character {
                case "0": "O"
                case "1", "I": "L"
                default: character
                }
            }
            .reduce(into: "") { $0.append($1) }
    }

    static func dateKey(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
