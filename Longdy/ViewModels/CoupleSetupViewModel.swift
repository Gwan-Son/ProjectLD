import Combine
import Foundation

@MainActor
final class CoupleSetupViewModel: ObservableObject {
    @Published var inviteCode = ""
    @Published var errorMessage: String?
    @Published var isCreatingShare = false
    @Published var isJoining = false

    private let cloudKitService = CloudKitService.shared

    func createCouple(session: AppleSession?) async -> Couple? {
        guard !isCreatingShare else { return nil }
        isCreatingShare = true
        defer { isCreatingShare = false }

        do {
            errorMessage = nil
            guard let session else { throw LongdyError.missingUser }
            let result = try await cloudKitService.createCoupleRootShare(session: session)
            return result.couple
        } catch {
            errorMessage = error.longdyUserMessage
            return nil
        }
    }

    func regenerateCouple(session: AppleSession?, currentCoupleId: String?) async -> Couple? {
        guard !isCreatingShare else { return nil }
        isCreatingShare = true
        defer { isCreatingShare = false }

        do {
            errorMessage = nil
            guard let session else { throw LongdyError.missingUser }
            let result = try await cloudKitService.regenerateCoupleRootShare(session: session, currentCoupleId: currentCoupleId)
            return result.couple
        } catch {
            errorMessage = error.longdyUserMessage
            return nil
        }
    }

    func joinCouple(session: AppleSession?, currentCoupleId: String?) async -> Couple? {
        guard !isJoining else { return nil }
        isJoining = true
        defer { isJoining = false }

        do {
            errorMessage = nil
            guard let session else { throw LongdyError.missingUser }
            return try await cloudKitService.joinCouple(
                inviteCode: inviteCode,
                session: session,
                currentCoupleId: currentCoupleId
            )
        } catch {
            errorMessage = error.longdyUserMessage
            return nil
        }
    }

}
