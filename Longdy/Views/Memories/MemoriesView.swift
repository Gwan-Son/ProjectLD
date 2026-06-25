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
        appState.memories
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
        let sortedPhotos = appState.memories
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
                appState.refreshCoupleData()
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
            .toolbar(.hidden, for: .navigationBar)
            .background(PhotoPalette.background.ignoresSafeArea())
            .overlay {
                if viewModel.isSaving {
                    PhotoSavingOverlay(message: "사진 업로드 중")
                }
            }
            .sheet(item: $selectedMemory) { memory in
                PhotoDetailView(memory: memory, ownerName: ownerName(for: memory))
            }
            .sheet(item: $editingMemory) { memory in
                PhotoEditorView(memory: memory, coupleId: appState.coupleId, viewModel: viewModel) { updatedMemory in
                    appState.applySavedMemory(updatedMemory)
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
                    TodayPhotoSlot(title: "나", memory: myTodayPhoto, width: slotWidth)
                        .onTapGesture {
                            if let myTodayPhoto { selectedMemory = myTodayPhoto }
                        }
                        .contextMenu {
                            if let myTodayPhoto, myTodayPhoto.userId == appState.userId {
                                memoryMenu(for: myTodayPhoto)
                            }
                        }
                    TodayPhotoSlot(title: appState.partner?.friendlyName ?? "상대", memory: partnerTodayPhoto, width: slotWidth)
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

                    Button {
                        editingMemory = myTodayPhoto
                    } label: {
                        Label("수정하기", systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PhotoPrimaryButtonStyle())
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
                    Task { await saveTodayPhoto() }
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
                        PhotoHistoryCell(memory: memory, ownerName: ownerName(for: memory))
                            .onTapGesture {
                                selectedMemory = memory
                            }
                            .contextMenu {
                                if memory.userId == appState.userId {
                                    memoryMenu(for: memory)
                                }
                            }
                        }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
            }
        }
    }

    private func saveTodayPhoto() async {
        if let memory = await viewModel.saveTodayPhoto(userId: appState.userId, coupleId: appState.coupleId, selectedPhotoData: selectedPhotoData) {
            selectedPhoto = nil
            selectedPhotoData = nil
            appState.applySavedMemory(memory)
            photoSaveAlertMessage = "오늘의 한 장을 업로드했어요."
            showingPhotoSaveAlert = true
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
        appState.removeMemory(memory)
        Task {
            let succeeded = await viewModel.deleteTodayPhoto(coupleId: appState.coupleId, memory: memory)
            if !succeeded {
                appState.applySavedMemory(memory)
            }
        }
        memoryPendingDelete = nil
    }
}

private struct TodayPhotoSlot: View {
    let title: String
    let memory: MemoryNote?
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(PhotoPalette.surface)
                if let memory {
                    MemoryImage(memory: memory)
                } else {
                    VStack(spacing: 8) {
                        Image("empty-state")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 72)
                        Text("아직 비어 있어요")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(PhotoPalette.muted)
                    }
                }
            }
            .frame(width: width, height: 170)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PhotoPalette.ink)
                .frame(width: width, alignment: .leading)
            if let text = memory?.text, !text.isEmpty {
                Text(text)
                    .font(.caption)
                    .foregroundStyle(PhotoPalette.muted)
                    .lineLimit(2)
                    .frame(width: width, alignment: .leading)
            }
        }
        .frame(width: width, alignment: .leading)
        .clipped()
    }
}

private struct PhotoHistoryCell: View {
    let memory: MemoryNote
    let ownerName: String

    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 8) {
                MemoryImage(memory: memory, contentMode: .fill)
                    .frame(width: proxy.size.width, height: 150)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(ownerName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PhotoPalette.ink)
                    .lineLimit(1)
                    .frame(width: proxy.size.width, alignment: .leading)
                Text(memory.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(PhotoPalette.muted)
                    .lineLimit(1)
                    .frame(width: proxy.size.width, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 195)
        .clipped()
    }
}

private struct MemoryImage: View {
    let memory: MemoryNote
    var contentMode: ContentMode = .fill

    var body: some View {
        if let urlString = memory.storageURL, let url = URL(string: urlString) {
            if url.isFileURL,
               let data = try? Data(contentsOf: url),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .id(url.absoluteString)
            } else {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                } placeholder: {
                    Rectangle().fill(PhotoPalette.line.opacity(0.35))
                }
                .id(url.absoluteString)
            }
        } else {
            Rectangle().fill(PhotoPalette.line.opacity(0.35))
        }
    }
}

