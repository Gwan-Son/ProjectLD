import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppViewModel
    @StateObject private var moodEditor = CheckInViewModel()
    @State private var showingSettings = false
    @State private var showingMoodEditor = false
    @State private var isSavingMood = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                HomePalette.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        homeHeader
                        ddayHero
                        timeCards
                        moodCard
                        recentMoments
                        presenceChips
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 94)
                }

                Button {} label: {
                    Image(systemName: "heart.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(HomePalette.primary)
                        .clipShape(Circle())
                        .shadow(color: HomePalette.primary.opacity(0.28), radius: 12, y: 6)
                }
                .accessibilityLabel("마음 보내기")
                .padding(.trailing, 20)
                .padding(.bottom, 18)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingMoodEditor) {
                MoodEditorSheet(
                    viewModel: moodEditor,
                    isSaving: isSavingMood,
                    onSave: saveMood
                )
            }
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

            Text("아워 브릿지")
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundStyle(HomePalette.primary)

            Spacer()

            Button {
                showingSettings = true
            } label: {
                Image(systemName: "bell")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(HomePalette.muted)
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel("설정")
        }
    }

    private var ddayHero: some View {
        VStack(spacing: 10) {
            Text("우리의 다음 만남")
                .font(.caption.weight(.semibold))
                .tracking(2)
                .opacity(0.78)

            HStack(alignment: .lastTextBaseline, spacing: 5) {
                Text(ddayNumber)
                    .font(.system(size: 54, weight: .bold, design: .serif))
                Text(ddayUnit)
                    .font(.system(size: 23, weight: .semibold, design: .serif))
                    .opacity(0.9)
            }

            Text(ddaySubtitle)
                .font(.system(size: 17))

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.24))
                    Capsule()
                        .fill(HomePalette.heroInk)
                        .frame(width: proxy.size.width * ddayProgress)
                }
            }
            .frame(height: 11)
            .padding(.top, 10)
            .padding(.horizontal, 22)
        }
        .foregroundStyle(HomePalette.heroInk)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 34)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(HomePalette.hero)
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
        }
        .shadow(color: HomePalette.primary.opacity(0.08), radius: 8, y: 4)
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

    private func timeCard(title: String, user: LongdyUser?, status: String, accent: Color) -> some View {
        let weather = appState.weather(for: user)
        let night = isNight(for: user)

        return glassCard {
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
                        Image(systemName: night ? "moon.fill" : "sun.max.fill")
                            .font(.system(size: 29))
                            .foregroundStyle(accent)
                        Text("\(weather.temperature)°C \(weather.summary)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(HomePalette.ink)
                    }
                }

                Label(status, systemImage: night ? "moon.stars.fill" : "clock")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(accent)
            }
        }
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
            Text(moodEmoji(for: checkIn?.mood))
                .font(.system(size: 28))
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HomePalette.ink)
                Text(checkIn.map { "\($0.mood.rawValue) · \($0.status.rawValue)" } ?? fallback)
                    .font(.system(size: 15))
                    .foregroundStyle(HomePalette.muted)
            }
            Spacer()
            Image(systemName: isPartner ? "heart.fill" : "pencil")
                .font(.system(size: 15))
                .foregroundStyle(isPartner ? HomePalette.primary : HomePalette.muted)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isPartner else { return }
            moodEditor.load(from: appState.myLatestCheckIn)
            showingMoodEditor = true
        }
        .padding(12)
        .background((isPartner ? HomePalette.hero : HomePalette.tertiary).opacity(0.13))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private func saveMood() {
        isSavingMood = true
        Task {
            await moodEditor.saveCheckIn(userId: appState.userId, coupleId: appState.coupleId)
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
                Text("저널 보기")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HomePalette.primary)
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HomePalette.primary)
            }

            ZStack(alignment: .bottomLeading) {
                memoryArtwork
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
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            .shadow(color: HomePalette.primary.opacity(0.13), radius: 14, y: 7)
        }
    }

    @ViewBuilder
    private var memoryArtwork: some View {
        if let urlString = appState.recentMemory?.storageURL,
           let url = URL(string: urlString),
           appState.recentMemory?.type == .photo {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                memoryPlaceholder
            }
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

    private var presenceChips: some View {
        HStack(spacing: 8) {
            presenceChip("cup.and.saucer.fill", "모닝 루틴", HomePalette.tertiary)
            presenceChip("heart.fill", "우리의 기록", HomePalette.hero)
            presenceChip("map.fill", distanceText, HomePalette.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func presenceChip(_ icon: String, _ text: String, _ color: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(HomePalette.ink)
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .background(color.opacity(0.22))
            .clipShape(Capsule())
    }

    private func avatar(for user: LongdyUser?, fallback: String) -> some View {
        Text(user?.friendlyName.first.map(String.init) ?? fallback)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(HomePalette.primary)
            .frame(width: 40, height: 40)
            .background(HomePalette.surface)
            .clipShape(Circle())
            .overlay(Circle().stroke(HomePalette.hero, lineWidth: 2))
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

    private var ddayNumber: String {
        guard let daysUntilMeet else { return "?" }
        return "\(abs(daysUntilMeet))"
    }

    private var ddayUnit: String {
        guard let daysUntilMeet else { return "" }
        return daysUntilMeet == 0 ? "D-day" : "일"
    }

    private var ddaySubtitle: String {
        guard let daysUntilMeet else { return "다음 만남을 플래너에서 정해보세요" }
        if daysUntilMeet == 0 { return "드디어 오늘, 다시 만나는 날" }
        if daysUntilMeet < 0 { return "함께했던 만남으로부터" }
        return "다시 만날 때까지"
    }

    private var daysUntilMeet: Int? {
        guard let meetDate = appState.couple?.nextMeetDate else { return nil }
        return Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: meetDate)
        ).day
    }

    private var ddayProgress: CGFloat {
        guard let daysUntilMeet, daysUntilMeet > 0 else { return daysUntilMeet == nil ? 0 : 1 }
        return min(max(1 - CGFloat(daysUntilMeet) / 100, 0.08), 1)
    }

    private var memoryCaption: String {
        appState.recentMemory?.createdAt.formatted(date: .abbreviated, time: .omitted) ?? "우리의 첫 번째 추억을 기다리는 중"
    }

    private var memoryText: String {
        guard let memory = appState.recentMemory else { return "\"함께 기억하고 싶은 순간을 남겨보세요.\"" }
        return memory.text.isEmpty ? "\"사진 속 순간을 오래 간직할게.\"" : "\"\(memory.text)\""
    }

    private var distanceText: String {
        let mine = appState.currentProfile?.cityName
        let partner = appState.partner?.cityName
        guard let mine, let partner, !mine.isEmpty, !partner.isEmpty else { return "우리의 거리" }
        return "\(mine) ↔ \(partner)"
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

    private func moodEmoji(for mood: Mood?) -> String {
        switch mood {
        case .clear: "☀️"
        case .calm: "☕"
        case .tired: "😴"
        case .lonely: "🌙"
        case .sensitive: "🌧️"
        case .excited: "✨"
        case nil: "💭"
        }
    }
}

private enum HomePalette {
    static let background = Color(red: 1.00, green: 0.96, blue: 0.97)
    static let surface = Color(red: 1.00, green: 0.98, blue: 0.98)
    static let primary = Color(red: 0.58, green: 0.28, blue: 0.26)
    static let hero = Color(red: 0.96, green: 0.59, blue: 0.56)
    static let heroInk = Color(red: 0.44, green: 0.18, blue: 0.16)
    static let secondary = Color(red: 0.49, green: 0.33, blue: 0.25)
    static let tertiary = Color(red: 0.80, green: 0.67, blue: 0.55)
    static let ink = Color(red: 0.16, green: 0.09, blue: 0.13)
    static let muted = Color(red: 0.33, green: 0.26, blue: 0.25)
}

struct MoodEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CheckInViewModel
    let isSaving: Bool
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("기분 공유 수정")
                            .font(.system(size: 28, weight: .bold, design: .serif))
                            .foregroundStyle(HomePalette.primary)
                        Text("마음과 상태를 고르고, 얼마나 오래 보여둘지 정해요.")
                            .font(.callout)
                            .foregroundStyle(HomePalette.muted)
                    }

                    editorCard {
                        pickerRow("마음", selection: $viewModel.mood, values: Mood.allCases)
                        Divider().opacity(0.35)
                        pickerRow("상태", selection: $viewModel.status, values: LongdyStatus.allCases)
                        Divider().opacity(0.35)
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

    private func pickerRow<Value: RawRepresentable & Hashable & Identifiable>(
        _ title: String,
        selection: Binding<Value>,
        values: [Value]
    ) -> some View where Value.RawValue == String {
        Picker(title, selection: selection) {
            ForEach(values) { value in
                Text(value.rawValue).tag(value)
            }
        }
        .font(.body)
        .foregroundStyle(HomePalette.ink)
        .tint(HomePalette.primary)
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppViewModel
    @State private var showingCopyAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section("내 정보") {
                    HStack {
                        Text("이름")
                        Spacer()
                        Text(appState.currentProfile?.friendlyName ?? "이름 없음")
                            .foregroundStyle(LongdyColors.muted)
                    }
                    HStack {
                        Text("도시")
                        Spacer()
                        Text(appState.currentProfile?.cityName ?? "-")
                            .foregroundStyle(LongdyColors.muted)
                    }
                    HStack {
                        Text("시간대")
                        Spacer()
                        Text(appState.currentProfile?.timezoneId ?? "-")
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
        }
    }
}
