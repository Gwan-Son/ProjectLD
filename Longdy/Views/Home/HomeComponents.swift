import PhotosUI
import SwiftUI
import UIKit

struct HomeMemoryArtwork: View {
    let url: URL

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                HomeMemoryPlaceholder()

                if url.isFileURL,
                   let data = try? Data(contentsOf: url),
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .id(url.absoluteString)
                } else {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                    } placeholder: {
                        HomeMemoryPlaceholder()
                    }
                    .id(url.absoluteString)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 260)
        .clipped()
    }
}

struct HomeMemoryPlaceholder: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [HomePalette.tertiary, HomePalette.secondary, HomePalette.primary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 58))
                .foregroundStyle(.white.opacity(0.45))
        }
    }
}

struct MoodEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CheckInViewModel
    let isSaving: Bool
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("기분 공유 수정")
                            .font(.system(size: 28, weight: .bold, design: .serif))
                            .foregroundStyle(HomePalette.primary)
                        Text("마음과 상태를 고르고, 얼마나 오래 보여둘지 정해요.")
                            .font(.callout)
                            .foregroundStyle(HomePalette.muted)
                    }

                    moodSection
                    statusSection

                    editorCard {
                        Picker("유지 시간", selection: $viewModel.duration) {
                            ForEach(MoodShareDuration.allCases) { duration in
                                Text(duration.title).tag(duration)
                            }
                        }
                        .font(.body)
                        .foregroundStyle(HomePalette.ink)
                        .tint(HomePalette.primary)
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                    }

                    Button(action: onSave) {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(isSaving ? "저장 중" : "기분 공유 저장")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(HomePalette.primary.opacity(isSaving ? 0.65 : 1))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(isSaving)
                }
                .padding(20)
            }
            .background(HomePalette.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                    .foregroundStyle(HomePalette.primary)
                }
            }
        }
    }

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("지금 마음은 어때요?", iconName: viewModel.mood.iconName)
            MoodIconPicker(selection: $viewModel.mood)
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("무엇을 하고 있나요?", iconName: viewModel.status.iconName)
            StatusIconPicker(selection: $viewModel.status)
        }
    }

    private func sectionHeader(_ title: String, iconName: String) -> some View {
        HStack(spacing: 10) {
            Image(iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 34, height: 34)
            Text(title)
                .font(.headline)
                .foregroundStyle(HomePalette.ink)
        }
    }

    private func editorCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HomePalette.surface.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.72), lineWidth: 1)
        }
    }

}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppViewModel
    @State private var showingCopyAlert = false
    @State private var showingDisconnectAlert = false
    @State private var showingDeleteCoupleSpaceAlert = false
    @State private var showingWeatherRefreshAlert = false
    @State private var weatherRefreshSucceeded = false
    @State private var draftName = ""
    @StateObject private var profilePhotoViewModel = ProfilePhotoViewModel()
    @State private var selectedProfilePhoto: PhotosPickerItem?
    @State private var showingProfilePhotoRemovalAlert = false
    @State private var showingDeleteAccountAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section("내 정보") {
                    profilePhotoControls
                    VStack(alignment: .leading, spacing: 8) {
                        Text("이름")
                            .font(.caption.bold())
                            .foregroundStyle(LongdyColors.muted)
                        HStack(spacing: 10) {
                            TextField("이름을 입력하세요", text: $draftName)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            Button(appState.isSavingProfile ? "저장 중" : "저장") {
                                appState.updateNickname(draftName)
                            }
                            .disabled(
                                appState.isSavingProfile
                                || draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || draftName == appState.currentProfile?.friendlyName
                            )
                        }
                    }
                    HStack {
                        Text("도시")
                        Spacer()
                        Text(appState.currentProfile?.cityName ?? "-")
                            .foregroundStyle(LongdyColors.muted)
                    }
                    Text("위치·날씨 새로고침을 하면 현재 위치 기준으로 도시가 바뀌어요.")
                        .font(.caption)
                        .foregroundStyle(LongdyColors.muted)
                    HStack {
                        Text("시간대")
                        Spacer()
                        Text(appState.currentProfile?.timezoneId ?? "-")
                            .foregroundStyle(LongdyColors.muted)
                    }
                }

                Section("홈 화면") {
                    NavigationLink {
                        HomeCardOrderView()
                            .environmentObject(appState)
                    } label: {
                        Label("카드 순서", systemImage: "rectangle.3.group")
                    }
                }

                Section("위치와 날씨") {
                    Button {
                        Task {
                            weatherRefreshSucceeded = await appState.refreshLocationAndWeatherNow()
                            showingWeatherRefreshAlert = true
                        }
                    } label: {
                        HStack {
                            if appState.isRefreshingLocationWeather {
                                ProgressView()
                            }
                            Label(
                                appState.isRefreshingLocationWeather ? "새로고침 중" : "위치·날씨 새로고침",
                                systemImage: "location.fill"
                            )
                        }
                    }
                    .disabled(appState.isRefreshingLocationWeather)

                    if let message = appState.weatherErrorMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else {
                        Text("정확한 주소는 저장하지 않고, 날씨와 도시 표시용 위치만 사용해요.")
                            .font(.caption)
                            .foregroundStyle(LongdyColors.muted)
                    }
                }

                Section("커플 연결") {
                    if let inviteCode = appState.couple?.inviteCode, !inviteCode.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("초대 코드")
                                .font(.caption.bold())
                                .foregroundStyle(LongdyColors.muted)
                            HStack(spacing: 12) {
                                Text(inviteCode)
                                    .font(.title2.monospaced().bold())
                                    .foregroundStyle(LongdyColors.ink)
                                    .textSelection(.enabled)
                                Spacer()
                                Button {
                                    UIPasteboard.general.string = inviteCode
                                    showingCopyAlert = true
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                }
                                .accessibilityLabel("초대 코드 복사")
                            }
                            Text(appState.partner == nil ? "상대에게 이 코드를 알려주면 둘만의 공간에 연결돼요." : "이미 연결된 커플 코드예요.")
                                .font(.caption)
                                .foregroundStyle(LongdyColors.muted)
                        }
                        .padding(.vertical, 4)
                    } else {
                        Text("초대 코드가 아직 없어요.")
                            .foregroundStyle(LongdyColors.muted)
                    }

                    if appState.currentProfile?.partnerCoupleId != nil {
                        Button(role: .destructive) {
                            showingDisconnectAlert = true
                        } label: {
                            Label(
                                disconnectButtonTitle,
                                systemImage: "heart.slash"
                            )
                        }
                        .disabled(appState.isDisconnectingCouple || appState.isDeletingCoupleSpace)

                        if appState.isCurrentUserCoupleOwner {
                            Button(role: .destructive) {
                                showingDeleteCoupleSpaceAlert = true
                            } label: {
                                Label(
                                    appState.isDeletingCoupleSpace ? "공간 삭제 중" : "커플 공간 삭제",
                                    systemImage: "trash"
                                )
                            }
                            .disabled(appState.isDisconnectingCouple || appState.isDeletingCoupleSpace)
                        }
                    }
                }

                Section("약관 및 개인정보") {
                    Link(destination: LegalDocumentLinks.privacyPolicy) {
                        legalDocumentLabel("개인정보처리방침", systemImage: "hand.raised")
                    }
                    Link(destination: LegalDocumentLinks.termsOfService) {
                        legalDocumentLabel("이용약관", systemImage: "doc.text")
                    }
                }

                Section("계정") {
                    Button {
                        dismiss()
                        appState.signOut()
                    } label: {
                        Label("로그아웃", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .disabled(accountOperationInProgress)

                    Button(role: .destructive) {
                        showingDeleteAccountAlert = true
                    } label: {
                        Label(
                            appState.isDeletingAccount ? "회원탈퇴 처리 중" : "회원탈퇴",
                            systemImage: "person.crop.circle.badge.minus"
                        )
                    }
                    .disabled(accountOperationInProgress)

                    if appState.isDeletingAccount {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("iCloud 데이터를 삭제하고 있어요. 앱을 종료하지 마세요.")
                                .font(.caption)
                                .foregroundStyle(LongdyColors.muted)
                        }
                    }

                    if let error = appState.accountDeletionErrorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .disabled(appState.isDeletingAccount)
            .navigationTitle("설정")
            .toolbar {
                Button("닫기") {
                    dismiss()
                }
                .disabled(accountOperationInProgress)
            }
            .alert("복사 완료", isPresented: $showingCopyAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("초대 코드가 클립보드에 복사됐어요.")
            }
            .alert(disconnectAlertTitle, isPresented: $showingDisconnectAlert) {
                Button("취소", role: .cancel) {}
                Button(appState.isCurrentUserCoupleOwner ? "연결 해제" : "나가기", role: .destructive) {
                    appState.disconnectCouple()
                }
            } message: {
                Text(disconnectAlertMessage)
            }
            .alert("커플 공간을 삭제할까요?", isPresented: $showingDeleteCoupleSpaceAlert) {
                Button("취소", role: .cancel) {}
                Button("영구 삭제", role: .destructive) {
                    appState.deleteCoupleSpace()
                }
            } message: {
                Text("기분 공유, 일정, 챙김, 오늘의 한 장과 연결 정보가 iCloud에서 삭제돼요. 상대도 더 이상 접근할 수 없으며 복구할 수 없어요.")
            }
            .alert("회원탈퇴를 진행할까요?", isPresented: $showingDeleteAccountAlert) {
                Button("취소", role: .cancel) {}
                Button("영구 삭제", role: .destructive) {
                    appState.deleteAccount()
                }
            } message: {
                Text(deleteAccountAlertMessage)
            }
            .alert("프로필 사진을 제거할까요?", isPresented: $showingProfilePhotoRemovalAlert) {
                Button("취소", role: .cancel) {}
                Button("제거", role: .destructive) {
                    removeProfilePhoto()
                }
            } message: {
                Text("제거하면 상대 화면에서도 기본 이니셜로 표시돼요.")
            }
            .alert(weatherRefreshSucceeded ? "새로고침 완료" : "새로고침 실패", isPresented: $showingWeatherRefreshAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(weatherRefreshSucceeded ? "현재 위치 기준으로 도시와 날씨를 업데이트했어요." : (appState.weatherErrorMessage ?? "위치와 날씨 정보를 업데이트하지 못했어요."))
            }
            .onAppear {
                draftName = appState.currentProfile?.friendlyName ?? ""
            }
            .onChange(of: appState.currentProfile?.friendlyName) { _, name in
                draftName = name ?? ""
            }
            .onChange(of: selectedProfilePhoto) { _, item in
                loadAndSaveProfilePhoto(item)
            }
        }
        .interactiveDismissDisabled(accountOperationInProgress)
    }

    private var profilePhotoControls: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                BridgeAvatar(
                    user: appState.currentProfile,
                    fallback: "나",
                    size: 88,
                    strokeColor: HomePalette.hero
                )

                PhotosPicker(selection: $selectedProfilePhoto, matching: .images) {
                    ZStack {
                        Circle()
                            .fill(HomePalette.hero)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 32, height: 32)
                    .overlay {
                        Circle()
                            .stroke(.white, lineWidth: 2)
                    }
                    .shadow(color: HomePalette.primary.opacity(0.15), radius: 3, y: 1)
                }
                .buttonStyle(.plain)
                .disabled(profilePhotoViewModel.isSaving)
                .accessibilityLabel(
                    appState.currentProfile?.profilePhotoURL == nil
                        ? "프로필 사진 등록"
                        : "프로필 사진 수정"
                )
            }

            Text(appState.currentProfile?.friendlyName ?? "나")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LongdyColors.ink)

            if profilePhotoViewModel.isSaving {
                HStack(spacing: 7) {
                    ProgressView()
                        .controlSize(.small)
                    Text("사진 저장 중")
                        .font(.caption)
                        .foregroundStyle(LongdyColors.muted)
                }
            } else if appState.currentProfile?.profilePhotoURL != nil {
                Button(role: .destructive) {
                    showingProfilePhotoRemovalAlert = true
                } label: {
                    Label("사진 제거", systemImage: "trash")
                        .font(.footnote.weight(.medium))
                }
            } else {
                Text("카메라 버튼을 눌러 사진을 등록하세요")
                    .font(.caption)
                    .foregroundStyle(LongdyColors.muted)
            }

            if let error = profilePhotoViewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
        .alignmentGuide(.listRowSeparatorTrailing) { dimensions in
            dimensions.width
        }
    }

    private var disconnectButtonTitle: String {
        if appState.isDisconnectingCouple { return "처리 중" }
        return appState.isCurrentUserCoupleOwner ? "상대 연결 해제" : "커플 공간 나가기"
    }

    private var disconnectAlertTitle: String {
        appState.isCurrentUserCoupleOwner ? "상대 연결을 해제할까요?" : "커플 공간에서 나갈까요?"
    }

    private var disconnectAlertMessage: String {
        if appState.isCurrentUserCoupleOwner {
            return "상대의 공유 접근 권한과 프로필 정보를 제거하고 기존 초대 코드를 폐기해요. 커플 공간 데이터는 유지돼요."
        }
        return "내 공유 접근 권한과 연결 정보가 제거돼요. 커플 공간 데이터는 생성자에게 남아요."
    }

    private var accountOperationInProgress: Bool {
        appState.isDisconnectingCouple
            || appState.isDeletingCoupleSpace
            || appState.isDeletingAccount
    }

    private func legalDocumentLabel(_ title: String, systemImage: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(LongdyColors.muted)
        }
    }

    private var deleteAccountAlertMessage: String {
        if appState.isCurrentUserCoupleOwner {
            return "내 프로필과 커플 공간의 기분, 일정, 챙김, 사진이 모두 삭제돼요. 상대도 공간에 접근할 수 없으며 복구할 수 없어요. Apple 계정 자체는 삭제되지 않아요."
        }
        if appState.currentProfile?.partnerCoupleId != nil {
            return "내 프로필과 내가 등록한 기분, 일정, 챙김, 사진을 삭제하고 커플 공간에서 나가요. 복구할 수 없어요. Apple 계정 자체는 삭제되지 않아요."
        }
        return "Our Bridge에 저장된 내 프로필과 앱 데이터를 삭제해요. 복구할 수 없어요. Apple 계정 자체는 삭제되지 않아요."
    }

    private func loadAndSaveProfilePhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            defer { selectedProfilePhoto = nil }
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw LongdyError.invalidInput("사진을 불러오지 못했어요.")
                }
                if let profile = await profilePhotoViewModel.save(
                    session: appState.appleSession,
                    photoData: data
                ) {
                    appState.applyUpdatedProfile(profile)
                }
            } catch {
                profilePhotoViewModel.errorMessage = error.longdyUserMessage
            }
        }
    }

    private func removeProfilePhoto() {
        Task {
            if let profile = await profilePhotoViewModel.remove(session: appState.appleSession) {
                appState.applyUpdatedProfile(profile)
            }
        }
    }
}

struct HomeCardOrderView: View {
    @EnvironmentObject private var appState: AppViewModel
    @State private var editMode: EditMode = .active

    var body: some View {
        List {
            ForEach(appState.homeCardOrder) { card in
                Label(card.title, systemImage: card.systemImage)
                    .foregroundStyle(LongdyColors.ink)
                    .padding(.vertical, 6)
            }
            .onMove(perform: appState.moveHomeCard)
        }
        .environment(\.editMode, $editMode)
        .navigationTitle("홈 카드 순서")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    appState.resetHomeCardOrder()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .accessibilityLabel("기본 순서로 초기화")
            }
        }
    }
}
