import PhotosUI
import SwiftUI
import UIKit

@MainActor
struct MemoriesView: View {
    @EnvironmentObject private var appState: AppViewModel
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = MemoriesViewModel()
    @State private var selectedMemory: MemoryNote?
    @State private var editingMemory: MemoryNote?
    @State private var memoryPendingDelete: MemoryNote?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var showingPhotoSaveAlert = false
    @State private var photoSaveAlertMessage = ""

    private var todayPhotos: [MemoryNote] {
        viewModel.memories
            .filter { $0.dateKey == appState.todayDateKey }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var myTodayPhoto: MemoryNote? {
        guard let userId = appState.userId else { return nil }
        return todayPhotos.first { $0.userId == userId }
    }

    private var partnerTodayPhoto: MemoryNote? {
        guard let partnerId = appState.partner?.id else { return nil }
        return todayPhotos.first { $0.userId == partnerId }
    }

    private var photoHistory: [MemoryNote] {
        let sortedPhotos = viewModel.memories
            .sorted { $0.createdAt > $1.createdAt }
        var seenKeys: Set<String> = []
        return sortedPhotos.filter { memory in
            let key = "\(memory.userId)-\(memory.dateKey)"
            return seenKeys.insert(key).inserted
        }
    }

    @MainActor
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    photoHero
                    todaySection
                    addPhotoCard
                    historySection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
            .navigationTitle("오늘의 한 장")
            .onAppear {
                viewModel.seedMemories(appState.memories)
                appState.refreshCoupleData()
            }
            .task(id: appState.coupleId) {
                await viewModel.loadFirstPage(coupleId: appState.coupleId)
            }
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(60))
                    if !Task.isCancelled {
                        appState.refreshCoupleData()
                    }
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    appState.refreshCoupleData()
                }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                Task { @MainActor in
                    await loadSelectedPhoto(newValue)
                }
            }
            .onChange(of: appState.memories) { _, memories in
                viewModel.mergeRecentMemories(memories)
            }
            .toolbar(.hidden, for: .navigationBar)
            .background(PhotoPalette.background.ignoresSafeArea())
            .sheet(item: $selectedMemory) { memory in
                PhotoDetailView(
                    memory: memory,
                    ownerName: ownerName(for: memory),
                    coupleId: appState.coupleId
                )
            }
            .sheet(item: $editingMemory) { memory in
                PhotoEditorView(memory: memory, coupleId: appState.coupleId, viewModel: viewModel) { updatedMemory in
                    appState.applySavedMemory(updatedMemory)
                    viewModel.applySavedMemory(updatedMemory)
                    photoSaveAlertMessage = "오늘의 한 장을 수정했어요."
                    showingPhotoSaveAlert = true
                }
            }
            .alert("오늘의 한 장을 삭제할까요?", isPresented: deleteConfirmationBinding) {
                Button("취소", role: .cancel) {
                    memoryPendingDelete = nil
                }
                Button("삭제", role: .destructive) {
                    deletePendingMemory()
                }
            } message: {
                Text("삭제하면 상대 화면에서도 사라져요.")
            }
            .alert("업로드 완료", isPresented: $showingPhotoSaveAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(photoSaveAlertMessage)
            }
        }
    }

    private var photoHero: some View {
        BridgeScreenHeader(
            currentUser: appState.currentProfile,
            partner: appState.partner,
            eyebrow: "오늘 서로에게 보내는 장면",
            title: "오늘의 한 장",
            summary: photoSummary,
            primaryColor: PhotoPalette.primary,
            secondaryColor: PhotoPalette.secondary,
            inkColor: PhotoPalette.ink
        )
    }

    private var photoSummary: String {
        switch (myTodayPhoto != nil, partnerTodayPhoto != nil) {
        case (true, true): "오늘의 장면이 서로에게 닿았어요"
        case (true, false): "내 한 장이 먼저 도착했어요"
        case (false, true): "상대의 한 장이 도착했어요"
        case (false, false): "하루에 한 장만 조용히 남겨요"
        }
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("오늘 도착한 장면")
                .font(.headline)
                .foregroundStyle(PhotoPalette.ink)

            GeometryReader { proxy in
                let spacing: CGFloat = 12
                let slotWidth = max((proxy.size.width - spacing) / 2, 0)
                HStack(spacing: spacing) {
                    TodayPhotoSlot(
                        title: "나",
                        memory: myTodayPhoto,
                        width: slotWidth,
                        onRetry: myTodayPhoto.flatMap(photoRetryAction)
                    )
                        .onTapGesture {
                            if let myTodayPhoto, canOpenPhoto(myTodayPhoto) {
                                selectedMemory = myTodayPhoto
                            }
                        }
                        .contextMenu {
                            if let myTodayPhoto,
                               myTodayPhoto.userId == appState.userId,
                               myTodayPhoto.effectiveSyncState == .synced {
                                memoryMenu(for: myTodayPhoto)
                            }
                        }
                    TodayPhotoSlot(
                        title: appState.partner?.friendlyName ?? "상대",
                        memory: partnerTodayPhoto,
                        width: slotWidth,
                        onRetry: nil
                    )
                        .onTapGesture {
                            if let partnerTodayPhoto { selectedMemory = partnerTodayPhoto }
                        }
                }
            }
            .frame(height: 225)
        }
    }

    @MainActor
    private var addPhotoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(myTodayPhoto == nil ? "오늘 남기기" : "오늘의 사진을 남겼어요.")
                .font(.headline)
                .foregroundStyle(PhotoPalette.ink)

            if let myTodayPhoto {
                VStack(alignment: .leading, spacing: 12) {
                    Text(myTodayPhoto.text.isEmpty ? "오늘의 장면이 조용히 도착했어요." : myTodayPhoto.text)
                        .font(.subheadline)
                        .foregroundStyle(PhotoPalette.muted)
                        .lineLimit(2)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(PhotoPalette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    if myTodayPhoto.effectiveSyncState == .synced {
                        Button {
                            editingMemory = myTodayPhoto
                        } label: {
                            Label("수정하기", systemImage: "pencil")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PhotoPrimaryButtonStyle())
                    } else if myTodayPhoto.effectiveSyncState == .failed {
                        Button {
                            retryPhoto(myTodayPhoto)
                        } label: {
                            Label("업로드 다시 시도", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PhotoPrimaryButtonStyle())
                    } else if myTodayPhoto.effectiveSyncState == .deleteFailed {
                        Button {
                            deletePhoto(myTodayPhoto)
                        } label: {
                            Label("삭제 다시 시도", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PhotoPrimaryButtonStyle())
                    } else {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text(myTodayPhoto.effectiveSyncState == .deleting ? "iCloud에서 삭제 중" : "iCloud에 업로드 중")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(PhotoPalette.muted)
                        Text("사진은 먼저 화면에 표시되고, iCloud 저장은 뒤에서 계속 진행돼요.")
                            .font(.caption)
                            .foregroundStyle(PhotoPalette.muted)
                    }
                }
            } else {
                PhotoPickerPreviewButton(
                    selection: $selectedPhoto,
                    data: $selectedPhotoData,
                    height: 210,
                    placeholderTitle: "사진 선택"
                )
                TextField("짧은 한 줄", text: $viewModel.caption, axis: .vertical)
                    .lineLimit(1...3)
                    .textFieldStyle(.plain)
                    .padding(14)
                    .background(PhotoPalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Button {
                    saveTodayPhoto()
                } label: {
                    if viewModel.isSaving {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("오늘의 한 장 저장", systemImage: "paperplane.fill")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(PhotoPrimaryButtonStyle())
                .disabled(viewModel.isSaving)
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(PhotoPalette.error)
            }
        }
        .padding(16)
        .background(PhotoPalette.surfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(PhotoPalette.line.opacity(0.6), lineWidth: 1)
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("지난 한 장들")
                .font(.headline)
                .foregroundStyle(PhotoPalette.ink)

            if photoHistory.isEmpty {
                EmptyStateView(
                    title: "아직 사진이 없어요",
                    message: "오늘의 한 장을 남기면 둘의 하루가 차곡히 쌓여요.",
                    systemImage: "photo.on.rectangle"
                )
                .background(PhotoPalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(photoHistory) { memory in
                        PhotoHistoryCell(
                            memory: memory,
                            ownerName: ownerName(for: memory),
                            onRetry: memory.userId == appState.userId ? photoRetryAction(for: memory) : nil
                        )
                            .onTapGesture {
                                if canOpenPhoto(memory) {
                                    selectedMemory = memory
                                }
                            }
                            .contextMenu {
                                if memory.userId == appState.userId && memory.effectiveSyncState == .synced {
                                    memoryMenu(for: memory)
                                }
                            }
                        }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)

                if viewModel.hasMorePages {
                    Button {
                        Task { await viewModel.loadNextPage(coupleId: appState.coupleId) }
                    } label: {
                        if viewModel.isLoadingPage {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("더 불러오기", systemImage: "chevron.down")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(PhotoPrimaryButtonStyle())
                    .disabled(viewModel.isLoadingPage)
                    .padding(.horizontal, 12)
                }
            }
        }
    }

    private func saveTodayPhoto() {
        guard let memory = viewModel.makePendingTodayPhoto(
            userId: appState.userId,
            selectedPhotoData: selectedPhotoData
        ) else { return }
        selectedPhoto = nil
        selectedPhotoData = nil
        appState.applySavedMemory(memory)
        viewModel.applySavedMemory(memory)
        uploadPhoto(memory)
    }

    private func retryPhoto(_ memory: MemoryNote) {
        var pendingMemory = memory
        pendingMemory.syncState = .pending
        appState.applySavedMemory(pendingMemory)
        viewModel.applySavedMemory(pendingMemory)
        uploadPhoto(pendingMemory)
    }

    private func uploadPhoto(_ memory: MemoryNote) {
        Task {
            let savedMemory = await viewModel.persistPendingPhoto(
                coupleId: appState.coupleId,
                memory: memory
            )
            appState.applySavedMemory(savedMemory)
            viewModel.applySavedMemory(savedMemory)
            if savedMemory.effectiveSyncState == .synced {
                photoSaveAlertMessage = "오늘의 한 장을 업로드했어요."
                showingPhotoSaveAlert = true
            } else if savedMemory.effectiveSyncState == .failed {
                appState.errorMessage = viewModel.errorMessage ?? "오늘의 한 장을 저장하지 못했어요. 다시 시도해 주세요."
            }
        }
    }

    private func photoRetryAction(for memory: MemoryNote) -> (() -> Void)? {
        switch memory.effectiveSyncState {
        case .failed:
            return { retryPhoto(memory) }
        case .deleteFailed:
            return { deletePhoto(memory) }
        default:
            return nil
        }
    }

    private func loadSelectedPhoto(_ item: PhotosPickerItem?) async {
        do {
            guard let data = try await item?.loadTransferable(type: Data.self) else { return }
            selectedPhotoData = viewModel.compressedJPEGData(from: data)
        } catch {
            viewModel.errorMessage = "사진을 불러오지 못했어요."
        }
    }

    private func ownerName(for memory: MemoryNote) -> String {
        if memory.userId == appState.userId { return "나" }
        return appState.partner?.friendlyName ?? "상대"
    }

    private func canOpenPhoto(_ memory: MemoryNote) -> Bool {
        memory.effectiveSyncState == .synced || memory.storageURL != nil
    }

    @ViewBuilder
    private func memoryMenu(for memory: MemoryNote) -> some View {
        Button {
            editingMemory = memory
        } label: {
            Label("수정", systemImage: "pencil")
        }
        Button(role: .destructive) {
            memoryPendingDelete = memory
        } label: {
            Label("삭제", systemImage: "trash")
        }
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { memoryPendingDelete != nil },
            set: { isPresented in
                if !isPresented { memoryPendingDelete = nil }
            }
        )
    }

    private func deletePendingMemory() {
        guard let memory = memoryPendingDelete else { return }
        deletePhoto(memory)
        memoryPendingDelete = nil
    }

    private func deletePhoto(_ memory: MemoryNote) {
        var deletingMemory = memory
        deletingMemory.syncState = .deleting
        appState.applySavedMemory(deletingMemory)
        viewModel.applySavedMemory(deletingMemory)
        Task {
            let succeeded = await viewModel.deleteTodayPhoto(coupleId: appState.coupleId, memory: memory)
            if succeeded {
                appState.removeMemory(memory)
                viewModel.removeMemory(memory)
            } else {
                var failedMemory = memory
                failedMemory.syncState = .deleteFailed
                appState.applySavedMemory(failedMemory)
                viewModel.applySavedMemory(failedMemory)
                appState.errorMessage = viewModel.errorMessage ?? "오늘의 한 장을 삭제하지 못했어요. 다시 시도해 주세요."
            }
        }
    }
}
