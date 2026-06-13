import SwiftUI

struct FirebaseSetupView: View {
    var body: some View {
        ZStack {
            LongdyColors.background.ignoresSafeArea()
            LongdyCard {
                VStack(alignment: .leading, spacing: 14) {
                    Image(systemName: "flame")
                        .font(.title)
                        .foregroundStyle(LongdyColors.peach)
                    Text("Firebase 설정이 필요해요")
                        .font(.title2.bold())
                        .foregroundStyle(LongdyColors.ink)
                    Text("Firebase 콘솔에서 iOS 앱 `kr.gwanson.Longdy`를 만들고 `GoogleService-Info.plist`를 Longdy 타깃에 추가하면 동기화 MVP가 실행돼요.")
                        .font(.callout)
                        .foregroundStyle(LongdyColors.muted)
                }
            }
            .padding()
        }
    }
}

struct AuthView: View {
    @StateObject private var viewModel = AuthViewModel()

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    VStack(spacing: 12) {
                        Text("Our Bridge")
                            .font(.system(size: 24, weight: .medium, design: .serif))
                            .foregroundStyle(LoginPalette.primary)
                        Rectangle()
                            .fill(LoginPalette.primary.opacity(0.2))
                            .frame(width: 48, height: 1)
                    }
                    .padding(.bottom, 24)

                    VStack(spacing: 16) {
                        Text("거리의 장벽을 넘어,\n다시 우리로")
                            .font(.system(size: 30, weight: .semibold, design: .serif))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(LoginPalette.ink)
                        Text("서로의 따스함을 느끼는\n우리만의 소중한 공간")
                            .font(.system(size: 17))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(LoginPalette.muted)
                    }
                    .padding(.bottom, 48)

                    loginPanel

                    loginImage
                        .padding(.top, 64)
                }
                .frame(maxWidth: 440)
                .padding(.horizontal, 20)
                .padding(.vertical, 48)
                .frame(maxWidth: .infinity)
            }
            .background(LoginPalette.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: LoginRoute.self) { route in
                switch route {
                case .signUp:
                    SignUpView()
                }
            }
        }
    }

    private var loginPanel: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Button(action: {}) {
                    Label("카카오로 시작하기", systemImage: "bubble.left.fill")
                        .foregroundStyle(Color(red: 0.10, green: 0.10, blue: 0.10))
                        .loginButtonBackground(Color(red: 1.00, green: 0.90, blue: 0.00))
                }
                .buttonStyle(.plain)

                Button(action: {}) {
                    Label("Apple로 계속하기", systemImage: "apple.logo")
                        .foregroundStyle(.white)
                        .loginButtonBackground(.black)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 16) {
                Rectangle().fill(LoginPalette.line.opacity(0.45)).frame(height: 1)
                Text("OR")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(LoginPalette.outline)
                Rectangle().fill(LoginPalette.line.opacity(0.45)).frame(height: 1)
            }

            VStack(spacing: 24) {
                LoginField(title: "이메일 주소") {
                    TextField("hello@ourbridge.app", text: $viewModel.email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                }

                LoginField(title: "비밀번호") {
                    SecureField("비밀번호를 입력하세요", text: $viewModel.password)
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(LoginPalette.error)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    viewModel.isSignUp = false
                    Task { await viewModel.submit() }
                } label: {
                    Text("로그인")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [LoginPalette.primary, LoginPalette.primaryContainer],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: LoginPalette.primary.opacity(0.2), radius: 12, y: 6)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 14) {
                HStack(spacing: 5) {
                    Text("아직 회원이 아니신가요?")
                        .foregroundStyle(LoginPalette.muted)
                    NavigationLink(value: LoginRoute.signUp) {
                        Text("가입하기")
                            .fontWeight(.semibold)
                            .foregroundStyle(LoginPalette.primary)
                    }
                }
                .font(.subheadline)

                Button("비밀번호를 잊으셨나요?") {}
                    .font(.caption.weight(.medium))
                    .foregroundStyle(LoginPalette.outline)
            }
        }
        .padding(24)
        .background(.white.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(.white.opacity(0.65), lineWidth: 1)
        }
        .shadow(color: LoginPalette.ink.opacity(0.04), radius: 16, y: 4)
    }

    private var loginImage: some View {
        ZStack(alignment: .bottom) {
            AsyncImage(url: URL(string: "https://lh3.googleusercontent.com/aida-public/AB6AXuAUO5_w407eOpAYLvfG8ZTCOvr737nMOAUSckK7cnNu_55uwvXQ4ii1yTGzEX_ufLluguTt6sfn_MzhvHWbdB5_tLicYFcKGLuysPnOOYLXsTk571mMY_5zUlevCAXS-IHLljt43JaeVzbOdqsX94Ktp84X-gkgl4W3N23DtbBF9mtPBM_RNErtxu1dZAK9Ux0srbY6ZKqnVWVTMjkHOLt2WaSmH09HcAXuUATulm7bmJXcyxq_xdn4CDMBhJ9_KeFFENWM7YjpGSY")) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    LoginPalette.surfaceContainer
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(16 / 9, contentMode: .fit)
            .clipped()

            LinearGradient(colors: [.clear, LoginPalette.background.opacity(0.92)], startPoint: .top, endPoint: .bottom)

            Text("“멀리 있어도, 마음은 언제나 곁에”")
                .font(.system(size: 19, weight: .regular, design: .serif).italic())
                .foregroundStyle(LoginPalette.primary)
                .padding(.bottom, 18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.45), lineWidth: 1)
        }
        .shadow(color: LoginPalette.ink.opacity(0.05), radius: 16, y: 6)
    }
}

