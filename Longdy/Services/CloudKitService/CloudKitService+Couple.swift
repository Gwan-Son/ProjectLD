import CloudKit
import Foundation

extension CloudKitService {
    func fetchCoupleRoot(recordName: String) async throws -> Couple? {
        let reference = coupleReference(from: recordName)
        if let record = try await fetchRecord(recordID: reference.recordID, database: reference.database) {
            return decodeCoupleRoot(from: record, databaseScope: databaseScope(fromCoupleReference: recordName), shareURL: nil)
        }

        guard !recordName.contains("|") else { return nil }
        for zone in try await fetchSharedRecordZones() {
            let sharedRecordID = CKRecord.ID(recordName: recordName, zoneID: zone.zoneID)
            if let record = try await fetchRecord(recordID: sharedRecordID, database: sharedDatabase) {
                return decodeCoupleRoot(from: record, databaseScope: .shared, shareURL: nil)
            }
        }
        return nil
    }

    func fetchShareMetadata(from url: URL) async throws -> CKShare.Metadata {
        try await container.shareMetadata(for: url)
    }

    func acceptShare(metadata: CKShare.Metadata, session: AppleSession, replacingCurrentCoupleId: String? = nil) async throws -> Couple {
        try await accept(metadata: metadata)
        guard let rootRecordID = metadata.hierarchicalRootRecordID else {
            throw LongdyError.invalidInviteCode
        }
        let rootRecord = try await fetchRequiredRecord(recordID: rootRecordID, database: sharedDatabase)
        let ownerId = stringValue(rootRecord[CoupleRootField.ownerAppleUserId])
        let existingPartnerId = stringValue(rootRecord[CoupleRootField.partnerAppleUserId])
        guard ownerId != session.appleUserId else {
            throw LongdyError.invalidInput("내가 만든 초대는 직접 수락할 수 없어요.")
        }
        if let existingPartnerId, existingPartnerId != session.appleUserId {
            throw LongdyError.coupleFull
        }
        rootRecord[CoupleRootField.partnerAppleUserId] = session.appleUserId as CKRecordValue
        rootRecord[CoupleRootField.updatedAt] = Date() as CKRecordValue
        if let userRecord = try await fetchRecord(recordID: currentUserProfileRecordID) {
            fillMemberSnapshot(
                in: rootRecord,
                prefix: .partner,
                user: decodeUserProfile(from: userRecord, session: session)
            )
        }
        let savedRoot = try await save(rootRecord, database: sharedDatabase)
        try await updateUserCoupleRoot(session: session, coupleRootRecordName: coupleReference(for: savedRoot.recordID, databaseScope: .shared))
        if let replacingCurrentCoupleId {
            try await deleteUnpairedPrivateCoupleRootIfNeeded(coupleId: replacingCurrentCoupleId, session: session)
        }
        return decodeCoupleRoot(from: savedRoot, databaseScope: .shared, shareURL: metadata.share.url)
    }

    func createCoupleRootShare(session: AppleSession) async throws -> (couple: Couple, share: CKShare) {
        try await ensureAccountAvailable()
        try await ensureCoupleZone()

        let now = Date()
        let recordID = CKRecord.ID(recordName: "coupleRoot-\(UUID().uuidString)", zoneID: coupleZoneID)
        let rootRecord = CKRecord(recordType: RecordType.coupleRoot, recordID: recordID)
        let inviteCode = Self.makeInviteCode()
        rootRecord[CoupleRootField.ownerAppleUserId] = session.appleUserId as CKRecordValue
        rootRecord[CoupleRootField.inviteCode] = inviteCode as CKRecordValue
        rootRecord[CoupleRootField.createdAt] = now as CKRecordValue
        rootRecord[CoupleRootField.updatedAt] = now as CKRecordValue
        if let userRecord = try await fetchRecord(recordID: currentUserProfileRecordID) {
            fillMemberSnapshot(
                in: rootRecord,
                prefix: .owner,
                user: decodeUserProfile(from: userRecord, session: session)
            )
        }

        let share = CKShare(rootRecord: rootRecord)
        share[CKShare.SystemFieldKey.title] = "Our Bridge 초대" as CKRecordValue
        share[CKShare.SystemFieldKey.shareType] = "kr.gwanson.Longdy.couple" as CKRecordValue
        share.publicPermission = .readWrite

        let savedRecords = try await modify(recordsToSave: [rootRecord, share], recordIDsToDelete: [])
        let savedRoot = savedRecords.first { $0.recordID == rootRecord.recordID } ?? rootRecord
        let savedShare = (savedRecords.first { $0 is CKShare } as? CKShare) ?? share
        try await updateUserCoupleRoot(session: session, coupleRootRecordName: coupleReference(for: savedRoot.recordID, databaseScope: .private))
        try await savePublicInviteCode(code: inviteCode, ownerAppleUserId: session.appleUserId, shareURL: savedShare.url)

        return (decodeCoupleRoot(from: savedRoot, databaseScope: .private, shareURL: nil), savedShare)
    }

