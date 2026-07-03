import AuthenticationServices
import CryptoKit
import Foundation

struct AppleSignInResult {
    let appleUserId: String
    let identityToken: String
    let rawNonce: String
    let fullName: PersonNameComponents?
    let email: String?
}

@MainActor
final class AppleAuthService: NSObject {
    static let shared = AppleAuthService()

    private var continuation: CheckedContinuation<AppleSignInResult, Error>?
    private var currentNonce: String?
    private var currentController: ASAuthorizationController?
    private var presentationWindow: ASPresentationAnchor?

    private override init() {}

    func signIn() async throws -> AppleSignInResult {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation?.resume(throwing: LongdyError.invalidInput("Apple 로그인을 다시 시도해 주세요."))
            clearState()
            self.continuation = continuation

            guard let presentationWindow = Self.activePresentationAnchor() else {
                continuation.resume(throwing: LongdyError.invalidInput("Apple 로그인 화면을 표시할 수 없어요. 잠시 후 다시 시도해 주세요."))
                clearState()
                return
            }
            self.presentationWindow = presentationWindow

            let nonce: String
            do {
                nonce = try Self.randomNonceString()
            } catch {
                continuation.resume(throwing: error)
                clearState()
                return
            }
            currentNonce = nonce

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = Self.sha256(nonce)

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            self.currentController = controller
            controller.performRequests()
        }
    }

    private static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }

    private static func randomNonceString(length: Int = 32) throws -> String {
        guard length > 0 else {
            throw LongdyError.invalidInput("Apple 로그인 보안 정보를 생성하지 못했어요.")
        }
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            guard status == errSecSuccess else {
                throw LongdyError.invalidInput("Apple 로그인 보안 정보를 생성하지 못했어요. 다시 시도해 주세요.")
            }

            if random < charset.count {
                result.append(charset[Int(random)])
                remainingLength -= 1
            }
        }

        return result
    }

    private static func activePresentationAnchor() -> ASPresentationAnchor? {
        let windowScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .sorted { lhs, rhs in
                lhs.activationState == .foregroundActive && rhs.activationState != .foregroundActive
            }

        return windowScenes
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
            ?? windowScenes.flatMap(\.windows).first(where: { !$0.isHidden })
    }
}

extension AppleAuthService: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let identityToken = String(data: tokenData, encoding: .utf8),
            let rawNonce = currentNonce
        else {
            continuation?.resume(throwing: LongdyError.invalidInput("Apple 로그인 정보를 확인할 수 없어요."))
            clearState()
            return
        }

        continuation?.resume(
            returning: AppleSignInResult(
                appleUserId: credential.user,
                identityToken: identityToken,
                rawNonce: rawNonce,
                fullName: credential.fullName,
                email: credential.email
            )
        )
        clearState()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: Self.userFacingError(from: error))
        clearState()
    }

    private func clearState() {
        continuation = nil
        currentNonce = nil
        currentController = nil
        presentationWindow = nil
    }

    private static func userFacingError(from error: Error) -> Error {
        let nsError = error as NSError
        guard nsError.domain == ASAuthorizationError.errorDomain,
              let code = ASAuthorizationError.Code(rawValue: nsError.code) else {
            return error
        }

        let message = switch code {
        case .canceled:
            "Apple 로그인이 취소됐어요."
        case .failed:
            "Apple 로그인 요청이 실패했어요. Apple ID 상태와 네트워크를 확인해 주세요."
        case .invalidResponse:
            "Apple 로그인 응답을 확인할 수 없어요."
        case .notHandled:
            "Apple 로그인 요청을 처리하지 못했어요. 앱의 Sign in with Apple 설정을 확인해 주세요."
        case .unknown:
            "Apple 로그인을 완료할 수 없어요. Apple Developer의 Sign in with Apple capability와 기기 Apple ID 로그인을 확인해 주세요. (\(nsError.domain) \(nsError.code))"
        case .notInteractive:
            "현재 상태에서는 Apple 로그인 화면을 표시할 수 없어요."
        case .matchedExcludedCredential:
            "이 Apple ID로는 현재 로그인 요청을 사용할 수 없어요."
        case .credentialImport:
            "Apple 로그인 정보를 가져오지 못했어요."
        case .credentialExport:
            "Apple 로그인 정보를 내보내지 못했어요."
        case .preferSignInWithApple:
            "기존 Apple 로그인 계정을 사용해 주세요."
        case .deviceNotConfiguredForPasskeyCreation:
            "이 기기는 패스키 생성을 사용할 수 없어요. Apple ID 설정을 확인해 주세요."
        @unknown default:
            "Apple 로그인을 완료할 수 없어요. (\(nsError.domain) \(nsError.code))"
        }
        return LongdyError.invalidInput(message)
    }
}

extension AppleAuthService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        presentationWindow
            ?? Self.activePresentationAnchor()
            ?? ASPresentationAnchor(frame: .zero)
    }
}
