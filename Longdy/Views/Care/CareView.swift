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