private enum LoginRoute: Hashable {
    case signUp
}

private struct LoginField<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(LoginPalette.muted)
                .padding(.leading, 16)
            content
                .padding(.horizontal, 20)
                .frame(height: 56)
                .background(LoginPalette.surfaceContainerLow)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

private enum LoginPalette {
    static let background = Color(red: 1.00, green: 0.97, blue: 0.97)
    static let surfaceContainer = Color(red: 1.00, green: 0.91, blue: 0.95)
    static let surfaceContainerLow = Color(red: 1.00, green: 0.94, blue: 0.96)
    static let primary = Color(red: 0.58, green: 0.28, blue: 0.26)
    static let primaryContainer = Color(red: 0.96, green: 0.59, blue: 0.56)
    static let ink = Color(red: 0.16, green: 0.09, blue: 0.13)
    static let muted = Color(red: 0.33, green: 0.26, blue: 0.25)
    static let outline = Color(red: 0.53, green: 0.45, blue: 0.44)
    static let line = Color(red: 0.85, green: 0.76, blue: 0.75)
    static let error = Color(red: 0.73, green: 0.10, blue: 0.10)
}

private extension View {
    func loginButtonBackground(_ color: Color) -> some View {
        self
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(color)
            .clipShape(Capsule())
    }
}

struct CoupleSetupView: View {
    @EnvironmentObject private var appState: AppViewModel
    @StateObject private var viewModel = CoupleSetupViewModel()
    @State private var showingCopyAlert = false

