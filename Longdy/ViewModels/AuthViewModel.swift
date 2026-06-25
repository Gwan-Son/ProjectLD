import Combine
import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isSigningInWithApple = false
    @Published var errorMessage: String?

    private let appleAuthService = AppleAuthService.shared
    private let appleSessionStore = AppleSessionStore.shared
    private let cloudKitService = CloudKitService.shared

    func signInWithApple() async -> Bool {
        guard !isSigningInWithApple else { return false }
        isSigningInWithApple = true
        defer { isSigningInWithApple = false }

        do {
            errorMessage = nil
            let appleResult = try await appleAuthService.signIn()
            let displayName = Self.displayName(from: appleResult.fullName) ?? "Guest"
            appleSessionStore.save(appleUserId: appleResult.appleUserId, email: appleResult.email, displayName: displayName)
            if let session = appleSessionStore.currentSession {
                _ = try await cloudKitService.upsertUserProfile(session: session, nickname: displayName)
            }
            return true
        } catch {
            errorMessage = error.longdyUserMessage
            return false
        }
    }

    private static func displayName(from fullName: PersonNameComponents?) -> String? {
        guard let fullName else { return nil }
        let name = PersonNameComponentsFormatter()
            .string(from: fullName)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != "Longdy" else { return nil }
        return name
    }
}
