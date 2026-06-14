import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AuthViewModel()
    @State private var step = 1

    var body: some View {
        ZStack {
            SignUpPalette.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    signUpHeader
                    signUpCard
                    footerLinks
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, 20)
                .padding(.top, 32)
                .padding(.bottom, 48)
                .frame(maxWidth: .infinity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            viewModel.isSignUp = true
        }
    }

    private var signUpHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: "heart.fill")
                .font(.system(size: 40))
                .foregroundStyle(SignUpPalette.primary)
            Text("Our Bridge")
                .font(.system(size: 30, weight: .semibold, design: .serif))
                .foregroundStyle(SignUpPalette.primary)
            Text("거리에 상관없이, 우리만의 소중한 공간이 피어나도록.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(SignUpPalette.muted)
                .padding(.horizontal, 24)
        }
        .padding(.bottom, 64)
    }

    private var signUpCard: some View {
        VStack(spacing: 32) {
            progressBar

            Group {
                switch step {
                case 1: accountStep
                case 2: profileStep
                default: completionStep
                }
            }
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
        }
        .padding(24)
        .background(.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(SignUpPalette.surfaceHigh.opacity(0.55), lineWidth: 1)
        }
        .shadow(color: SignUpPalette.ink.opacity(0.04), radius: 20, y: 8)
    }

    private var progressBar: some View {
        HStack(spacing: 8) {
            ForEach(1...3, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? SignUpPalette.primary : SignUpPalette.surfaceHigh)
                    .frame(height: 6)
                    .animation(.easeInOut(duration: 0.35), value: step)
            }
        }
    }

    private var accountStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("우리의 여정 시작하기")
                .font(.system(size: 24, weight: .medium, design: .serif))
                .foregroundStyle(SignUpPalette.ink)

            SignUpField(title: "이메일 주소", icon: "envelope") {
                TextField("heart@sharedbridge.com", text: $viewModel.email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
            }

            SignUpField(title: "비밀번호 설정", icon: "lock") {
                SecureField("비밀번호를 입력하세요", text: $viewModel.password)
            }

            Button {
                guard !viewModel.email.isEmpty, !viewModel.password.isEmpty else {
                    viewModel.errorMessage = "이메일과 비밀번호를 입력해 주세요."
                    return
                }
                viewModel.errorMessage = nil
                withAnimation { step = 2 }
            } label: {
                Label("다음 단계로", systemImage: "arrow.right")
            }
            .buttonStyle(SignUpPrimaryButtonStyle())
        }
    }

    private var profileStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("서로를 잇는 준비")
                .font(.system(size: 24, weight: .medium, design: .serif))
                .foregroundStyle(SignUpPalette.ink)
            Text("상대에게 보일 이름과 생활 지역을 알려주세요.")
                .font(.subheadline)
                .foregroundStyle(SignUpPalette.muted)

            SignUpField(title: "이름", icon: "person") {
                TextField("이름", text: $viewModel.displayName)
            }

            SignUpField(title: "닉네임", icon: "heart") {
                TextField("상대에게 보일 이름", text: $viewModel.nickname)
            }

            SignUpField(title: "도시", icon: "mappin.and.ellipse") {
                TextField("Seoul", text: $viewModel.cityName)
            }

            HStack(spacing: 12) {
                Button("이전으로") {
                    withAnimation { step = 1 }
                }
                .buttonStyle(SignUpSecondaryButtonStyle())

                Button("계속하기") {
                    guard !viewModel.displayName.isEmpty else {
                        viewModel.errorMessage = "이름을 입력해 주세요."
                        return
                    }
                    viewModel.errorMessage = nil
                    withAnimation { step = 3 }
                }
                .buttonStyle(SignUpPrimaryButtonStyle())
            }
        }
    }

    private var completionStep: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(SignUpPalette.primary.opacity(0.13))
                    .frame(width: 118, height: 118)
                Circle()
                    .fill(SignUpPalette.primaryContainer)
                    .frame(width: 96, height: 96)
                Image(systemName: "heart.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(SignUpPalette.onPrimaryContainer)
            }

            VStack(spacing: 10) {
                Text("다리가 준비되었습니다")
                    .font(.system(size: 24, weight: .medium, design: .serif))
                    .foregroundStyle(SignUpPalette.ink)
                Text("두 분만의 비밀스러운 공간을 설정할 준비가 되었어요. 가입 후 초대 코드로 상대와 연결할 수 있어요.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(SignUpPalette.muted)
            }

            VStack(spacing: 12) {
                SignUpStatusRow(icon: "checkmark.shield", title: "안전한 계정 보호")
                SignUpStatusRow(icon: "heart.text.square", title: "둘만의 기록 공간")
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(SignUpPalette.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                viewModel.isSignUp = true
                Task { await viewModel.submit() }
            } label: {
                Text("우리의 안식처 입장하기")
            }
            .buttonStyle(SignUpPrimaryButtonStyle())
        }
    }

    private var footerLinks: some View {
        VStack(spacing: 22) {
            HStack(spacing: 5) {
                Text("이미 계정이 있으신가요?")
                    .foregroundStyle(SignUpPalette.muted)
                Button("로그인하기") { dismiss() }
                    .fontWeight(.bold)
                    .foregroundStyle(SignUpPalette.primary)
            }
            .font(.subheadline)

            HStack(spacing: 24) {
                Text("개인정보처리방침")
                Text("이용약관")
                Text("안전 가이드")
            }
            .font(.caption2)
            .foregroundStyle(SignUpPalette.muted.opacity(0.65))
        }
        .padding(.top, 64)
    }
}

private struct SignUpField<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(SignUpPalette.secondary)
                .padding(.leading, 4)
            HStack(spacing: 12) {
                content
                Image(systemName: icon)
                    .foregroundStyle(SignUpPalette.outline)
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(SignUpPalette.surfaceLow)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct SignUpStatusRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(SignUpPalette.primary)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SignUpPalette.ink)
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(SignUpPalette.secondary)
        }
        .padding(16)
        .background(SignUpPalette.surfaceLow)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct SignUpPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(SignUpPalette.primary.opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(Capsule())
            .shadow(color: SignUpPalette.primary.opacity(0.2), radius: 10, y: 5)
    }
}

private struct SignUpSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(SignUpPalette.muted)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(SignUpPalette.surfaceContainer.opacity(configuration.isPressed ? 0.7 : 1))
            .clipShape(Capsule())
    }
}

private enum SignUpPalette {
    static let background = Color(red: 1.00, green: 0.97, blue: 0.97)
    static let surfaceLow = Color(red: 1.00, green: 0.94, blue: 0.96)
    static let surfaceContainer = Color(red: 1.00, green: 0.91, blue: 0.95)
    static let surfaceHigh = Color(red: 0.98, green: 0.85, blue: 0.91)
    static let primary = Color(red: 0.58, green: 0.28, blue: 0.26)
    static let primaryContainer = Color(red: 0.96, green: 0.59, blue: 0.56)
    static let onPrimaryContainer = Color(red: 0.44, green: 0.18, blue: 0.16)
    static let secondary = Color(red: 0.49, green: 0.33, blue: 0.25)
    static let ink = Color(red: 0.16, green: 0.09, blue: 0.13)
    static let muted = Color(red: 0.33, green: 0.26, blue: 0.25)
    static let outline = Color(red: 0.53, green: 0.45, blue: 0.44)
    static let error = Color(red: 0.73, green: 0.10, blue: 0.10)
}
