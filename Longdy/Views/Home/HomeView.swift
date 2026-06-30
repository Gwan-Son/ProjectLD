import PhotosUI
import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject private var appState: AppViewModel
    @StateObject private var moodEditor = CheckInViewModel()
    @State private var showingSettings = false
    @State private var showingMoodEditor = false
    @State private var showingBridgeProgress = false
    @State private var isSavingMood = false
    @State private var selectedWeatherUser: LongdyUser?
    @State private var selectedMeetingPage = 1

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                HomePalette.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        homeHeader
                            .zIndex(10)
                        ForEach(appState.homeCardOrder) { card in
                            homeCard(card)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 94)
                }

                Button(action: presentMoodEditor) {
                    Image("mood-edit-fab")
                        .resizable()
                        .scaledToFit()
                        .padding(6)
                        .frame(width: 60, height: 60)
                        .background(
                            LinearGradient(
                                colors: [CalendarPalette.hero, CalendarPalette.secondaryContainer],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: HomePalette.primary.opacity(0.28), radius: 12, y: 6)
                }
                .accessibilityLabel("기분 공유 수정")
                .padding(.trailing, 20)
                .padding(.bottom, 18)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingMoodEditor) {
                MoodEditorSheet(
                    viewModel: moodEditor,
                    isSaving: isSavingMood,
                    onSave: saveMood
                )
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(appState)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingBridgeProgress) {
            BridgeProgressView()
                .environmentObject(appState)
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(item: $selectedWeatherUser) { user in
            WeatherDetailView(user: user, weather: appState.weather(for: user)) {
                appState.refreshLocationAndWeather()
            }
            .presentationBackground(.clear)
        }
    }

    private var homeHeader: some View {
        HStack {
            HStack(spacing: 6) {
                avatar(for: appState.currentProfile, fallback: "나")
                Capsule()
                    .fill(HomePalette.hero)
                    .frame(width: 28, height: 4)
                    .padding(.horizontal, 2)
                avatar(for: appState.partner, fallback: "?")
            }

            Spacer()

            Text("Our Bridge")
                .font(.system(size: 22, weight: .medium, design: .serif))
                .foregroundStyle(HomePalette.primary)

            Spacer()

            Button {
                showingSettings = true
            } label: {
                Image("settings-icon")
                    .resizable()
                    .scaledToFit()
                    .padding(3)
                    .frame(width: 50, height: 50)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityLabel("설정")
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .zIndex(10)
    }

    @ViewBuilder
    private func homeCard(_ card: HomeCardKind) -> some View {
        switch card {
        case .nextMeeting:
            ddayHero
                .zIndex(0)
        case .connectedBridge:
            bridgeProgressCard
        case .timeAndWeather:
            timeCards
        case .mood:
            moodCard
        case .recentMoments:
            recentMoments
        }
    }

    private var ddayHero: some View {
        TabView(selection: $selectedMeetingPage) {
            meetingHero(
                heading: "우리의 이전 만남",
                date: previousMeetingDate,
                eventTitle: previousMeetingEvent?.title,
                isPrevious: true
            )
            .tag(0)

            meetingHero(
                heading: "우리의 다음 만남",
                date: nextMeetingDate,
                eventTitle: nextMeetingEvent?.title,
                isPrevious: false
            )
            .tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .interactive))
        .frame(height: 250)
    }

    private func meetingHero(heading: String, date: Date?, eventTitle: String?, isPrevious: Bool) -> some View {
        VStack(spacing: 10) {
            Text(heading)
                .font(.caption.weight(.semibold))
                .tracking(2)
                .opacity(0.78)

            Text(meetingCountdown(for: date, isPrevious: isPrevious))
                .font(.system(size: 50, weight: .bold, design: .serif))

            Text(meetingSummary(date: date, eventTitle: eventTitle, isPrevious: isPrevious))
                .font(.system(size: 17, weight: .medium))
                .lineLimit(1)

            Text(meetingDateText(date))
                .font(.caption.weight(.medium))
                .opacity(0.72)
        }
        .foregroundStyle(HomePalette.heroInk)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 32)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(isPrevious ? HomePalette.tertiary.opacity(0.72) : HomePalette.hero)
                Circle()
                    .fill(.white.opacity(0.13))
                    .frame(width: 180)
                    .offset(x: 150, y: -88)
                Circle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 160)
                    .offset(x: -160, y: 100)
            }
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .allowsHitTesting(false)
        }
        .padding(.horizontal, 2)
    }

    private var timeCards: some View {
        VStack(spacing: 14) {
            timeCard(
                title: "나의 시간",
                user: appState.currentProfile,
                status: appState.myLatestCheckIn?.status.rawValue ?? "오늘도 좋은 하루",
                accent: HomePalette.secondary
            )
            timeCard(
                title: "상대방 시간",
                user: appState.partner,
                status: appState.partnerLatestCheckIn?.status.rawValue ?? "상대의 소식을 기다리는 중",
                accent: HomePalette.primary
            )
        }
    }

    private var bridgeProgressCard: some View {
        let progress = appState.dailyBridgeProgress

        return Button {
            showingBridgeProgress = true
        } label: {
            glassCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("연결된 다리")
                                .font(.system(size: 21, weight: .semibold, design: .serif))
                                .foregroundStyle(HomePalette.ink)
                            Text(progress.stageTitle)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(HomePalette.muted)
                        }
                        Spacer()
                        Text("\(progress.points)")
                            .font(.system(size: 30, weight: .bold, design: .serif))
                            .foregroundStyle(HomePalette.primary)
                        Text("/ 100")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(HomePalette.muted)
                            .padding(.top, 12)
                    }

                    Image(progress.assetName)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1.5, contentMode: .fit)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .id(progress.assetName)

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(HomePalette.hero.opacity(0.18))
                            Capsule()
                                .fill(HomePalette.hero)
                                .frame(width: proxy.size.width * progress.fraction)
                        }
                    }
                    .frame(height: 10)

                    HStack {
                        Text("오늘의 행동으로 둘 사이의 다리를 이어요.")
                            .font(.caption)
                            .foregroundStyle(HomePalette.muted)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(HomePalette.primary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("연결된 다리 \(progress.points)점, 상세 보기")
    }

    private func timeCard(title: String, user: LongdyUser?, status: String, accent: Color) -> some View {
        let weather = appState.weather(for: user)
        let night = isNight(for: user)

        return Button {
            selectedWeatherUser = user
        } label: {
            glassCard {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("\(title) · \(weather.cityName)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(HomePalette.muted)
                            TimelineView(.periodic(from: .now, by: 60)) { context in
                                Text(timeText(for: user, date: context.date))
                                    .font(.system(size: 29, weight: .bold, design: .serif))
                                    .foregroundStyle(HomePalette.ink)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Image(weather.iconName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                            Text(weatherText(weather))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(HomePalette.ink)
                        }
                    }

                    HStack {
                        Label(status, systemImage: night ? "moon.stars.fill" : "clock")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(accent)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(HomePalette.muted)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(user == nil)
        .accessibilityLabel("\(title) 날씨 상세 보기")
    }

    private func weatherText(_ weather: WeatherSummary) -> String {
        guard let temperature = weather.temperature else { return weather.summary }
        return "\(temperature)°C \(weather.summary)"
    }

    private var moodCard: some View {
        glassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("기분 공유")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HomePalette.muted)

                moodRow(
                    label: "나",
                    checkIn: appState.myLatestCheckIn,
                    fallback: "내 기분을 남겨보세요",
                    isPartner: false
                )
                moodRow(
                    label: appState.partner?.friendlyName ?? "상대방",
                    checkIn: appState.partnerLatestCheckIn,
                    fallback: "아직 도착한 소식이 없어요",
                    isPartner: true
                )
            }
        }
    }

    private func moodRow(label: String, checkIn: CheckIn?, fallback: String, isPartner: Bool) -> some View {
        HStack(spacing: 14) {
            Group {
                if let mood = checkIn?.mood {
                    Image(mood.iconName)
                        .resizable()
                        .scaledToFit()
                        .padding(5)
                } else if isPartner {
                    Image("empty-news")
                        .resizable()
                        .scaledToFit()
                        .padding(4)
                } else {
                    Image("empty-state")
                        .resizable()
                        .scaledToFit()
                        .padding(4)
                }
            }
            .frame(width: 50, height: 50)
            .background(HomePalette.surface.opacity(0.75))
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HomePalette.ink)
                Text(checkIn.map { "\($0.mood.rawValue) · \($0.status.rawValue)" } ?? fallback)
                    .font(.system(size: 15))
                    .foregroundStyle(HomePalette.muted)
            }
            Spacer()
            if let status = checkIn?.status {
                Image(status.iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
            } else {
                Image(isPartner ? "empty-state" : "mood-edit-fab")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isPartner else { return }
            presentMoodEditor()
        }
        .padding(12)
        .background((isPartner ? HomePalette.hero : HomePalette.tertiary).opacity(0.13))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private func presentMoodEditor() {
        moodEditor.load(from: appState.myLatestCheckIn)
        showingMoodEditor = true
    }

    private func saveMood() {
        isSavingMood = true
        Task {
            if let checkIn = await moodEditor.saveCheckIn(userId: appState.userId, coupleId: appState.coupleId) {
                appState.applySavedCheckIn(checkIn)
            }
            isSavingMood = false
            if moodEditor.errorMessage == nil {
                showingMoodEditor = false
            }
        }
    }

    private var recentMoments: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("최근의 순간들")
                    .font(.system(size: 23, weight: .medium, design: .serif))
                    .foregroundStyle(HomePalette.ink)
                Spacer()
                Button {
                    appState.selectedMainTab = .todayPhoto
                } label: {
                    HStack(spacing: 5) {
                        Text("더보기")
                            .font(.caption.weight(.semibold))
                        Image(systemName: "arrow.right")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(HomePalette.primary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("오늘의 한 장 더보기")
            }

            ZStack(alignment: .bottomLeading) {
                memoryArtwork
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
                    .clipped()
                LinearGradient(
                    colors: [.clear, .black.opacity(0.58)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                VStack(alignment: .leading, spacing: 5) {
                    Text(memoryCaption)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.82))
                    Text(memoryText)
                        .font(.system(size: 21, weight: .medium, design: .serif))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                }
                .padding(22)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 260)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            .shadow(color: HomePalette.primary.opacity(0.13), radius: 14, y: 7)
        }
    }

    @ViewBuilder
    private var memoryArtwork: some View {
        if let urlString = appState.recentMemory?.thumbnailURL,
           let url = URL(string: urlString) {
            HomeMemoryArtwork(url: url)
        } else {
            memoryPlaceholder
        }
    }

    private var memoryPlaceholder: some View {
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

    private func avatar(for user: LongdyUser?, fallback: String) -> some View {
        BridgeAvatar(user: user, fallback: fallback)
    }

    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HomePalette.surface.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.72), lineWidth: 1)
            }
            .shadow(color: HomePalette.primary.opacity(0.05), radius: 16, y: 8)
    }

    private var previousMeetingEvent: CoupleEvent? {
        let today = Calendar.current.startOfDay(for: Date())
        return appState.events
            .filter { $0.type == .meet && $0.startAt < today }
            .max { $0.startAt < $1.startAt }
    }

    private var nextMeetingEvent: CoupleEvent? {
        let today = Calendar.current.startOfDay(for: Date())
        return appState.events
            .filter { $0.type == .meet && $0.startAt >= today }
            .min { $0.startAt < $1.startAt }
    }

    private var previousMeetingDate: Date? {
        if let date = previousMeetingEvent?.startAt { return date }
        guard let date = appState.couple?.nextMeetDate,
              date < Calendar.current.startOfDay(for: Date()) else { return nil }
        return date
    }

    private var nextMeetingDate: Date? {
        if let date = nextMeetingEvent?.startAt { return date }
        guard let date = appState.couple?.nextMeetDate,
              date >= Calendar.current.startOfDay(for: Date()) else { return nil }
        return date
    }

    private func meetingCountdown(for date: Date?, isPrevious: Bool) -> String {
        guard let date else { return "?" }
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: Date()),
            to: calendar.startOfDay(for: date)
        ).day ?? 0
        if days == 0 { return "D-day" }
        return isPrevious ? "D+\(abs(days))" : "D-\(max(days, 0))"
    }

    private func meetingSummary(date: Date?, eventTitle: String?, isPrevious: Bool) -> String {
        if let eventTitle, !eventTitle.isEmpty { return eventTitle }
        guard date != nil else {
            return isPrevious ? "아직 기록된 이전 만남이 없어요" : "다음 만남을 캘린더에서 정해보세요"
        }
        return isPrevious ? "함께했던 소중한 만남" : "다시 만나는 날"
    }

    private func meetingDateText(_ date: Date?) -> String {
        guard let date else { return "날짜 없음" }
        return date.formatted(.dateTime.year().month(.wide).day().weekday(.wide))
    }

    private var memoryCaption: String {
        appState.recentMemory?.createdAt.formatted(date: .abbreviated, time: .omitted) ?? "오늘의 한 장을 기다리는 중"
    }

    private var memoryText: String {
        guard let memory = appState.recentMemory else { return "\"오늘 서로에게 보여주고 싶은 장면을 남겨보세요.\"" }
        return memory.text.isEmpty ? "\"오늘의 장면이 조용히 도착했어요.\"" : "\"\(memory.text)\""
    }

    private func timeText(for user: LongdyUser?, date: Date) -> String {
        guard let timezone = TimeZone(identifier: user?.timezoneId ?? "") else { return "--:--" }
        let formatter = DateFormatter()
        formatter.timeZone = timezone
        formatter.dateFormat = "a h:mm"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }

    private func isNight(for user: LongdyUser?) -> Bool {
        guard let timezone = TimeZone(identifier: user?.timezoneId ?? "") else { return false }
        var calendar = Calendar.current
        calendar.timeZone = timezone
        let hour = calendar.component(.hour, from: Date())
        return hour < 6 || hour >= 20
    }

}