    func regenerateCoupleRootShare(session: AppleSession, currentCoupleId: String?) async throws -> (couple: Couple, share: CKShare) {
        try await ensureAccountAvailable()
        try await ensureCoupleZone()

        guard let currentCoupleId else {
            return try await createCoupleRootShare(session: session)
        }

        let ref = coupleReference(from: currentCoupleId)
        guard ref.database.databaseScope == .private,
              let rootRecord = try await fetchRecord(recordID: ref.recordID, database: ref.database) else {
            return try await createCoupleRootShare(session: session)
        }
        guard stringValue(rootRecord[CoupleRootField.ownerAppleUserId]) == session.appleUserId else {
            throw LongdyError.invalidInput("커플 공간을 만든 사람만 초대를 재생성할 수 있어요.")
        }
        guard stringValue(rootRecord[CoupleRootField.partnerAppleUserId]) == nil else {
            throw LongdyError.invalidInput("이미 연결된 커플 공간은 초대를 재생성할 수 없어요.")
        }

        if let oldCode = stringValue(rootRecord[CoupleRootField.inviteCode]) {
            try await deleteIfExists(
                recordID: CKRecord.ID(recordName: inviteCodeRecordName(oldCode)),
                database: publicDatabase
            )
        }

        let inviteCode = Self.makeInviteCode()
        rootRecord[CoupleRootField.inviteCode] = inviteCode as CKRecordValue
        rootRecord[CoupleRootField.updatedAt] = Date() as CKRecordValue

        let share: CKShare
        if let shareRecordID = rootRecord.share?.recordID,
           let existingShare = try await fetchRecord(recordID: shareRecordID, database: privateDatabase) as? CKShare {
            share = existingShare
        } else {
            share = CKShare(rootRecord: rootRecord)
            share[CKShare.SystemFieldKey.title] = "Our Bridge 초대" as CKRecordValue
            share[CKShare.SystemFieldKey.shareType] = "kr.gwanson.Longdy.couple" as CKRecordValue
        }
        share.publicPermission = .readWrite

        _ = try await modify(
            recordsToSave: [rootRecord, share],
            recordIDsToDelete: [],
            database: privateDatabase
        )
        try await updateUserCoupleRoot(
            session: session,
            coupleRootRecordName: coupleReference(for: rootRecord.recordID, databaseScope: .private)
        )
        try await savePublicInviteCode(
            code: inviteCode,
            ownerAppleUserId: session.appleUserId,
            shareURL: share.url
        )

        return (decodeCoupleRoot(from: rootRecord, databaseScope: .private, shareURL: nil), share)
    }

    func joinCouple(inviteCode rawCode: String, session: AppleSession, currentCoupleId: String?) async throws -> Couple {
        try await ensureAccountAvailable()

        let code = Self.normalizedInviteCode(rawCode)
        guard code.count == 6 else {
            throw LongdyError.invalidInviteCode
        }

        let inviteRecord = try await fetchRequiredInviteCode(code: code)
        guard stringValue(inviteRecord[InviteCodeField.usedByAppleUserId]) == nil,
              inviteRecord[InviteCodeField.usedAt] == nil else {
            throw LongdyError.coupleFull
        }
        guard let ownerAppleUserId = stringValue(inviteRecord[InviteCodeField.ownerAppleUserId]),
              ownerAppleUserId != session.appleUserId else {
            throw LongdyError.invalidInput("내가 만든 초대 코드는 직접 입력할 수 없어요.")
        }
        guard let expiresAt = inviteRecord[InviteCodeField.expiresAt] as? Date,
              expiresAt > Date(),
              let shareURLText = stringValue(inviteRecord[InviteCodeField.shareURL]),
              let shareURL = URL(string: shareURLText) else {
            throw LongdyError.invalidInviteCode
        }

        let replacingCoupleId: String?
        if let currentCoupleId {
            if try await canReplaceWithIncomingShare(currentCoupleId: currentCoupleId, session: session) {
                replacingCoupleId = currentCoupleId
            } else {
                throw LongdyError.invalidInput("이미 연결된 커플 공간이 있어요.")
            }
        } else {
            replacingCoupleId = nil
        }

        let metadata = try await fetchShareMetadata(from: shareURL)
        let couple = try await acceptShare(metadata: metadata, session: session, replacingCurrentCoupleId: replacingCoupleId)
        inviteRecord[InviteCodeField.usedAt] = Date() as CKRecordValue
        inviteRecord[InviteCodeField.usedByAppleUserId] = session.appleUserId as CKRecordValue
        _ = try await save(inviteRecord, database: publicDatabase)
        return couple
    }

