import Foundation

struct AppleSession: Equatable {
    var appleUserId: String
    var email: String?
    var displayName: String?
    var updatedAt: Date
}

final class AppleSessionStore {
    static let shared = AppleSessionStore()

    private enum Key {
        static let appleUserId = "longdy.appleSession.appleUserId"
        static let email = "longdy.appleSession.email"
        static let displayName = "longdy.appleSession.displayName"
        static let updatedAt = "longdy.appleSession.updatedAt"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var currentSession: AppleSession? {
        guard let appleUserId = defaults.string(forKey: Key.appleUserId), !appleUserId.isEmpty else {
            return nil
        }
        return AppleSession(
            appleUserId: appleUserId,
            email: defaults.string(forKey: Key.email),
            displayName: defaults.string(forKey: Key.displayName),
            updatedAt: defaults.object(forKey: Key.updatedAt) as? Date ?? .distantPast
        )
    }

    func save(appleUserId: String, email: String?, displayName: String?) {
        defaults.set(appleUserId, forKey: Key.appleUserId)
        defaults.set(email, forKey: Key.email)
        defaults.set(displayName, forKey: Key.displayName)
        defaults.set(Date(), forKey: Key.updatedAt)
    }

    func clear() {
        defaults.removeObject(forKey: Key.appleUserId)
        defaults.removeObject(forKey: Key.email)
        defaults.removeObject(forKey: Key.displayName)
        defaults.removeObject(forKey: Key.updatedAt)
    }
}
