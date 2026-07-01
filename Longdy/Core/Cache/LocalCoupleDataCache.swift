import Foundation

struct CachedCoupleSnapshot: Codable {
    var userId: String
    var coupleId: String
    var couple: Couple?
    var members: [LongdyUser]
    var checkIns: [CheckIn]
    var events: [CoupleEvent]
    var careItems: [CareItem]
    var memories: [MemoryNote]
    var bridgeActivities: [BridgeActivity]?
}

enum LocalCoupleDataCache {
    private static func key(for userId: String) -> String {
        "longdy.cachedCoupleData.\(userId)"
    }

    static func load(userId: String) -> CachedCoupleSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: key(for: userId)) else { return nil }
        return try? JSONDecoder().decode(CachedCoupleSnapshot.self, from: data)
    }

    static func save(_ snapshot: CachedCoupleSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: key(for: snapshot.userId))
    }

    static func clear(userId: String) {
        UserDefaults.standard.removeObject(forKey: key(for: userId))
    }
}