    func disconnectCouple(coupleId: String, session: AppleSession) async throws -> CoupleDisconnectResult {
        try await ensureAccountAvailable()
        let ref = coupleReference(from: coupleId)

        let fetchedRoot: CKRecord?
        do {
            fetchedRoot = try await fetchRecord(recordID: ref.recordID, database: ref.database)
        } catch let error as CKError where isRevokedCoupleAccessError(error) {
            _ = try await resetUserProfileAfterCoupleDeletion(session: session)
            return CoupleDisconnectResult(retainedCouple: nil)
        }
        guard let rootRecord = fetchedRoot else {
            _ = try await resetUserProfileAfterCoupleDeletion(session: session)
            return CoupleDisconnectResult(retainedCouple: nil)
        }

        let ownerId = stringValue(rootRecord[CoupleRootField.ownerAppleUserId])
        let partnerId = stringValue(rootRecord[CoupleRootField.partnerAppleUserId])

        if ownerId == session.appleUserId {
            try await invalidateInviteCode(in: rootRecord)
            clearMemberSnapshot(in: rootRecord, prefix: .partner)
            rootRecord[CoupleRootField.partnerAppleUserId] = nil
            rootRecord[CoupleRootField.inviteCode] = nil
            rootRecord[CoupleRootField.updatedAt] = Date() as CKRecordValue

            if let shareRecordID = rootRecord.share?.recordID,
               let share = try await fetchRecord(recordID: shareRecordID, database: privateDatabase) as? CKShare {
                share.publicPermission = .none
                _ = try await modify(
                    recordsToSave: [rootRecord, share],
                    recordIDsToDelete: [],
                    database: privateDatabase
                )
            } else {
                _ = try await save(rootRecord, database: privateDatabase)
            }

            let retained = decodeCoupleRoot(from: rootRecord, databaseScope: .private, shareURL: nil)
            return CoupleDisconnectResult(retainedCouple: retained)
        }

        guard partnerId == session.appleUserId else {
            throw LongdyError.invalidInput("현재 계정은 이 커플 공간의 구성원이 아니에요.")
        }

        clearMemberSnapshot(in: rootRecord, prefix: .partner)
        rootRecord[CoupleRootField.partnerAppleUserId] = nil
        rootRecord[CoupleRootField.inviteCode] = nil
        rootRecord[CoupleRootField.updatedAt] = Date() as CKRecordValue
        _ = try await save(rootRecord, database: sharedDatabase)

        if let shareRecordID = rootRecord.share?.recordID {
            try await deleteIfExists(recordID: shareRecordID, database: sharedDatabase)
        }

        _ = try await resetUserProfileAfterCoupleDeletion(session: session)
        return CoupleDisconnectResult(retainedCouple: nil)
    }

    func deleteCoupleSpace(coupleId: String, session: AppleSession) async throws -> LongdyUser {
        try await ensureAccountAvailable()
        let ref = coupleReference(from: coupleId)
        guard ref.database.databaseScope == .private,
              let rootRecord = try await fetchRecord(recordID: ref.recordID, database: ref.database) else {
            return try await resetUserProfileAfterCoupleDeletion(session: session)
        }
        guard stringValue(rootRecord[CoupleRootField.ownerAppleUserId]) == session.appleUserId else {
            throw LongdyError.invalidInput("커플 공간을 만든 사람만 공간을 삭제할 수 있어요.")
        }

        try await invalidateInviteCode(in: rootRecord)

        let recordTypes = [
            RecordType.checkIn,
            RecordType.coupleEvent,
            RecordType.careItem,
            RecordType.memoryNote,
            RecordType.bridgeActivity
        ]
        var childRecordIDs: [CKRecord.ID] = []
        for recordType in recordTypes {
            let records = try await optionalQueryRecords(
                type: recordType,
                coupleId: coupleId,
                database: privateDatabase
            )
            childRecordIDs.append(contentsOf: records.map(\.recordID))
        }
        try await deleteRecords(childRecordIDs, database: privateDatabase)

        if let shareRecordID = rootRecord.share?.recordID {
            try await deleteIfExists(recordID: shareRecordID, database: privateDatabase)
        }
        try await deleteIfExists(recordID: rootRecord.recordID, database: privateDatabase)
        return try await resetUserProfileAfterCoupleDeletion(session: session)
    }

