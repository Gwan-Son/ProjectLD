import SwiftUI
import UIKit

struct AuthView: View {
    @EnvironmentObject private var appState: AppViewModel
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
        }
    }

    private var loginPanel: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Button {
                    Task {
                        if await viewModel.signInWithApple() {
                            appState.start()
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isSigningInWithApple {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "apple.logo")
                        }
                        Text("Apple로 계속하기")
                    }
                    .foregroundStyle(.white)
                    .loginButtonBackground(.black)
                }
                .disabled(viewModel.isSigningInWithApple)
                .buttonStyle(.plain)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(LoginPalette.error)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            VStack(spacing: 8) {
                Text("Apple ID로 안전하게 로그인해요.")
                    .font(.subheadline)
                    .foregroundStyle(LoginPalette.muted)
                Text("이름과 이메일은 최초 로그인 때만 공유될 수 있어요.")
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
    @State private var showingRegenerateConfirmation = false
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
        .alert("공유 초대를 재생성할까요?", isPresented: $showingRegenerateConfirmation) {
            Button("취소", role: .cancel) {}
            Button("재생성", role: .destructive) {
                Task {
                    if let couple = await viewModel.regenerateCouple(
                        session: appState.appleSession,
                        currentCoupleId: appState.currentProfile?.partnerCoupleId ?? appState.couple?.id
                    ) {
                        appState.couple = couple
                        appState.currentProfile?.partnerCoupleId = couple.id
                        appState.start()
                    }
                }
            }
        } message: {
            Text("기존 초대 코드는 더 이상 사용할 수 없고 새 코드가 만들어져요.")
        }
        .task(id: appState.currentProfile?.partnerCoupleId) {
            await pollPendingCoupleConnection()
        }
    }

    private func pollPendingCoupleConnection() async {
        guard appState.currentProfile?.partnerCoupleId != nil else { return }
        while !Task.isCancelled {
            if (appState.couple?.memberIds.count ?? 0) >= 2 { return }
            await appState.refreshCoupleStatus()
            try? await Task.sleep(for: .seconds(3))
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

            Image("couple-link")
                .resizable()
                .scaledToFit()
                .frame(width: 246, height: 246)
                .shadow(color: CoupleSetupPalette.primary.opacity(0.14), radius: 18, y: 10)
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

                if let code = appState.couple?.inviteCode, !code.isEmpty {
                    Text(code)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundStyle(CoupleSetupPalette.ink)
                        .tracking(4)
                        .textSelection(.enabled)
                } else {
                    Text("아직 초대가 없어요")
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

            if appState.couple != nil {
                VStack(spacing: 12) {
                    if let code = appState.couple?.inviteCode, !code.isEmpty {
                        HStack(spacing: 12) {
                            Button {
                                UIPasteboard.general.string = code
                                showingCopyAlert = true
                            } label: {
                                Label("복사", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(CouplePrimaryButtonStyle())

                            ShareLink(item: "Our Bridge 초대 코드: \(code)") {
                                Label("공유하기", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(CoupleSecondaryButtonStyle())
                        }
                    } else {
                        Text("기존 초대 코드를 찾을 수 없어요. 새 초대 코드를 만들 수 있어요.")
                            .font(.footnote)
                            .foregroundStyle(CoupleSetupPalette.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        showingRegenerateConfirmation = true
                    } label: {
                        Label(viewModel.isCreatingShare ? "재생성 중" : "초대 코드 재생성", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(CoupleSecondaryButtonStyle())
                    .disabled(viewModel.isCreatingShare)
                }
            } else {
                Button {
                    Task {
                        if let couple = await viewModel.createCouple(session: appState.appleSession) {
                            appState.couple = couple
                            appState.currentProfile?.partnerCoupleId = couple.id
                            appState.start()
                        }
                    }
                } label: {
                    Label(viewModel.isCreatingShare ? "초대 생성 중" : "초대 코드 만들기", systemImage: "plus")
                }
                .buttonStyle(CouplePrimaryButtonStyle())
                .disabled(viewModel.isCreatingShare)
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
            Label("초대 코드 입력하기", systemImage: "link.badge.plus")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(CoupleSetupPalette.secondary)

            TextField("6자리 코드를 입력하세요", text: $viewModel.inviteCode)
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundStyle(CoupleSetupPalette.ink)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(.horizontal, 18)
                .frame(height: 56)
                .background(.white.opacity(0.62))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .onChange(of: viewModel.inviteCode) { _, newValue in
                    viewModel.inviteCode = String(
                        newValue
                            .uppercased()
                            .filter { $0.isLetter || $0.isNumber }
                            .prefix(6)
                    )
                }

            Button {
                Task {
                    if let couple = await viewModel.joinCouple(
                        session: appState.appleSession,
                        currentCoupleId: appState.currentProfile?.partnerCoupleId
                    ) {
                        appState.couple = couple
                        appState.currentProfile?.partnerCoupleId = couple.id
                        appState.start()
                    }
                }
            } label: {
                Label(viewModel.isJoining ? "연결 중" : "연결하기", systemImage: "heart.fill")
            }
            .buttonStyle(CouplePrimaryButtonStyle())
            .disabled(viewModel.isJoining || viewModel.inviteCode.count < 6)
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

struct MainTabView: View {
    @EnvironmentObject private var appState: AppViewModel

    var body: some View {
        TabView(selection: $appState.selectedMainTab) {
            HomeView()
                .tabItem { Label("홈", systemImage: "house") }
                .tag(MainTab.home)
            CalendarView()
                .tabItem { Label("캘린더", systemImage: "calendar") }
                .tag(MainTab.calendar)
            CareView()
                .tabItem { Label("챙김", systemImage: "checklist") }
                .tag(MainTab.care)
            MemoriesView()
                .tabItem { Label("한 장", systemImage: "photo.on.rectangle") }
                .tag(MainTab.todayPhoto)
        }
        .tint(LongdyColors.primary)
    }
}