    var body: some View {
        ZStack {
            CoupleSetupPalette.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    topBar
                    bridgeIllustration
                    heading
                    inviteSection
                    divider
                    joinSection

                    Button("연결에 도움이 필요하신가요?") {}
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CoupleSetupPalette.muted)
                        .underline(color: CoupleSetupPalette.line)
                        .padding(.top, 64)

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(CoupleSetupPalette.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 20)
                    }
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, 20)
                .padding(.bottom, 64)
                .frame(maxWidth: .infinity)
            }
        }
        .alert("복사 완료", isPresented: $showingCopyAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("초대 코드가 클립보드에 복사됐어요.")
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                appState.signOut()
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(CoupleSetupPalette.primary)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("로그아웃하고 돌아가기")

            Spacer()

            Text("커플 연결")
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundStyle(CoupleSetupPalette.primary)

            Spacer()

            BridgeAvatar(user: appState.currentProfile, fallback: "나")
        }
        .padding(.top, 8)
        .padding(.bottom, 24)
    }

    private var bridgeIllustration: some View {
        ZStack {
            Circle()
                .fill(CoupleSetupPalette.primaryContainer.opacity(0.16))
                .frame(width: 260, height: 260)

            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [CoupleSetupPalette.primary, CoupleSetupPalette.secondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 148, height: 148)
                .rotationEffect(.degrees(45))
                .shadow(color: CoupleSetupPalette.primary.opacity(0.2), radius: 20, y: 10)
                .overlay {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 58))
                        .foregroundStyle(.white)
                }

            Image(systemName: "link")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(CoupleSetupPalette.onSecondaryContainer)
                .frame(width: 86, height: 86)
                .background(CoupleSetupPalette.secondaryContainer)
                .clipShape(Circle())
                .shadow(color: CoupleSetupPalette.primary.opacity(0.15), radius: 14, y: 7)
                .offset(x: 86, y: 82)
        }
        .frame(height: 280)
        .allowsHitTesting(false)
    }

    private var heading: some View {
        VStack(spacing: 8) {
            Text("연인과 연결하기")
                .font(.system(size: 30, weight: .semibold, design: .serif))
                .foregroundStyle(CoupleSetupPalette.ink)
            Text("소중한 사람과 함께 Our Bridge를 시작해 보세요.")
                .font(.subheadline)
                .foregroundStyle(CoupleSetupPalette.muted)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 24)
        .padding(.bottom, 64)
    }

    private var inviteSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("상대방 초대하기", systemImage: "paperplane.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(CoupleSetupPalette.primary)

            VStack(spacing: 8) {
                Text("나의 초대 코드")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(CoupleSetupPalette.muted)

                if let inviteCode = appState.couple?.inviteCode, !inviteCode.isEmpty {
                    Text(inviteCode)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundStyle(CoupleSetupPalette.ink)
                        .tracking(3)
                        .textSelection(.enabled)
                } else {
                    Text("아직 코드가 없어요")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(CoupleSetupPalette.outline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(.white.opacity(0.62))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(CoupleSetupPalette.line.opacity(0.35), lineWidth: 1)
            }

            if let inviteCode = appState.couple?.inviteCode, !inviteCode.isEmpty {
                HStack(spacing: 12) {
                    Button {
                        UIPasteboard.general.string = inviteCode
                        showingCopyAlert = true
                    } label: {
                        Label("복사", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(CouplePrimaryButtonStyle())

                    ShareLink(item: "Our Bridge 초대 코드: \(inviteCode)") {
                        Label("공유하기", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(CoupleSecondaryButtonStyle())
                }
            } else {
                Button {
                    Task { await viewModel.createCouple(userId: appState.userId) }
                } label: {
                    Label("초대 코드 만들기", systemImage: "plus")
                }
                .buttonStyle(CouplePrimaryButtonStyle())
            }
        }
        .padding(24)
        .background(CoupleSetupPalette.surfaceLow)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: CoupleSetupPalette.primary.opacity(0.08), radius: 16, y: 8)
    }

    private var divider: some View {
        HStack(spacing: 24) {
            Rectangle().fill(CoupleSetupPalette.line.opacity(0.5)).frame(height: 1)
            Text("또는")
                .font(.caption.weight(.medium))
                .foregroundStyle(CoupleSetupPalette.muted)
            Rectangle().fill(CoupleSetupPalette.line.opacity(0.5)).frame(height: 1)
        }
        .padding(.vertical, 48)
    }

    private var joinSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("초대코드 입력하기", systemImage: "link.badge.plus")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(CoupleSetupPalette.secondary)

            TextField("상대방의 코드를 입력하세요", text: $viewModel.inviteCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(.horizontal, 16)
                .frame(height: 56)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Button {
                Task { await viewModel.joinCouple(userId: appState.userId) }
            } label: {
                Text("연결하기")
                    .font(.system(size: 20, weight: .medium, design: .serif))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .background(
                        LinearGradient(
                            colors: [CoupleSetupPalette.primary, CoupleSetupPalette.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: CoupleSetupPalette.primary.opacity(0.2), radius: 12, y: 6)
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(CoupleSetupPalette.surfaceLow)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: CoupleSetupPalette.primary.opacity(0.08), radius: 16, y: 8)
    }
}

private struct CouplePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(CoupleSetupPalette.primary.opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(Capsule())
    }
}

private struct CoupleSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(CoupleSetupPalette.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(CoupleSetupPalette.surfaceHigh.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(Capsule())
    }
}

private enum CoupleSetupPalette {
    static let background = Color(red: 1.00, green: 0.97, blue: 0.97)
    static let surfaceLow = Color(red: 1.00, green: 0.94, blue: 0.96)
    static let surfaceHigh = Color(red: 0.98, green: 0.85, blue: 0.91)
    static let primary = Color(red: 0.58, green: 0.28, blue: 0.26)
    static let primaryContainer = Color(red: 0.96, green: 0.59, blue: 0.56)
    static let secondary = Color(red: 0.49, green: 0.33, blue: 0.25)
    static let secondaryContainer = Color(red: 0.99, green: 0.78, blue: 0.68)
    static let onSecondaryContainer = Color(red: 0.47, green: 0.31, blue: 0.24)
    static let ink = Color(red: 0.16, green: 0.09, blue: 0.13)
    static let muted = Color(red: 0.33, green: 0.26, blue: 0.25)
    static let outline = Color(red: 0.53, green: 0.45, blue: 0.44)
    static let line = Color(red: 0.85, green: 0.76, blue: 0.75)
    static let error = Color(red: 0.73, green: 0.10, blue: 0.10)
}

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("홈", systemImage: "house") }
            CalendarView()
                .tabItem { Label("캘린더", systemImage: "calendar") }
            CareView()
                .tabItem { Label("챙김", systemImage: "checklist") }
            MemoriesView()
                .tabItem { Label("메모", systemImage: "photo.on.rectangle") }
        }
        .tint(LongdyColors.peach)
    }
}
