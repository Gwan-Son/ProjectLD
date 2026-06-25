import CloudKit
import Foundation

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

        if recordsById.isEmpty {
            let query = CKQuery(recordType: type, predicate: NSPredicate(value: true))
            let records = try await fetchRecords(matching: query, database: database, zoneID: ref.recordID.zoneID)
            records
                .filter { record in
                    let rootName = stringValue(record[SharedField.coupleRootRecordName])
                    let parentName = record.parent?.recordID.recordName
                    return lookupKeys.contains(rootName ?? "") || parentName == ref.recordID.recordName
                }
                .forEach { recordsById[$0.recordID.recordName] = $0 }
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

    private func fetchRecords(matching query: CKQuery, database: CKDatabase, zoneID: CKRecordZone.ID) async throws -> [CKRecord] {
        let result = try await database.records(
            matching: query,
            inZoneWith: zoneID,
            desiredKeys: nil,
            resultsLimit: CKQueryOperation.maximumResults
        )
        return try result.matchResults.map { _, recordResult in
            try recordResult.get()
        }
    }
}
