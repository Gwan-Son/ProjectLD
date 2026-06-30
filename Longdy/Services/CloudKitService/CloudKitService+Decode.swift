import CloudKit
import Foundation

extension CloudKitService {
    func decodeUserProfile(from record: CKRecord, session: AppleSession) -> LongdyUser {
        let displayName = profileName(
            preferred: stringValue(record[UserProfileField.displayName]),
            session: session
        )
        let nickname = profileName(
            preferred: stringValue(record[UserProfileField.nickname]),
            fallback: displayName,
            session: session
        )

        return LongdyUser(
            id: stringValue(record[UserProfileField.appleUserId]) ?? session.appleUserId,
            email: stringValue(record[UserProfileField.email]) ?? session.email ?? "",
            displayName: displayName,
            nickname: nickname,
            timezoneId: stringValue(record[UserProfileField.timezoneId]) ?? TimeZone.current.identifier,
            cityName: stringValue(record[UserProfileField.cityName]) ?? "Seoul",
            latitude: record[UserProfileField.latitude] as? Double,
            longitude: record[UserProfileField.longitude] as? Double,
            locationUpdatedAt: record[UserProfileField.locationUpdatedAt] as? Date,
            profilePhotoURL: Self.cachedProfilePhotoURL(
                from: record,
                field: UserProfileField.profilePhotoAsset
            )?.absoluteString,
            partnerCoupleId: stringValue(record[UserProfileField.coupleRootRecordName]),
            createdAt: record[UserProfileField.createdAt] as? Date ?? Date()
        )
    }

    func profileName(
        preferred: String?,
        existing: String? = nil,
        fallback: String? = nil,
        session: AppleSession
    ) -> String {
        cleanedProfileName(preferred)
            ?? cleanedProfileName(existing)
            ?? cleanedProfileName(fallback)
            ?? cleanedProfileName(session.displayName)
            ?? "Guest"
    }

    func cleanedProfileName(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "Longdy" else { return nil }
        return trimmed
    }

