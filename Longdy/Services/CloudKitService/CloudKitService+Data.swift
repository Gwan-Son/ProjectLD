import CloudKit
import Foundation

extension CloudKitService {
    func fetchBridgeActivities(coupleId: String, userIds: [String], dateKey: String) async throws -> [BridgeActivity] {
        let ref = coupleReference(from: coupleId)
        var activities: [BridgeActivity] = []

        for userId in userIds {
            let recordID = CKRecord.ID(
                recordName: bridgeActivityRecordName(userId: userId, dateKey: dateKey),
                zoneID: ref.recordID.zoneID
            )
            if let record = try await fetchRecord(recordID: recordID, database: ref.database),
               let activity = Self.decodeBridgeActivity(record) {
                activities.append(activity)
            }
        }
        return activities
    }

    func saveCalendarViewedActivity(coupleId: String, userId: String, dateKey: String) async throws -> BridgeActivity {
        let ref = coupleReference(from: coupleId)
        let recordID = CKRecord.ID(
            recordName: bridgeActivityRecordName(userId: userId, dateKey: dateKey),
            zoneID: ref.recordID.zoneID
        )
        if let existing = try await fetchRecord(recordID: recordID, database: ref.database),
           let activity = Self.decodeBridgeActivity(existing) {
            return activity
        }

        let now = Date()
        let record = CKRecord(recordType: RecordType.bridgeActivity, recordID: recordID)
        attachToCoupleRoot(record, ref: ref)
        record[SharedField.appleUserId] = userId as CKRecordValue
        record["kind"] = BridgeActivityKind.calendarViewed.rawValue as CKRecordValue
        record["dateKey"] = dateKey as CKRecordValue
        record[SharedField.createdAt] = now as CKRecordValue

        do {
            let saved = try await save(record, database: ref.database)
            return Self.decodeBridgeActivity(saved) ?? BridgeActivity(
                id: recordID.recordName,
                userId: userId,
                kind: .calendarViewed,
                dateKey: dateKey,
                createdAt: now
            )
        } catch let error as CKError where error.code == .serverRecordChanged {
            guard let existing = try await fetchRecord(recordID: recordID, database: ref.database),
                  let activity = Self.decodeBridgeActivity(existing) else { throw error }
            return activity
        }
    }