    func canReplaceWithIncomingShare(currentCoupleId: String, session: AppleSession) async throws -> Bool {
        let ref = coupleReference(from: currentCoupleId)
        guard let currentRoot = try await fetchRecord(recordID: ref.recordID, database: ref.database) else {
            return true
        }
        let ownerId = stringValue(currentRoot[CoupleRootField.ownerAppleUserId])
        let partnerId = stringValue(currentRoot[CoupleRootField.partnerAppleUserId])
        return ownerId == session.appleUserId && partnerId == nil
    }

    func updateCoupleMemberSnapshotIfNeeded(user: LongdyUser) async throws {
        guard let coupleId = user.partnerCoupleId else { return }
        let ref = coupleReference(from: coupleId)
        guard let rootRecord = try await fetchRecord(recordID: ref.recordID, database: ref.database) else { return }
        let ownerId = stringValue(rootRecord[CoupleRootField.ownerAppleUserId])
        let partnerId = stringValue(rootRecord[CoupleRootField.partnerAppleUserId])

        if ownerId == user.id {
            fillMemberSnapshot(in: rootRecord, prefix: .owner, user: user)
        } else if partnerId == user.id {
            fillMemberSnapshot(in: rootRecord, prefix: .partner, user: user)
        } else {
            return
        }

        rootRecord[CoupleRootField.updatedAt] = Date() as CKRecordValue
        _ = try await save(rootRecord, database: ref.database)
    }

    func fillMemberSnapshot(in record: CKRecord, prefix: MemberSnapshotPrefix, user: LongdyUser) {
        let fields = memberSnapshotFields(for: prefix)
        record[fields.displayName] = user.displayName as CKRecordValue
        record[fields.nickname] = user.nickname as CKRecordValue
        record[fields.cityName] = user.cityName as CKRecordValue
        record[fields.timezoneId] = user.timezoneId as CKRecordValue
        record[fields.latitude] = user.latitude as CKRecordValue?
        record[fields.longitude] = user.longitude as CKRecordValue?
        record[fields.locationUpdatedAt] = user.locationUpdatedAt as CKRecordValue?
        if record[fields.profilePhotoAsset] == nil,
           let urlText = user.profilePhotoURL,
           let url = URL(string: urlText),
           url.isFileURL {
            record[fields.profilePhotoAsset] = CKAsset(fileURL: url)
        }
    }

    func clearMemberSnapshot(in record: CKRecord, prefix: MemberSnapshotPrefix) {
        let fields = memberSnapshotFields(for: prefix)
        record[fields.displayName] = nil
        record[fields.nickname] = nil
        record[fields.cityName] = nil
        record[fields.timezoneId] = nil
        record[fields.latitude] = nil
        record[fields.longitude] = nil
        record[fields.locationUpdatedAt] = nil
        record[fields.profilePhotoAsset] = nil
    }

    func invalidateInviteCode(in rootRecord: CKRecord) async throws {
        guard let code = stringValue(rootRecord[CoupleRootField.inviteCode]) else { return }
        try await deleteIfExists(
            recordID: CKRecord.ID(recordName: inviteCodeRecordName(code)),
            database: publicDatabase
        )
    }

    func isRevokedCoupleAccessError(_ error: CKError) -> Bool {
        switch error.code {
        case .unknownItem, .permissionFailure, .zoneNotFound, .userDeletedZone:
            return true
        default:
            return false
        }
    }

    func memberSnapshotFields(for prefix: MemberSnapshotPrefix) -> (displayName: String, nickname: String, cityName: String, timezoneId: String, latitude: String, longitude: String, locationUpdatedAt: String, profilePhotoAsset: String) {
        switch prefix {
        case .owner:
            return (
                CoupleRootField.ownerDisplayName,
                CoupleRootField.ownerNickname,
                CoupleRootField.ownerCityName,
                CoupleRootField.ownerTimezoneId,
                CoupleRootField.ownerLatitude,
                CoupleRootField.ownerLongitude,
                CoupleRootField.ownerLocationUpdatedAt,
                CoupleRootField.ownerProfilePhotoAsset
            )
        case .partner:
            return (
                CoupleRootField.partnerDisplayName,
                CoupleRootField.partnerNickname,
                CoupleRootField.partnerCityName,
                CoupleRootField.partnerTimezoneId,
                CoupleRootField.partnerLatitude,
                CoupleRootField.partnerLongitude,
                CoupleRootField.partnerLocationUpdatedAt,
                CoupleRootField.partnerProfilePhotoAsset
            )
        }
    }
}