    func stringValue(_ value: CKRecordValue?) -> String? {
        let text = value as? String
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    func decodeCoupleRoot(from record: CKRecord, databaseScope: CKDatabase.Scope, shareURL: URL?) -> Couple {
        let ownerId = stringValue(record[CoupleRootField.ownerAppleUserId])
        let partnerId = stringValue(record[CoupleRootField.partnerAppleUserId])
        let coupleId = coupleReference(for: record.recordID, databaseScope: databaseScope)
        let memberProfiles = [
            decodeMemberSnapshot(from: record, prefix: .owner, userId: ownerId, coupleId: coupleId),
            decodeMemberSnapshot(from: record, prefix: .partner, userId: partnerId, coupleId: coupleId)
        ].compactMap { $0 }
        return Couple(
            id: coupleId,
            memberIds: [ownerId, partnerId].compactMap { $0 },
            memberProfiles: memberProfiles,
            inviteCode: shareURL?.absoluteString ?? stringValue(record[CoupleRootField.inviteCode]) ?? "",
            nextMeetDate: record[CoupleRootField.nextMeetDate] as? Date,
            anniversaryDate: record[CoupleRootField.anniversaryDate] as? Date,
            createdAt: record[CoupleRootField.createdAt] as? Date ?? Date()
        )
    }

    func decodeMemberSnapshot(from record: CKRecord, prefix: MemberSnapshotPrefix, userId: String?, coupleId: String) -> LongdyUser? {
        guard let userId else { return nil }
        let fields = memberSnapshotFields(for: prefix)
        let displayName = cleanedProfileName(stringValue(record[fields.displayName])) ?? "Guest"
        let nickname = cleanedProfileName(stringValue(record[fields.nickname])) ?? displayName
        return LongdyUser(
            id: userId,
            email: "",
            displayName: displayName,
            nickname: nickname,
            timezoneId: stringValue(record[fields.timezoneId]) ?? TimeZone.current.identifier,
            cityName: stringValue(record[fields.cityName]) ?? "Seoul",
            latitude: record[fields.latitude] as? Double,
            longitude: record[fields.longitude] as? Double,
            locationUpdatedAt: record[fields.locationUpdatedAt] as? Date,
            profilePhotoURL: Self.cachedProfilePhotoURL(
                from: record,
                field: fields.profilePhotoAsset
            )?.absoluteString,
            partnerCoupleId: coupleId,
            createdAt: record[CoupleRootField.createdAt] as? Date ?? Date()
        )
    }

    static func decodeCheckIn(_ record: CKRecord) -> CheckIn? {
        guard let userId = record[SharedField.appleUserId] as? String else { return nil }
        return CheckIn(
            id: record.recordID.recordName,
            userId: userId,
            mood: Mood(rawValue: record["mood"] as? String ?? "") ?? .calm,
            status: LongdyStatus(rawValue: record["status"] as? String ?? "") ?? .resting,
            createdAt: record[SharedField.createdAt] as? Date ?? Date(),
            expiresAt: record["expiresAt"] as? Date
        )
    }

    static func decodeEvent(_ record: CKRecord) -> CoupleEvent? {
        guard let ownerUserId = record["ownerUserId"] as? String,
              let title = record["title"] as? String,
              let startAt = record["startAt"] as? Date,
              let endAt = record["endAt"] as? Date else { return nil }
        return CoupleEvent(
            id: record.recordID.recordName,
            ownerUserId: ownerUserId,
            title: title,
            startAt: startAt,
            endAt: endAt,
            type: EventType(rawValue: record["type"] as? String ?? "") ?? .mine,
            memo: record["memo"] as? String ?? ""
        )
    }

    static func decodeCareItem(_ record: CKRecord) -> CareItem? {
        guard let userId = record[SharedField.appleUserId] as? String,
              let title = record["title"] as? String else { return nil }
        return CareItem(
            id: record.recordID.recordName,
            userId: userId,
            dateKey: record["dateKey"] as? String ?? dateKey(),
            title: title,
            iconName: record["iconName"] as? String ?? "drink-water",
            repeatRule: CareRepeatRule(rawValue: record["repeatRule"] as? String ?? "") ?? .once,
            reminderHour: record["reminderHour"] as? Int,
            reminderMinute: record["reminderMinute"] as? Int,
            note: record["note"] as? String ?? "",
            doneDateKeys: record["doneDateKeys"] as? [String] ?? [],
            createdAt: record[SharedField.createdAt] as? Date ?? Date()
        )
    }

    static func decodeMemory(_ record: CKRecord) -> MemoryNote? {
        guard let userId = record[SharedField.appleUserId] as? String else { return nil }
        return MemoryNote(
            id: record.recordID.recordName,
            userId: userId,
            text: record[MemoryField.text] as? String ?? "",
            storageURL: cachedMemoryAssetURL(from: record, field: MemoryField.asset, folder: "Originals")?.absoluteString,
            thumbnailURL: cachedMemoryAssetURL(from: record, field: MemoryField.thumbnailAsset, folder: "Thumbnails")?.absoluteString,
            dateKey: record[MemoryField.dateKey] as? String ?? Self.dateKey(for: record[SharedField.createdAt] as? Date ?? Date()),
            createdAt: record[SharedField.createdAt] as? Date ?? Date()
        )
    }

    static func decodeBridgeActivity(_ record: CKRecord) -> BridgeActivity? {
        guard let userId = record[SharedField.appleUserId] as? String,
              let kindValue = record["kind"] as? String,
              let kind = BridgeActivityKind(rawValue: kindValue),
              let dateKey = record["dateKey"] as? String else { return nil }
        return BridgeActivity(
            id: record.recordID.recordName,
            userId: userId,
            kind: kind,
            dateKey: dateKey,
            createdAt: record[SharedField.createdAt] as? Date ?? Date()
        )
    }

    private static func cachedProfilePhotoURL(from record: CKRecord, field: String) -> URL? {
        guard let sourceURL = (record[field] as? CKAsset)?.fileURL else { return nil }
        let fileManager = FileManager.default
        do {
            let directory = try fileManager.url(
                for: .cachesDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("ProfilePhotos", isDirectory: true)
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

            let prefix = "\(record.recordID.recordName)-\(field)-"
            let rawTag = record.recordChangeTag
                ?? record.modificationDate.map { String(Int($0.timeIntervalSince1970 * 1000)) }
                ?? UUID().uuidString
            let safeTag = rawTag
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
            let destinationURL = directory.appendingPathComponent("\(prefix)\(safeTag).jpg")

            let oldURLs = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ).filter {
                $0.lastPathComponent.hasPrefix(prefix) && $0 != destinationURL
            }
            oldURLs.forEach { try? fileManager.removeItem(at: $0) }

            if !fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
            }
            return destinationURL
        } catch {
            return sourceURL
        }
    }

    private static func cachedMemoryAssetURL(from record: CKRecord, field: String, folder: String) -> URL? {
        let fileManager = FileManager.default
        do {
            let directory = try fileManager.url(
                for: .cachesDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
                .appendingPathComponent("MemoryAssets", isDirectory: true)
                .appendingPathComponent(folder, isDirectory: true)
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let cacheKey = assetCacheKey(for: record, field: field)
            let destinationURL = directory.appendingPathComponent("\(cacheKey).jpg")

            if let sourceURL = (record[field] as? CKAsset)?.fileURL {
                removeOldCachedAssets(for: record.recordID.recordName, keeping: cacheKey, in: directory)
                if !fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.copyItem(at: sourceURL, to: destinationURL)
                }
            }

            guard fileManager.fileExists(atPath: destinationURL.path) else { return nil }
            return destinationURL
        } catch {
            return (record[field] as? CKAsset)?.fileURL
        }
    }

    private static func assetCacheKey(for record: CKRecord, field: String) -> String {
        let rawTag = record.recordChangeTag
            ?? record.modificationDate.map { String(Int($0.timeIntervalSince1970 * 1000)) }
            ?? UUID().uuidString
        let safeTag = rawTag
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return "\(record.recordID.recordName)-\(field)-\(safeTag)"
    }

    private static func removeOldCachedAssets(for recordName: String, keeping cacheKey: String, in directory: URL) {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return }

        urls
            .filter {
                $0.lastPathComponent.hasPrefix("\(recordName)-")
                    && $0.deletingPathExtension().lastPathComponent != cacheKey
            }
            .forEach { try? FileManager.default.removeItem(at: $0) }
    }
}
