import Foundation

enum HomeCardOrderStore {
    static func load(userId: String) -> [HomeCardKind] {
        let rawValues = UserDefaults.standard.stringArray(forKey: key(userId)) ?? []
        var seen: Set<HomeCardKind> = []
        var restored = rawValues
            .compactMap(HomeCardKind.init(rawValue:))
            .filter { seen.insert($0).inserted }
        restored.append(contentsOf: HomeCardKind.allCases.filter { seen.insert($0).inserted })
        return restored
    }

    static func save(_ order: [HomeCardKind], userId: String) {
        UserDefaults.standard.set(order.map(\.rawValue), forKey: key(userId))
    }

    static func clear(userId: String) {
        UserDefaults.standard.removeObject(forKey: key(userId))
    }

    private static func key(_ userId: String) -> String {
        "longdy.homeCardOrder.\(userId)"
    }
}