@MainActor
private struct PhotoSelectionPreview: View {
    @Binding var data: Data?
    let height: CGFloat
    var fallbackMemory: MemoryNote?
    let placeholderTitle: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(PhotoPalette.surface)
                .frame(height: height)
            if let data, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else if let fallbackMemory {
                MemoryImage(memory: fallbackMemory, contentMode: .fill)
                    .frame(height: height)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 38))
                        .foregroundStyle(PhotoPalette.primary)
                    Text(placeholderTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PhotoPalette.ink)
                }
            }
        }
    }
}

@MainActor
private struct PhotoPickerPreviewButton: View {
    @Binding var selection: PhotosPickerItem?
    @Binding var data: Data?
    let height: CGFloat
    var fallbackMemory: MemoryNote?
    let placeholderTitle: String

    var body: some View {
        ZStack {
            PhotoSelectionPreview(
                data: $data,
                height: height,
                fallbackMemory: fallbackMemory,
                placeholderTitle: placeholderTitle
            )
            PhotosPicker(selection: $selection, matching: .images) {
                Color.clear
                    .frame(height: height)
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}

private struct PhotoDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let memory: MemoryNote
    let ownerName: String

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    detailImage
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 320)
                        .background(PhotoPalette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        Text(ownerName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PhotoPalette.secondary)
                        Text(memory.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(PhotoPalette.muted)
                        if !memory.text.isEmpty {
                            Text(memory.text)
                                .font(.body)
                                .foregroundStyle(PhotoPalette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PhotoPalette.surfaceContainerLow)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .padding(20)
            }
            .navigationTitle("오늘의 한 장")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
            .background(PhotoPalette.background.ignoresSafeArea())
        }
    }

    @ViewBuilder
    private var detailImage: some View {
        if let urlString = memory.storageURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFit()
            } placeholder: {
                ProgressView()
                    .tint(PhotoPalette.primary)
            }
        } else {
            Rectangle().fill(PhotoPalette.line.opacity(0.35))
        }
    }
}

@MainActor
private struct PhotoEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let memory: MemoryNote
    let coupleId: String?
    @ObservedObject var viewModel: MemoriesViewModel
    let onSave: (MemoryNote) -> Void

    @State private var caption: String
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedPhotoData: Data?

    init(memory: MemoryNote, coupleId: String?, viewModel: MemoriesViewModel, onSave: @escaping (MemoryNote) -> Void) {
        self.memory = memory
        self.coupleId = coupleId
        self.viewModel = viewModel
        self.onSave = onSave
        _caption = State(initialValue: memory.text)
    }

    @MainActor
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    PhotoPickerPreviewButton(
                        selection: $selectedPhoto,
                        data: $selectedPhotoData,
                        height: 260,
                        fallbackMemory: memory,
                        placeholderTitle: "사진 선택"
                    )

                    Text("사진을 누르면 새 사진으로 바꿀 수 있어요")
                        .font(.caption)
                        .foregroundStyle(PhotoPalette.muted)

                    TextField("짧은 한 줄", text: $caption, axis: .vertical)
                        .lineLimit(1...3)
                        .textFieldStyle(.plain)
                        .padding(14)
                        .background(PhotoPalette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Button {
                        Task { await save() }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("수정 저장", systemImage: "checkmark")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(PhotoPrimaryButtonStyle())
                    .disabled(viewModel.isSaving)

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(PhotoPalette.error)
                    }
                }
                .padding(20)
            }
            .navigationTitle("한 장 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                Task { @MainActor in
                    guard let data = try? await newValue?.loadTransferable(type: Data.self) else { return }
                    selectedPhotoData = viewModel.compressedJPEGData(from: data)
                }
            }
            .background(PhotoPalette.background.ignoresSafeArea())
        }
    }

    private func save() async {
        if let updatedMemory = await viewModel.updateTodayPhoto(
            coupleId: coupleId,
            memory: memory,
            caption: caption,
            selectedPhotoData: selectedPhotoData
        ) {
            onSave(updatedMemory)
            dismiss()
        }
    }
}

private struct PhotoSavingOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                    .tint(PhotoPalette.primary)
                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PhotoPalette.ink)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(PhotoPalette.surface.opacity(0.96))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: PhotoPalette.primary.opacity(0.16), radius: 16, y: 8)
        }
    }
}

private struct PhotoPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .background(PhotoPalette.primary.opacity(configuration.isPressed ? 0.78 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
