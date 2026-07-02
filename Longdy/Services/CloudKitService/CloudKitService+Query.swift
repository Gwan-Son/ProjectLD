import CloudKit
import Foundation

struct MemoryPage {
    let memories: [MemoryNote]
    let cursor: CKQueryOperation.Cursor?
}

extension CloudKitService {
    func queryRecords(type: String, coupleId: String, database: CKDatabase) async throws -> [CKRecord] {
        let ref = coupleReference(from: coupleId)
        let lookupKeys = [ref.recordID.recordName, coupleId]
            .reduce(into: [String]()) { keys, value in
                if !keys.contains(value) { keys.append(value) }
            }
        var recordsById: [String: CKRecord] = [:]

        for lookupKey in lookupKeys {
            let predicate = NSPredicate(format: "%K == %@", SharedField.coupleRootRecordName, lookupKey)
            let query = CKQuery(recordType: type, predicate: predicate)
            let records = try await fetchRecords(matching: query, database: database, zoneID: ref.recordID.zoneID)
            records.forEach { recordsById[$0.recordID.recordName] = $0 }
        }

        return Array(recordsById.values)
    }

    func optionalQueryRecords(type: String, coupleId: String, database: CKDatabase) async throws -> [CKRecord] {
        do {
            return try await queryRecords(type: type, coupleId: coupleId, database: database)
        } catch {
            if isMissingRecordTypeError(error) {
                return []
            }
            throw error
        }
    }

    func fetchMemoryPage(
        coupleId: String,
        cursor: CKQueryOperation.Cursor? = nil,
        limit: Int = 20
    ) async throws -> MemoryPage {
        let ref = coupleReference(from: coupleId)
        let desiredKeys = [
            SharedField.appleUserId,
            SharedField.createdAt,
            MemoryField.text,
            MemoryField.dateKey,
            MemoryField.thumbnailAsset
        ]

        do {
            let result: (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?)
            if let cursor {
                result = try await ref.database.records(
                    continuingMatchFrom: cursor,
                    desiredKeys: desiredKeys,
                    resultsLimit: limit
                )
            } else {
                let predicate = NSPredicate(
                    format: "%K == %@",
                    SharedField.coupleRootRecordName,
                    ref.recordID.recordName
                )
                let query = CKQuery(recordType: RecordType.memoryNote, predicate: predicate)
                query.sortDescriptors = [NSSortDescriptor(key: SharedField.createdAt, ascending: false)]
                result = try await ref.database.records(
                    matching: query,
                    inZoneWith: ref.recordID.zoneID,
                    desiredKeys: desiredKeys,
                    resultsLimit: limit
                )
            }

            let memories = try result.matchResults
                .map { try $0.1.get() }
                .compactMap(Self.decodeMemory)
            return MemoryPage(memories: memories, cursor: result.queryCursor)
        } catch {
            if isMissingRecordTypeError(error) {
                return MemoryPage(memories: [], cursor: nil)
            }
            throw error
        }
    }

    private func fetchRecords(matching query: CKQuery, database: CKDatabase, zoneID: CKRecordZone.ID) async throws -> [CKRecord] {
        var result = try await database.records(
            matching: query,
            inZoneWith: zoneID,
            desiredKeys: nil,
            resultsLimit: CKQueryOperation.maximumResults
        )
        var records = try result.matchResults.map { _, recordResult in
            try recordResult.get()
        }

        while let cursor = result.queryCursor {
            result = try await database.records(
                continuingMatchFrom: cursor,
                desiredKeys: nil,
                resultsLimit: CKQueryOperation.maximumResults
            )
            records.append(contentsOf: try result.matchResults.map { _, recordResult in
                try recordResult.get()
            })
        }
        return records
    }
}
