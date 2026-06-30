import SwiftUI
import UIKit

struct CareView: View {
    @EnvironmentObject private var appState: AppViewModel
    @StateObject private var viewModel = CareViewModel()
    @State private var showingIconPicker = false
    @State private var showingAddCare = false
    @State private var editingItem: CareItem?

    private var allCareItems: [CareItem] {
        let today = Date()
        let todayKey = DateKey.dateKey(for: today)
        return (appState.myCareItems + appState.partnerCareItems)
            .filter { item in
                if item.repeatRule == .once { return item.dateKey == todayKey }
                return item.repeatRule.applies(to: today, createdAt: item.createdAt)
            }
            .sorted { first, second in
                if first.isDoneToday != second.isDoneToday {
                    return !first.isDoneToday
                }
                return first.createdAt < second.createdAt
            }
    }

    private var remainingCount: Int {
        allCareItems.filter { !$0.isDoneToday }.count
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        careHero
                        todayCareList
                        pastCareLink

                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 92)
                }

                Button {
                    showingAddCare = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(CarePalette.ink)
                        .frame(width: 56, height: 56)
                        .background(
                            LinearGradient(
                                colors: [CalendarPalette.hero, CalendarPalette.secondaryContainer],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: CarePalette.primary.opacity(0.22), radius: 14, y: 7)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("챙김 항목 추가")
                .padding(.trailing, 20)
                .padding(.bottom, 18)
            }
            .toolbar(.hidden, for: .navigationBar)
            .background(CarePalette.background.ignoresSafeArea())
            .sheet(isPresented: $showingAddCare) {
                NavigationStack {
                    ScrollView(showsIndicators: false) {
                        addCareCard
                            .padding(.horizontal, 20)
                            .padding(.vertical, 18)
                    }
                    .background(CarePalette.background.ignoresSafeArea())
                    .navigationTitle("새로운 챙김")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("닫기") {
                                showingAddCare = false
                            }
                            .foregroundStyle(CarePalette.primary)
                        }
                    }
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $editingItem) { item in
                CareItemEditorView(item: item, coupleId: appState.coupleId, viewModel: viewModel)
            }
            .onAppear {
                appState.refreshCoupleData(force: true)
            }
        }
    }

    private var careHero: some View {
        BridgeScreenHeader(
            currentUser: appState.currentProfile,
            partner: appState.partner,
            eyebrow: "서로를 아끼는 마음",
            title: "서로 챙김",
            summary: remainingCount == 0 ? "오늘의 챙김을 모두 마쳤어요" : "오늘의 챙김 \(remainingCount)개 남음",
            primaryColor: CarePalette.primary,
            secondaryColor: CarePalette.secondary,
            inkColor: CarePalette.ink
        )
    }

    private var todayCareList: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("오늘의 챙김")
                    .font(.system(size: 24, weight: .medium, design: .serif))
                    .foregroundStyle(CarePalette.ink)
                Spacer()
                Text(Date.now.formatted(.dateTime.month(.wide).day().weekday(.wide)))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(CarePalette.outline)
            }

            if allCareItems.isEmpty {
                EmptyStateView(
                    title: "오늘은 아직 비어 있어요",
                    message: "나와 상대를 위한 작은 챙김을 하나 남겨봐요.",
                    systemImage: "heart.text.square"
                )
                .background(CarePalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(allCareItems.enumerated()), id: \.element.id) { index, item in
                        CareItemRow(
                            item: item,
                            ownerName: ownerName(for: item),
                            ownerInitial: ownerInitial(for: item),
                            tint: rowTint(for: index),
                            canEdit: item.userId == appState.userId && item.effectiveSyncState == .synced,
                            onRetry: retryAction(for: item)
                        ) {
                            toggleCareItem(item)
                        }
                        .contextMenu {
                            if item.userId == appState.userId && item.effectiveSyncState == .synced {
                                Button {
                                    editingItem = item
                                } label: {
                                    Label("수정", systemImage: "pencil")
                                }
                                Button(item.isDoneToday ? "다시 챙기기 전으로" : "챙김 완료") {
                                    toggleCareItem(item)
                                }
                                Button("삭제", role: .destructive) {
                                    deleteCareItem(item)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var addCareCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("새로운 챙김 추가")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(CarePalette.primary)

            TextField("챙겨줄 내용을 입력하세요", text: $viewModel.title)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(CarePalette.surface)
                .clipShape(Capsule())
                .overlay(alignment: .trailing) {
                    Image(systemName: "pencil")
                        .foregroundStyle(CarePalette.outline)
                        .padding(.trailing, 14)
                }

            HStack(spacing: 10) {
                Button {
                    showingIconPicker = true
                } label: {
                    HStack(spacing: 10) {
                        CareIconImage(name: viewModel.selectedIconName)
                            .frame(width: 34, height: 34)
                            .background(CarePalette.primaryContainer.opacity(0.2))
                            .clipShape(Circle())
                        Text("변경")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(CarePalette.ink)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(CarePalette.outline)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
                .careInputShell()

                Picker("반복", selection: $viewModel.repeatRule) {
                    ForEach(CareRepeatRule.allCases) { rule in
                        Text(rule.rawValue)
                            .tag(rule)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .careInputShell()
            }

            Toggle("시간 알림", isOn: $viewModel.reminderEnabled)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(CarePalette.ink)
                .tint(CarePalette.primary)

            if viewModel.reminderEnabled {
                DatePicker("알림 시간", selection: $viewModel.reminderTime, displayedComponents: .hourAndMinute)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CarePalette.ink)
                    .careInputShell()
            }

            TextField("짧은 메모", text: $viewModel.note, axis: .vertical)
                .lineLimit(1...3)
                .textFieldStyle(.plain)
                .padding(14)
                .background(CarePalette.surface)
                .clipShape(Capsule())

            Button {
                if let item = viewModel.makePendingCareItem(userId: appState.userId) {
                    appState.applySavedCareItem(item)
                    showingAddCare = false
                    Task {
                        let savedItem = await viewModel.persistCareItem(
                            coupleId: appState.coupleId,
                            item: item
                        )
                        appState.applySavedCareItem(savedItem)
                    }
                }
            } label: {
                Label("항목 추가하기", systemImage: "plus")
            }
            .buttonStyle(CarePrimaryButtonStyle())
        }
        .fullScreenCover(isPresented: $showingIconPicker) {
            CareIconPickerView(selectedIconName: $viewModel.selectedIconName)
        }
        .padding(16)
        .background(CarePalette.primaryContainer.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(CarePalette.primaryContainer.opacity(0.24), lineWidth: 1)
        }
    }

    private var pastCareLink: some View {
        NavigationLink {
            PastCareView()
                .environmentObject(appState)
        } label: {
            Text("지난 챙김 보기")
                .font(.caption.weight(.semibold))
                .foregroundStyle(CarePalette.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(CarePalette.secondary.opacity(0.16))
                .clipShape(Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("지난 챙김 보기")
    }

    private func ownerName(for item: CareItem) -> String {
        if item.userId == appState.userId {
            return "나"
        }
        return appState.partner?.friendlyName ?? "상대"
    }

    private func ownerInitial(for item: CareItem) -> String {
        if item.userId == appState.userId {
            return appState.currentProfile?.friendlyName.first.map(String.init) ?? "나"
        }
        return appState.partner?.friendlyName.first.map(String.init) ?? "?"
    }

    private func rowTint(for index: Int) -> Color {
        [CarePalette.primary, CarePalette.secondary, CarePalette.tertiary][index % 3]
    }

    private func toggleCareItem(_ item: CareItem) {
        appState.toggleCareItemLocally(item, dateKey: viewModel.todayDateKey)
        Task {
            let succeeded = await viewModel.toggleCareItem(coupleId: appState.coupleId, item: item)
            if !succeeded {
                appState.applySavedCareItem(item)
            }
        }
    }

    private func retryCareItem(_ item: CareItem) {
        var pendingItem = item
        pendingItem.syncState = .pending
        appState.applySavedCareItem(pendingItem)
        Task {
            let savedItem = await viewModel.persistCareItem(
                coupleId: appState.coupleId,
                item: pendingItem
            )
            appState.applySavedCareItem(savedItem)
        }
    }

    private func retryAction(for item: CareItem) -> (() -> Void)? {
        switch item.effectiveSyncState {
        case .failed:
            return { retryCareItem(item) }
        case .deleteFailed:
            return { deleteCareItem(item) }
        default:
            return nil
        }
    }

    private func deleteCareItem(_ item: CareItem) {
        var deletingItem = item
        deletingItem.syncState = .deleting
        appState.applySavedCareItem(deletingItem)
        Task {
            let succeeded = await viewModel.deleteCareItem(coupleId: appState.coupleId, item: item)
            if succeeded {
                appState.removeCareItem(item)
            } else {
                var failedItem = item
                failedItem.syncState = .deleteFailed
                appState.applySavedCareItem(failedItem)
            }
        }
    }
}

private struct PastCareView: View {
    @EnvironmentObject private var appState: AppViewModel

    private var pastItems: [CareItem] {
        let todayKey = DateKey.dateKey()
        return (appState.myCareItems + appState.partnerCareItems)
            .filter { $0.repeatRule == .once && $0.dateKey < todayKey }
            .sorted {
                if $0.dateKey != $1.dateKey { return $0.dateKey > $1.dateKey }
                return $0.createdAt > $1.createdAt
            }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                if pastItems.isEmpty {
                    EmptyStateView(
                        title: "지난 챙김이 없어요",
                        message: "기한이 지난 오늘만 챙김이 여기에 모여요.",
                        systemImage: "clock.arrow.circlepath"
                    )
                    .background(CarePalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    ForEach(Array(pastItems.enumerated()), id: \.element.id) { index, item in
                        PastCareItemRow(
                            item: item,
                            ownerName: ownerName(for: item),
                            ownerInitial: ownerInitial(for: item),
                            tint: rowTint(for: index)
                        )
                    }
                }
            }
            .padding(20)
        }
        .background(CarePalette.background.ignoresSafeArea())
        .navigationTitle("지난 챙김")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .onAppear {
            appState.refreshCoupleData(force: true)
        }
    }

    private func ownerName(for item: CareItem) -> String {
        item.userId == appState.userId ? "나" : (appState.partner?.friendlyName ?? "상대")
    }

    private func ownerInitial(for item: CareItem) -> String {
        if item.userId == appState.userId {
            return appState.currentProfile?.friendlyName.first.map(String.init) ?? "나"
        }
        return appState.partner?.friendlyName.first.map(String.init) ?? "?"
    }

    private func rowTint(for index: Int) -> Color {
        [CarePalette.primary, CarePalette.secondary, CarePalette.tertiary][index % 3]
    }
}

private struct PastCareItemRow: View {
    let item: CareItem
    let ownerName: String
    let ownerInitial: String
    let tint: Color

    private var wasCompleted: Bool {
        item.doneDateKeys.contains(item.dateKey)
    }

    var body: some View {
        HStack(spacing: 14) {
            CareIconImage(name: item.iconName)
                .frame(width: 54, height: 54)
                .background(tint.opacity(0.14))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(CarePalette.ink)
                        .lineLimit(1)
                    Text(ownerInitial)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(CarePalette.primary)
                        .frame(width: 20, height: 20)
                        .background(CarePalette.surfaceHigh)
                        .clipShape(Circle())
                        .accessibilityLabel(ownerName)
                }

                Text(dateText)
                    .font(.caption)
                    .foregroundStyle(CarePalette.outline)

                if !item.note.isEmpty {
                    Text(item.note)
                        .font(.caption)
                        .foregroundStyle(CarePalette.muted)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: wasCompleted ? "checkmark.circle.fill" : "minus.circle")
                .font(.system(size: 23))
                .foregroundStyle(wasCompleted ? CarePalette.primary : CarePalette.outline)
                .accessibilityLabel(wasCompleted ? "완료" : "미완료")
        }
        .padding(16)
        .background(CarePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(CarePalette.line.opacity(0.45), lineWidth: 1)
        }
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: item.dateKey) else { return item.dateKey }
        return date.formatted(.dateTime.year().month(.wide).day())
    }
}

struct CareItemEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let item: CareItem
    let coupleId: String?
    @ObservedObject var viewModel: CareViewModel

    @State private var title: String
    @State private var iconName: String
    @State private var repeatRule: CareRepeatRule
    @State private var reminderEnabled: Bool
    @State private var reminderTime: Date
    @State private var note: String
    @State private var showingIconPicker = false
    @State private var isSaving = false

    init(item: CareItem, coupleId: String?, viewModel: CareViewModel) {
        self.item = item
        self.coupleId = coupleId
        self.viewModel = viewModel
        _title = State(initialValue: item.title)
        _iconName = State(initialValue: item.iconName)
        _repeatRule = State(initialValue: item.repeatRule)
        _reminderEnabled = State(initialValue: item.reminderHour != nil && item.reminderMinute != nil)

        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = item.reminderHour ?? 9
        components.minute = item.reminderMinute ?? 0
        _reminderTime = State(initialValue: Calendar.current.date(from: components) ?? Date())
        _note = State(initialValue: item.note)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("챙김 항목") {
                    TextField("챙김 이름", text: $title)

                    Button {
                        showingIconPicker = true
                    } label: {
                        HStack(spacing: 12) {
                            CareIconImage(name: iconName)
                                .frame(width: 42, height: 42)
                                .background(CarePalette.surfaceContainer)
                                .clipShape(Circle())
                            Text("아이콘")
                                .foregroundStyle(CarePalette.ink)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(CarePalette.outline)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Section("반복과 알림") {
                    Picker("반복", selection: $repeatRule) {
                        ForEach(CareRepeatRule.allCases) { rule in
                            Text(rule.rawValue).tag(rule)
                        }
                    }

                    Toggle("시간 알림", isOn: $reminderEnabled)
                        .tint(CarePalette.primary)

                    if reminderEnabled {
                        DatePicker("알림 시간", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                }

                Section("메모") {
                    TextField("짧은 메모", text: $note, axis: .vertical)
                        .lineLimit(1...4)
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(CarePalette.background)
            .navigationTitle("챙김 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .fontWeight(.semibold)
                        .disabled(isSaving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .fullScreenCover(isPresented: $showingIconPicker) {
                CareIconPickerView(selectedIconName: $iconName)
            }
        }
    }

    private func save() {
        isSaving = true
        Task {
            let succeeded = await viewModel.editCareItem(
                coupleId: coupleId,
                item: item,
                title: title,
                iconName: iconName,
                repeatRule: repeatRule,
                reminderEnabled: reminderEnabled,
                reminderTime: reminderTime,
                note: note
            )
            isSaving = false
            if succeeded { dismiss() }
        }
    }
}

struct CareIconPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedIconName: String
    @State private var searchText = ""

    private let categories: [CareIconCategory] = [
        CareIconCategory(title: "식사와 건강", iconName: "care-food-health", icons: [
            CareIconOption(name: "drink-water", title: "물 마시기"),
            CareIconOption(name: "meal", title: "식사 챙기기"),
            CareIconOption(name: "medicine", title: "약 먹기"),
            CareIconOption(name: "supplement", title: "영양제")
        ]),
        CareIconCategory(title: "활동", iconName: "care-activity", icons: [
            CareIconOption(name: "exercise", title: "운동하기"),
            CareIconOption(name: "walk", title: "산책하기"),
            CareIconOption(name: "stretch", title: "스트레칭"),
            CareIconOption(name: "rest", title: "휴식하기")
        ]),
        CareIconCategory(title: "생활과 마음", iconName: "care-life-mind", icons: [
            CareIconOption(name: "sleep", title: "일찍 자기"),
            CareIconOption(name: "reading", title: "책 읽기"),
            CareIconOption(name: "call", title: "전화하기"),
            CareIconOption(name: "mindfulness", title: "마음 챙기기")
        ])
    ]

    private var hasSearchText: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var searchQuery: String {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return query
    }

    var body: some View {
        ZStack {
            CarePalette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                topAppBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        searchBar
                        selectedPreview
                        iconSections
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 120)
                }
            }

            VStack {
                Spacer()
                confirmFooter
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private var topAppBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(CarePalette.primary)
                    .frame(width: 40, height: 40)
                    .background(CarePalette.primaryContainer.opacity(0.001))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("뒤로")

            Spacer()

            Text("아이콘 선택")
                .font(.system(size: 24, weight: .medium, design: .serif))
                .foregroundStyle(CarePalette.ink)

            Spacer()

            Color.clear
                .frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }

    private var confirmFooter: some View {
        VStack {
            Button {
                dismiss()
            } label: {
                Text("확인")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [CarePalette.primary, CarePalette.secondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: CarePalette.primary.opacity(0.18), radius: 10, y: 5)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .background(.ultraThinMaterial)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 8, topTrailingRadius: 8, style: .continuous))
    }

    private func matchesSearch(icon: CareIconOption, category: CareIconCategory) -> Bool {
        guard hasSearchText else { return true }
        return icon.name.localizedCaseInsensitiveContains(searchQuery)
            || icon.title.localizedCaseInsensitiveContains(searchQuery)
            || category.title.localizedCaseInsensitiveContains(searchQuery)
    }

    private func categoryHasMatch(_ category: CareIconCategory) -> Bool {
        guard hasSearchText else { return true }
        return category.icons.contains { matchesSearch(icon: $0, category: category) }
            || category.title.localizedCaseInsensitiveContains(searchQuery)
    }

    private var iconSections: some View {
        VStack(alignment: .leading, spacing: 48) {
            ForEach(categories.filter(categoryHasMatch)) { category in
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 12) {
                        CareIconImage(name: category.iconName)
                            .padding(5)
                            .frame(width: 44, height: 44)
                            .background(CarePalette.surfaceContainer)
                            .clipShape(Circle())

                        Text(category.title)
                            .font(.system(size: 24, weight: .medium, design: .serif))
                            .foregroundStyle(CarePalette.ink)
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 16) {
                        ForEach(category.icons) { icon in
                            CareIconButton(
                                icon: icon,
                                isSelected: selectedIconName == icon.name,
                                isDimmed: !matchesSearch(icon: icon, category: category)
                            ) {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                                    selectedIconName = icon.name
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(CarePalette.outline)
            TextField("어떤 활동을 기록할까요?", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(CarePalette.surfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var selectedPreview: some View {
        VStack(spacing: 10) {
            CareIconImage(name: selectedIconName)
                .frame(width: 104, height: 104)
                .background(CarePalette.primaryContainer)
                .clipShape(Circle())
            Text("선택된 아이콘")
                .font(.caption.weight(.semibold))
                .foregroundStyle(CarePalette.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(CarePalette.surfaceContainer)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct CareIconButton: View {
    let icon: CareIconOption
    let isSelected: Bool
    let isDimmed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                CareIconImage(name: icon.name)
                    .padding(8)
                    .frame(width: 72, height: 72)
                    .background(isSelected ? CarePalette.primaryContainer : CarePalette.surfaceContainer)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(isSelected ? CarePalette.primary : .clear, lineWidth: 2)
                    }
                    .scaleEffect(isSelected ? 0.95 : 1)

                Text(icon.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isSelected ? CarePalette.primary : CarePalette.onSurfaceVariant)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
                .frame(maxWidth: .infinity, minHeight: 98, alignment: .top)
                .opacity(isDimmed ? 0.3 : 1)
                .animation(.easeInOut(duration: 0.2), value: isSelected)
                .animation(.easeInOut(duration: 0.2), value: isDimmed)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(icon.title)
    }
}

struct CareIconCategory: Identifiable {
    let title: String
    let iconName: String
    let icons: [CareIconOption]

    var id: String { title }
}

struct CareIconOption: Identifiable, Hashable {
    let name: String
    let title: String

    var id: String { name }
}

struct CareIconImage: View {
    let name: String

    var body: some View {
        if UIImage(named: name) != nil {
            Image(name)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: name)
                .resizable()
                .scaledToFit()
                .foregroundStyle(CarePalette.primary)
                .padding(8)
        }
    }
}

struct CareItemRow: View {
    let item: CareItem
    let ownerName: String
    let ownerInitial: String
    let tint: Color
    let canEdit: Bool
    let onRetry: (() -> Void)?
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            CareIconImage(name: item.iconName)
                .frame(width: 54, height: 54)
                .background(tint.opacity(0.14))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(CarePalette.ink)
                        .lineLimit(1)
                        .strikethrough(item.isDoneToday, color: CarePalette.outline)

                    Text(ownerInitial)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(CarePalette.primary)
                        .frame(width: 20, height: 20)
                        .background(CarePalette.surfaceHigh)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(CarePalette.line.opacity(0.8), lineWidth: 1))
                        .accessibilityLabel(ownerName)
                }

                HStack(spacing: 10) {
                    if let reminderText = item.reminderText {
                        careMetaLabel("clock", reminderText)
                    }
                    careMetaLabel("repeat", item.repeatRule.rawValue)
                }

                if !item.note.isEmpty {
                    Text(item.note)
                        .font(.caption)
                        .foregroundStyle(CarePalette.muted)
                        .lineLimit(2)
                }

                if item.effectiveSyncState == .pending {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("iCloud에 저장 중")
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(CarePalette.outline)
                } else if item.effectiveSyncState == .failed, let onRetry {
                    Button(action: onRetry) {
                        Label("저장 실패 · 재시도", systemImage: "arrow.clockwise")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                } else if item.effectiveSyncState == .deleting {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("iCloud에서 삭제 중")
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(CarePalette.outline)
                } else if item.effectiveSyncState == .deleteFailed, let onRetry {
                    Button(action: onRetry) {
                        Label("삭제 실패 · 재시도", systemImage: "arrow.clockwise")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 8)

            Button(action: onToggle) {
                Image(systemName: "checkmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(item.isDoneToday ? .white : .clear)
                    .frame(width: 32, height: 32)
                    .background(item.isDoneToday ? CarePalette.primary : CarePalette.surfaceHigh)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(CarePalette.line.opacity(item.isDoneToday ? 0 : 0.75), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .disabled(!canEdit)
            .opacity(canEdit ? 1 : 0.65)
        }
        .padding(16)
        .background(item.isDoneToday ? CarePalette.surfaceHigh.opacity(0.58) : CarePalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(CarePalette.line.opacity(0.45), lineWidth: 1)
        }
        .opacity(item.isDoneToday ? 0.66 : 1)
    }

    private func careMetaLabel(_ systemImage: String, _ text: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption2.weight(.medium))
            .foregroundStyle(CarePalette.outline)
            .labelStyle(.titleAndIcon)
    }
}

private struct CarePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(CarePalette.primary.opacity(configuration.isPressed ? 0.82 : 1))
            .clipShape(Capsule())
    }
}

private extension View {
    func careInputShell() -> some View {
        self
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(CarePalette.surface)
            .clipShape(Capsule())
    }
}