    private func bridgeActivityRecordName(userId: String, dateKey: String) -> String {
        let safeUserId = userId
            .unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) ? String($0) : "-" }
            .joined()
        return "bridge-calendar-\(dateKey)-\(safeUserId)"
    }

    func fetchCoupleData(coupleId: String) async throws -> (checkIns: [CheckIn], events: [CoupleEvent], careItems: [CareItem], memories: [MemoryNote]) {
        let ref = coupleReference(from: coupleId)
        async let checkInRecords = queryRecords(type: RecordType.checkIn, coupleId: coupleId, database: ref.database)
        async let eventRecords = optionalQueryRecords(type: RecordType.coupleEvent, coupleId: coupleId, database: ref.database)
        async let careItemRecords = optionalQueryRecords(type: RecordType.careItem, coupleId: coupleId, database: ref.database)
        async let memoryPage = fetchMemoryPage(coupleId: coupleId)

        let checkIns = try await checkInRecords
            .compactMap(Self.decodeCheckIn)
            .sorted { $0.createdAt > $1.createdAt }
        let events = try await eventRecords
            .compactMap(Self.decodeEvent)
            .sorted { $0.startAt < $1.startAt }
        let careItems = try await careItemRecords
            .compactMap(Self.decodeCareItem)
            .sorted { $0.createdAt < $1.createdAt }
        let memories = try await memoryPage.memories
        return (checkIns, events, careItems, memories)
    }

    func fetchHomeData(coupleId: String) async throws -> (checkIns: [CheckIn], events: [CoupleEvent], careItems: [CareItem]) {
        let ref = coupleReference(from: coupleId)
        async let checkInRecords = queryRecords(type: RecordType.checkIn, coupleId: coupleId, database: ref.database)
        async let eventRecords = optionalQueryRecords(type: RecordType.coupleEvent, coupleId: coupleId, database: ref.database)
        async let careItemRecords = optionalQueryRecords(type: RecordType.careItem, coupleId: coupleId, database: ref.database)

        let now = Date()
        let thirtyDaysLater = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now
        let checkIns = try await checkInRecords
            .compactMap(Self.decodeCheckIn)
            .filter { !$0.isExpired }
            .sorted { $0.createdAt > $1.createdAt }
        let events = try await eventRecords
            .compactMap(Self.decodeEvent)
            .filter { $0.endAt >= Calendar.current.startOfDay(for: now) && $0.startAt <= thirtyDaysLater }
            .sorted { $0.startAt < $1.startAt }
        let careItems = try await careItemRecords
            .compactMap(Self.decodeCareItem)
            .filter { item in
                item.dateKey == DateKey.dateKey() || item.repeatRule.applies(to: now, createdAt: item.createdAt)
            }
            .sorted { $0.createdAt < $1.createdAt }
        return (checkIns, events, careItems)
    }

    func saveCheckIn(coupleId: String, userId: String, mood: Mood, status: LongdyStatus, expiresAt: Date?) async throws -> CheckIn {
        let ref = coupleReference(from: coupleId)
        let record = CKRecord(recordType: RecordType.checkIn, recordID: CKRecord.ID(recordName: "checkIn-\(UUID().uuidString)", zoneID: ref.recordID.zoneID))
        attachToCoupleRoot(record, ref: ref)
        record[SharedField.appleUserId] = userId as CKRecordValue
        record["mood"] = mood.rawValue as CKRecordValue
        record["status"] = status.rawValue as CKRecordValue
        record[SharedField.createdAt] = Date() as CKRecordValue
        if let expiresAt {
            record["expiresAt"] = expiresAt as CKRecordValue
        }
        let savedRecord = try await save(record, database: ref.database)
        return Self.decodeCheckIn(savedRecord) ?? CheckIn(
            id: savedRecord.recordID.recordName,
            userId: userId,
            mood: mood,
            status: status,
            createdAt: savedRecord[SharedField.createdAt] as? Date ?? Date(),
            expiresAt: expiresAt
        )
    }

    func repairUserCoupleReference(session: AppleSession, coupleId: String) async throws {
        try await updateUserCoupleRoot(session: session, coupleRootRecordName: coupleId)
    }

    func saveEvent(coupleId: String, ownerUserId: String, title: String, startAt: Date, endAt: Date, type: EventType, memo: String) async throws -> CoupleEvent {
        let ref = coupleReference(from: coupleId)
        let record = CKRecord(recordType: RecordType.coupleEvent, recordID: CKRecord.ID(recordName: "event-\(UUID().uuidString)", zoneID: ref.recordID.zoneID))
        attachToCoupleRoot(record, ref: ref)
        fillEvent(record, coupleRootRecordName: ref.recordID.recordName, ownerUserId: ownerUserId, title: title, startAt: startAt, endAt: endAt, type: type, memo: memo)
        let savedRecord = try await save(record, database: ref.database)
        if type == .meet {
            try await updateCoupleDate(coupleId: coupleId, key: CoupleRootField.nextMeetDate, date: startAt)
        }
        return Self.decodeEvent(savedRecord) ?? CoupleEvent(
            id: savedRecord.recordID.recordName,
            ownerUserId: ownerUserId,
            title: title,
            startAt: startAt,
            endAt: endAt,
            type: type,
            memo: memo
        )
    }

    func updateEvent(coupleId: String, eventId: String, title: String, startAt: Date, endAt: Date, type: EventType, memo: String) async throws -> CoupleEvent {
        let ref = coupleReference(from: coupleId)
        let recordID = CKRecord.ID(recordName: eventId, zoneID: ref.recordID.zoneID)
        let record = try await fetchRequiredRecord(recordID: recordID, database: ref.database)
        attachToCoupleRoot(record, ref: ref)
        let ownerUserId = record["ownerUserId"] as? String ?? ""
        fillEvent(record, coupleRootRecordName: ref.recordID.recordName, ownerUserId: ownerUserId, title: title, startAt: startAt, endAt: endAt, type: type, memo: memo)
        let savedRecord = try await save(record, database: ref.database)
        if type == .meet {
            try await updateCoupleDate(coupleId: coupleId, key: CoupleRootField.nextMeetDate, date: startAt)
        }
        return Self.decodeEvent(savedRecord) ?? CoupleEvent(
            id: savedRecord.recordID.recordName,
            ownerUserId: ownerUserId,
            title: title,
            startAt: startAt,
            endAt: endAt,
            type: type,
            memo: memo
        )
    }

    func deleteEvent(coupleId: String, eventId: String) async throws {
        let ref = coupleReference(from: coupleId)
        try await delete(recordID: CKRecord.ID(recordName: eventId, zoneID: ref.recordID.zoneID), database: ref.database)
    }

    func saveCareItem(coupleId: String, itemId: String, dateKey: String, userId: String, title: String, iconName: String, repeatRule: CareRepeatRule, reminderHour: Int?, reminderMinute: Int?, note: String) async throws -> String {
        let ref = coupleReference(from: coupleId)
        let recordID = CKRecord.ID(recordName: itemId, zoneID: ref.recordID.zoneID)
        if try await fetchRecord(recordID: recordID, database: ref.database) != nil {
            return itemId
        }
        let record = CKRecord(recordType: RecordType.careItem, recordID: recordID)
        attachToCoupleRoot(record, ref: ref)
        record[SharedField.appleUserId] = userId as CKRecordValue
        record["dateKey"] = dateKey as CKRecordValue
        record["title"] = title as CKRecordValue
        record["iconName"] = iconName as CKRecordValue
        record["repeatRule"] = repeatRule.rawValue as CKRecordValue
        record["note"] = note as CKRecordValue
        record[SharedField.createdAt] = Date() as CKRecordValue
        if let reminderHour, let reminderMinute {
            record["reminderHour"] = reminderHour as CKRecordValue
            record["reminderMinute"] = reminderMinute as CKRecordValue
        }
        _ = try await save(record, database: ref.database)
        return recordID.recordName
    }

    func updateCareItem(coupleId: String, itemId: String, dateKey: String, isDone: Bool) async throws {
        let ref = coupleReference(from: coupleId)
        let record = try await fetchRequiredRecord(recordID: CKRecord.ID(recordName: itemId, zoneID: ref.recordID.zoneID), database: ref.database)
        attachToCoupleRoot(record, ref: ref)
        var doneDateKeys = record["doneDateKeys"] as? [String] ?? []
        if isDone {
            if !doneDateKeys.contains(dateKey) { doneDateKeys.append(dateKey) }
        } else {
            doneDateKeys.removeAll { $0 == dateKey }
        }
        if doneDateKeys.isEmpty {
            record["doneDateKeys"] = nil
        } else {
            record["doneDateKeys"] = doneDateKeys as NSArray
        }
        record[SharedField.updatedAt] = Date() as CKRecordValue
        _ = try await save(record, database: ref.database)
    }

    func updateCareItemDetails(coupleId: String, itemId: String, title: String, iconName: String, repeatRule: CareRepeatRule, reminderHour: Int?, reminderMinute: Int?, note: String) async throws {
        let ref = coupleReference(from: coupleId)
        let record = try await fetchRequiredRecord(recordID: CKRecord.ID(recordName: itemId, zoneID: ref.recordID.zoneID), database: ref.database)
        attachToCoupleRoot(record, ref: ref)
        record["title"] = title as CKRecordValue
        record["iconName"] = iconName as CKRecordValue
        record["repeatRule"] = repeatRule.rawValue as CKRecordValue
        record["note"] = note as CKRecordValue
        record["reminderHour"] = reminderHour as CKRecordValue?
        record["reminderMinute"] = reminderMinute as CKRecordValue?
        record[SharedField.updatedAt] = Date() as CKRecordValue
        _ = try await save(record, database: ref.database)
    }

    func deleteCareItem(coupleId: String, itemId: String) async throws {
        let ref = coupleReference(from: coupleId)
        try await deleteIfExists(
            recordID: CKRecord.ID(recordName: itemId, zoneID: ref.recordID.zoneID),
            database: ref.database
        )
    }

    func saveMemory(
        coupleId: String,
        memoryId: String,
        userId: String,
        text: String,
        fileData: Data?,
        thumbnailData: Data?,
        fileExtension: String?
    ) async throws -> MemoryNote {
        let ref = coupleReference(from: coupleId)
        let recordID = CKRecord.ID(recordName: memoryId, zoneID: ref.recordID.zoneID)
        if let existing = try await fetchRecord(recordID: recordID, database: ref.database),
           let memory = Self.decodeMemory(existing) {
            return memory
        }
        let record = CKRecord(recordType: RecordType.memoryNote, recordID: recordID)
        let now = Date()
        attachToCoupleRoot(record, ref: ref)
        record[SharedField.appleUserId] = userId as CKRecordValue
        record[MemoryField.type] = "photo" as CKRecordValue
        record[MemoryField.text] = text as CKRecordValue
        record[MemoryField.dateKey] = DateKey.dateKey(for: now) as CKRecordValue
        record[SharedField.createdAt] = now as CKRecordValue

        var temporaryURLs: [URL] = []
        if let fileData, let fileExtension {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(fileExtension)
            try fileData.write(to: url, options: .atomic)
            temporaryURLs.append(url)
            record[MemoryField.asset] = CKAsset(fileURL: url)
        }
        if let thumbnailData {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("thumbnail-\(UUID().uuidString)")
                .appendingPathExtension("jpg")
            try thumbnailData.write(to: url, options: .atomic)
            temporaryURLs.append(url)
            record[MemoryField.thumbnailAsset] = CKAsset(fileURL: url)
        }
        defer {
            temporaryURLs.forEach { try? FileManager.default.removeItem(at: $0) }
        }
        let savedRecord = try await save(record, database: ref.database)
        return Self.decodeMemory(savedRecord) ?? MemoryNote(
            id: savedRecord.recordID.recordName,
            userId: userId,
            text: text,
            storageURL: nil,
            dateKey: DateKey.dateKey(for: now),
            createdAt: now
        )
    }

    func updateMemory(
        coupleId: String,
        memoryId: String,
        text: String,
        fileData: Data?,
        thumbnailData: Data?,
        fileExtension: String?
    ) async throws -> MemoryNote {
        let ref = coupleReference(from: coupleId)
        let record = try await fetchRequiredRecord(recordID: CKRecord.ID(recordName: memoryId, zoneID: ref.recordID.zoneID), database: ref.database)
        attachToCoupleRoot(record, ref: ref)
        record[MemoryField.text] = text as CKRecordValue
        record[SharedField.updatedAt] = Date() as CKRecordValue

        var temporaryURLs: [URL] = []
        if let fileData, let fileExtension {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(fileExtension)
            try fileData.write(to: url, options: .atomic)
            temporaryURLs.append(url)
            record[MemoryField.asset] = CKAsset(fileURL: url)
        }
        if let thumbnailData {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("thumbnail-\(UUID().uuidString)")
                .appendingPathExtension("jpg")
            try thumbnailData.write(to: url, options: .atomic)
            temporaryURLs.append(url)
            record[MemoryField.thumbnailAsset] = CKAsset(fileURL: url)
        }
        defer {
            temporaryURLs.forEach { try? FileManager.default.removeItem(at: $0) }
        }

        let savedRecord = try await save(record, database: ref.database)
        return Self.decodeMemory(savedRecord) ?? MemoryNote(
            id: savedRecord.recordID.recordName,
            userId: record[SharedField.appleUserId] as? String ?? "",
            text: text,
            storageURL: nil,
            dateKey: record[MemoryField.dateKey] as? String ?? DateKey.dateKey(),
            createdAt: record[SharedField.createdAt] as? Date ?? Date()
        )
    }

    func fetchMemoryDetail(coupleId: String, memoryId: String) async throws -> MemoryNote {
        let ref = coupleReference(from: coupleId)
        let recordID = CKRecord.ID(recordName: memoryId, zoneID: ref.recordID.zoneID)
        let record = try await fetchRequiredRecord(recordID: recordID, database: ref.database)
        guard let memory = Self.decodeMemory(record) else {
            throw LongdyError.invalidInput("사진 정보를 불러오지 못했어요.")
        }
        return memory
    }

    func deleteMemory(coupleId: String, memoryId: String) async throws {
        let ref = coupleReference(from: coupleId)
        try await deleteIfExists(
            recordID: CKRecord.ID(recordName: memoryId, zoneID: ref.recordID.zoneID),
            database: ref.database
        )
    }

}
