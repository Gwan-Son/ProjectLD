import CloudKit
import Foundation

extension CloudKitService {
    func deleteAccount(session: AppleSession, coupleId: String?) async throws {
        try await ensureAccountAvailable()

        if let coupleId {
            let ref = coupleReference(from: coupleId)
            let rootRecord: CKRecord?
            do {
                rootRecord = try await fetchRecord(recordID: ref.recordID, database: ref.database)
            } catch let error as CKError where isRevokedCoupleAccessError(error) {
                rootRecord = nil
            }

            if let rootRecord {
                let ownerId = stringValue(rootRecord[CoupleRootField.ownerAppleUserId])
                let partnerId = stringValue(rootRecord[CoupleRootField.partnerAppleUserId])
                if ownerId == session.appleUserId {
                    _ = try await deleteCoupleSpace(coupleId: coupleId, session: session)
                } else if partnerId == session.appleUserId {
                    try await deleteMemberRecords(coupleId: coupleId, userId: session.appleUserId)
                    _ = try await disconnectCouple(coupleId: coupleId, session: session)
                }
            }
        }

        try await deleteIfExists(recordID: currentUserProfileRecordID, database: privateDatabase)
        clearLocalAssetsAfterCoupleDeletion()
    }

    private func deleteMemberRecords(coupleId: String, userId: String) async throws {
        let ref = coupleReference(from: coupleId)
        let ownershipFields = [
            RecordType.checkIn: SharedField.appleUserId,
            RecordType.coupleEvent: "ownerUserId",
            RecordType.careItem: SharedField.appleUserId,
            RecordType.memoryNote: SharedField.appleUserId,
            RecordType.bridgeActivity: SharedField.appleUserId
        ]
        var recordIDs: [CKRecord.ID] = []

        for (recordType, ownershipField) in ownershipFields {
            let records = try await optionalQueryRecords(
                type: recordType,
                coupleId: coupleId,
                database: ref.database
            )
            recordIDs.append(contentsOf: records.compactMap { record in
                stringValue(record[ownershipField]) == userId ? record.recordID : nil
            })
        }
        try await deleteRecords(recordIDs, database: ref.database)
    }

    func resetUserProfileAfterCoupleDeletion(session: AppleSession) async throws -> LongdyUser {
        let record = try await fetchRecord(recordID: currentUserProfileRecordID)
            ?? CKRecord(recordType: RecordType.userProfile, recordID: currentUserProfileRecordID)
        let now = Date()

        record[UserProfileField.appleUserId] = session.appleUserId as CKRecordValue
        record[UserProfileField.email] = session.email as CKRecordValue?
        record[UserProfileField.displayName] = "나" as CKRecordValue
        record[UserProfileField.nickname] = "나" as CKRecordValue
        record[UserProfileField.profilePhotoAsset] = nil
        record[UserProfileField.coupleRootRecordName] = nil
        if record[UserProfileField.createdAt] == nil {
            record[UserProfileField.createdAt] = now as CKRecordValue
        }
        record[UserProfileField.updatedAt] = now as CKRecordValue

        let savedRecord = try await save(record)
        clearLocalAssetsAfterCoupleDeletion()
        return decodeUserProfile(from: savedRecord, session: session)
    }

    func clearLocalAssetsAfterCoupleDeletion() {
        guard let cachesDirectory = try? FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return }

