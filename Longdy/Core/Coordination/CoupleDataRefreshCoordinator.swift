import Foundation

@MainActor
final class CoupleDataRefreshCoordinator {
    static let shared = CoupleDataRefreshCoordinator()

    var handler: (() -> Void)?

    func requestRefresh() {
        handler?()
    }
}