private struct HomeMemoryArtwork: View {
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

private struct HomeMemoryPlaceholder: View {
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
    @State private var showingWeatherRefreshAlert = false
    @State private var weatherRefreshSucceeded = false
    @State private var draftName = ""
    @StateObject private var profilePhotoViewModel = ProfilePhotoViewModel()
    @State private var selectedProfilePhoto: PhotosPickerItem?
    @State private var showingProfilePhotoRemovalAlert = false

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
                                appState.isDisconnectingCouple ? "연결 끊는 중" : "연결 끊기",
                                systemImage: "heart.slash"
                            )
                        }
                        .disabled(appState.isDisconnectingCouple)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        dismiss()
                        appState.signOut()
                    } label: {
                        Label("로그아웃", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("설정")
            .toolbar {
                Button("닫기") {
                    dismiss()
                }
            }
            .alert("복사 완료", isPresented: $showingCopyAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("초대 코드가 클립보드에 복사됐어요.")
            }
            .alert("커플 연결을 끊을까요?", isPresented: $showingDisconnectAlert) {
                Button("취소", role: .cancel) {}
                Button("연결 끊기", role: .destructive) {
                    dismiss()
                    appState.disconnectCouple()
                }
            } message: {
                Text("이 기기에서 커플 공간 연결이 해제돼요. 다시 연결하려면 초대 코드를 새로 만들어야 해요.")
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
    }

    private var profilePhotoControls: some View {
        HStack(spacing: 16) {
            BridgeAvatar(
                user: appState.currentProfile,
                fallback: "나",
                size: 72,
                strokeColor: HomePalette.hero
            )

            VStack(alignment: .leading, spacing: 10) {
                Text("프로필 사진")
                    .font(.subheadline.weight(.semibold))

                if profilePhotoViewModel.isSaving {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("저장 중")
                            .font(.caption)
                            .foregroundStyle(LongdyColors.muted)
                    }
                } else if appState.currentProfile?.profilePhotoURL == nil {
                    PhotosPicker(selection: $selectedProfilePhoto, matching: .images) {
                        Label("사진 등록", systemImage: "photo.badge.plus")
                    }
                } else {
                    HStack(spacing: 14) {
                        PhotosPicker(selection: $selectedProfilePhoto, matching: .images) {
                            Label("수정", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            showingProfilePhotoRemovalAlert = true
                        } label: {
                            Label("제거", systemImage: "trash")
                        }
                    }
                }

                if let error = profilePhotoViewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.vertical, 6)
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

private struct HomeCardOrderView: View {
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
