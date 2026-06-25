import CloudKit
import Foundation

final class PendingCloudKitShareStore {
    static let shared = PendingCloudKitShareStore()

    private var metadata: CKShare.Metadata?
    private let lock = NSLock()

    private init() {}

    func save(_ metadata: CKShare.Metadata) {
        lock.lock()
        self.metadata = metadata
        lock.unlock()
    }

    func take() -> CKShare.Metadata? {
        lock.lock()
        defer { lock.unlock() }
        let current = metadata
        metadata = nil
        return current
    }

    func peek() -> CKShare.Metadata? {
        lock.lock()
        defer { lock.unlock() }
        return metadata
    }

    func discard() {
        lock.lock()
        metadata = nil
        lock.unlock()
    }
}
