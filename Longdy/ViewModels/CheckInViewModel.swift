import Combine
import Foundation

@MainActor
final class CheckInViewModel: ObservableObject {
    @Published var mood: Mood = .calm
    @Published var status: LongdyStatus = .resting
    @Published var duration: MoodShareDuration = .oneHour
    @Published var errorMessage: String?

    private let repository: any CheckInRepository

    init(repository: any CheckInRepository = DependencyContainer.live.checkInRepository) {
        self.repository = repository
    }

    func load(from checkIn: CheckIn?) {
        guard let checkIn else { return }
        mood = checkIn.mood
        status = checkIn.status
        duration = MoodShareDuration.closest(to: checkIn.expiresAt?.timeIntervalSinceNow)
        errorMessage = nil
    }

    func saveCheckIn(userId: String?, coupleId: String?) async -> CheckIn? {
        do {
            errorMessage = nil
            guard let userId else { throw LongdyError.missingUser }
            guard let coupleId else { throw LongdyError.missingCouple }
            let checkIn = try await repository.saveCheckIn(coupleId: coupleId, userId: userId, mood: mood, status: status, expiresAt: duration.expiresAt)
            CoupleDataRefreshCoordinator.shared.requestRefresh()
            return checkIn
        } catch {
            errorMessage = error.longdyUserMessage
            return nil
        }
    }

}

enum MoodShareDuration: Int, CaseIterable, Identifiable {
    case fiveMinutes = 300
    case fifteenMinutes = 900
    case thirtyMinutes = 1800
    case oneHour = 3600
    case threeHours = 10800
    case sixHours = 21600

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .fiveMinutes: "5분"
        case .fifteenMinutes: "15분"
        case .thirtyMinutes: "30분"
        case .oneHour: "1시간"
        case .threeHours: "3시간"
        case .sixHours: "6시간"
        }
    }

    var expiresAt: Date {
        Date().addingTimeInterval(TimeInterval(rawValue))
    }

    static func closest(to remainingTime: TimeInterval?) -> MoodShareDuration {
        guard let remainingTime, remainingTime > 0 else { return .oneHour }
        return allCases.min { first, second in
            abs(TimeInterval(first.rawValue) - remainingTime) < abs(TimeInterval(second.rawValue) - remainingTime)
        } ?? .oneHour
    }
}