        ["ProfilePhotos", "MemoryAssets", "PendingMemoryUploads"]
            .map { cachesDirectory.appendingPathComponent($0, isDirectory: true) }
            .forEach { try? FileManager.default.removeItem(at: $0) }
    }

    func upsertUserProfile(session: AppleSession, nickname: String? = nil, cityName: String = "Seoul", timezoneId: String = TimeZone.current.identifier) async throws -> LongdyUser {
        let status = try await fetchAccountStatus()
        guard status == .available else {
            throw LongdyError.invalidInput("iCloud 계정을 사용할 수 없어요. iCloud 로그인과 CloudKit 설정을 확인해 주세요.")
        }

        let recordID = CKRecord.ID(recordName: "currentUserProfile")
        let record = try await fetchRecord(recordID: recordID)
            ?? CKRecord(recordType: RecordType.userProfile, recordID: recordID)
        let now = Date()

        let displayName = profileName(
            preferred: stringValue(record[UserProfileField.displayName]),
            session: session
        )
        let nickname = profileName(
            preferred: nickname,
            existing: stringValue(record[UserProfileField.nickname]),
            fallback: displayName,
            session: session
        )

        record[UserProfileField.appleUserId] = session.appleUserId as CKRecordValue
        record[UserProfileField.email] = session.email as CKRecordValue?
        record[UserProfileField.displayName] = displayName as CKRecordValue
        record[UserProfileField.nickname] = nickname as CKRecordValue
        record[UserProfileField.cityName] = cityName as CKRecordValue
        record[UserProfileField.timezoneId] = timezoneId as CKRecordValue
        if record[UserProfileField.createdAt] == nil {
            record[UserProfileField.createdAt] = now as CKRecordValue
        }
        record[UserProfileField.updatedAt] = now as CKRecordValue

        let savedRecord = try await save(record)
        let user = decodeUserProfile(from: savedRecord, session: session)
        try await updateCoupleMemberSnapshotIfNeeded(user: user)
        return user
    }

    func fetchCurrentUserProfile(session: AppleSession) async throws -> LongdyUser? {
        guard let record = try await fetchRecord(recordID: currentUserProfileRecordID) else {
            return nil
        }
        return decodeUserProfile(from: record, session: session)
    }

    func updateUserLocation(session: AppleSession, latitude: Double, longitude: Double, timezoneId: String) async throws -> LongdyUser {
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
        record[UserProfileField.timezoneId] = timezoneId as CKRecordValue
        record[UserProfileField.latitude] = latitude as CKRecordValue
        record[UserProfileField.longitude] = longitude as CKRecordValue
        record[UserProfileField.locationUpdatedAt] = now as CKRecordValue
        if record[UserProfileField.createdAt] == nil {
            record[UserProfileField.createdAt] = now as CKRecordValue
        }
        record[UserProfileField.updatedAt] = now as CKRecordValue

        let savedRecord = try await save(record)
        let user = decodeUserProfile(from: savedRecord, session: session)
        try await updateCoupleMemberSnapshotIfNeeded(user: user)
        return user
    }

    func updateUserProfile(session: AppleSession, nickname: String? = nil, cityName: String? = nil, timezoneId: String? = nil) async throws -> LongdyUser {
        let record = try await fetchRecord(recordID: currentUserProfileRecordID)
            ?? CKRecord(recordType: RecordType.userProfile, recordID: currentUserProfileRecordID)
        let now = Date()

        let displayName = profileName(
            preferred: stringValue(record[UserProfileField.displayName]),
            session: session
        )
        let nickname = profileName(
            preferred: nickname,
            existing: stringValue(record[UserProfileField.nickname]),
            fallback: displayName,
            session: session
        )

        record[UserProfileField.appleUserId] = session.appleUserId as CKRecordValue
        record[UserProfileField.email] = session.email as CKRecordValue?
        record[UserProfileField.displayName] = displayName as CKRecordValue
        record[UserProfileField.nickname] = nickname as CKRecordValue
        if let cityName {
            record[UserProfileField.cityName] = cityName as CKRecordValue
        } else if record[UserProfileField.cityName] == nil {
            record[UserProfileField.cityName] = "Seoul" as CKRecordValue
        }
        if let timezoneId {
            record[UserProfileField.timezoneId] = timezoneId as CKRecordValue
        } else if record[UserProfileField.timezoneId] == nil {
            record[UserProfileField.timezoneId] = TimeZone.current.identifier as CKRecordValue
        }
        if record[UserProfileField.createdAt] == nil {
            record[UserProfileField.createdAt] = now as CKRecordValue
        }
        record[UserProfileField.updatedAt] = now as CKRecordValue

        let savedRecord = try await save(record)
        let user = decodeUserProfile(from: savedRecord, session: session)
        try await updateCoupleMemberSnapshotIfNeeded(user: user)
        return user
    }

    func updateUserProfilePhoto(session: AppleSession, fileData: Data?) async throws -> LongdyUser {
        guard let record = try await fetchRecord(recordID: currentUserProfileRecordID) else {
            throw LongdyError.missingUser
        }

        var temporaryURL: URL?
        if let fileData {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("profile-\(UUID().uuidString)")
                .appendingPathExtension("jpg")
            try fileData.write(to: url, options: .atomic)
            temporaryURL = url
            record[UserProfileField.profilePhotoAsset] = CKAsset(fileURL: url)
        } else {
            record[UserProfileField.profilePhotoAsset] = nil
        }
        record[UserProfileField.updatedAt] = Date() as CKRecordValue

        defer {
            if let temporaryURL {
                try? FileManager.default.removeItem(at: temporaryURL)
            }
        }

        let savedRecord = try await save(record)
        let user = decodeUserProfile(from: savedRecord, session: session)
        try await updateCoupleMemberProfilePhotoIfNeeded(user: user, fileData: fileData)
        return user
    }

    private func updateCoupleMemberProfilePhotoIfNeeded(user: LongdyUser, fileData: Data?) async throws {
        guard let coupleId = user.partnerCoupleId else { return }
        let ref = coupleReference(from: coupleId)
        guard let rootRecord = try await fetchRecord(recordID: ref.recordID, database: ref.database) else { return }
        let ownerId = stringValue(rootRecord[CoupleRootField.ownerAppleUserId])
        let partnerId = stringValue(rootRecord[CoupleRootField.partnerAppleUserId])

        let prefix: MemberSnapshotPrefix
        if ownerId == user.id {
            prefix = .owner
        } else if partnerId == user.id {
            prefix = .partner
        } else {
            return
        }

        let photoField = memberSnapshotFields(for: prefix).profilePhotoAsset
        var temporaryURL: URL?
        if let fileData {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("shared-profile-\(UUID().uuidString)")
                .appendingPathExtension("jpg")
            try fileData.write(to: url, options: .atomic)
            temporaryURL = url
            rootRecord[photoField] = CKAsset(fileURL: url)
        } else {
            rootRecord[photoField] = nil
        }
        rootRecord[CoupleRootField.updatedAt] = Date() as CKRecordValue

        defer {
            if let temporaryURL {
                try? FileManager.default.removeItem(at: temporaryURL)
            }
        }
        _ = try await save(rootRecord, database: ref.database)
    }
}
