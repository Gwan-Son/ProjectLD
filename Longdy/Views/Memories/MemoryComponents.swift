import PhotosUI
import SwiftUI
import UIKit

struct TodayPhotoSlot: View {
    let title: String
    let memory: MemoryNote?
    let width: CGFloat
    let onRetry: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(PhotoPalette.surface)
                if let memory {
                    MemoryImage(memory: memory)
                    PhotoSyncStatusOverlay(memory: memory, onRetry: onRetry)
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

struct PhotoHistoryCell: View {
    let memory: MemoryNote
    let ownerName: String
    let onRetry: (() -> Void)?

    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    MemoryImage(memory: memory, contentMode: .fill)
                    PhotoSyncStatusOverlay(memory: memory, onRetry: onRetry)
                }
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

struct PhotoSyncStatusOverlay: View {
    let memory: MemoryNote
    let onRetry: (() -> Void)?

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                if memory.effectiveSyncState == .pending {
                    Label {
                        Text("업로드 중")
                    } icon: {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(.white)
                    }
                    .syncBadgeStyle()
                } else if memory.effectiveSyncState == .failed, let onRetry {
                    Button(action: onRetry) {
                        Label("재시도", systemImage: "arrow.clockwise")
                            .syncBadgeStyle()
                    }
                    .buttonStyle(.plain)
                } else if memory.effectiveSyncState == .deleting {
                    Label {
                        Text("삭제 중")
                    } icon: {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(.white)
                    }
                    .syncBadgeStyle()
                } else if memory.effectiveSyncState == .deleteFailed, let onRetry {
                    Button(action: onRetry) {
                        Label("삭제 재시도", systemImage: "arrow.clockwise")
                            .syncBadgeStyle()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
        }
    }
}

struct MemoryImage: View {
    let memory: MemoryNote
    var contentMode: ContentMode = .fill

    var body: some View {
        if let urlString = memory.thumbnailURL, let url = URL(string: urlString) {
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
struct PhotoSelectionPreview: View {
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
struct PhotoPickerPreviewButton: View {
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

struct PhotoDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let ownerName: String
    let coupleId: String?
    @StateObject private var viewModel: MemoryDetailViewModel

    init(memory: MemoryNote, ownerName: String, coupleId: String?) {
        self.ownerName = ownerName
        self.coupleId = coupleId
        _viewModel = StateObject(wrappedValue: MemoryDetailViewModel(memory: memory))
    }

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
                        Text(viewModel.memory.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(PhotoPalette.muted)
                        if !viewModel.memory.text.isEmpty {
                            Text(viewModel.memory.text)
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
            .task {
                await viewModel.loadOriginal(coupleId: coupleId)
            }
        }
    }

    @ViewBuilder
    private var detailImage: some View {
        if let urlString = viewModel.memory.storageURL,
           let url = URL(string: urlString) {
            if url.isFileURL,
               let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFit()
                } placeholder: {
                    ProgressView()
                        .tint(PhotoPalette.primary)
                }
            }
        } else if viewModel.isLoading {
            ProgressView()
                .tint(PhotoPalette.primary)
        } else if let error = viewModel.errorMessage {
            ContentUnavailableView("사진을 불러오지 못했어요", systemImage: "photo", description: Text(error))
        } else {
            Rectangle().fill(PhotoPalette.line.opacity(0.35))
        }
    }
}

@MainActor
struct PhotoEditorView: View {
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

struct PhotoPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .background(PhotoPalette.primary.opacity(configuration.isPressed ? 0.78 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

extension View {
    func syncBadgeStyle() -> some View {
        self
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(.black.opacity(0.58))
            .clipShape(Capsule())
    }
}

