import CloudKit
import Combine
import Foundation
import UIKit

@MainActor
final class MemoriesViewModel: ObservableObject {
    @Published var caption = ""
    @Published var errorMessage: String?
    @Published var isSaving = false
    @Published private(set) var memories: [MemoryNote] = []
    @Published private(set) var isLoadingPage = false
    @Published private(set) var hasMorePages = false

    private let service = CloudKitService.shared
    private var nextCursor: CKQueryOperation.Cursor?

    func seedMemories(_ values: [MemoryNote]) {
        guard memories.isEmpty else { return }
        memories = deduplicated(values)
    }

    func mergeRecentMemories(_ values: [MemoryNote]) {
        memories = deduplicated(values + memories)
    }

    func loadFirstPage(coupleId: String?) async {
        guard !isLoadingPage, let coupleId else { return }
        isLoadingPage = true
        defer { isLoadingPage = false }

        do {
            errorMessage = nil
            let page = try await service.fetchMemoryPage(coupleId: coupleId)
            let unsynced = memories.filter { $0.effectiveSyncState != .synced }
            memories = deduplicated(unsynced + page.memories)
            nextCursor = page.cursor
            hasMorePages = page.cursor != nil
        } catch {
            errorMessage = error.longdyUserMessage
        }
    }

    func loadNextPage(coupleId: String?) async {
        guard !isLoadingPage, let coupleId, let cursor = nextCursor else { return }
        isLoadingPage = true
        defer { isLoadingPage = false }

        do {
            errorMessage = nil
            let page = try await service.fetchMemoryPage(coupleId: coupleId, cursor: cursor)
            memories = deduplicated(memories + page.memories)
            nextCursor = page.cursor
            hasMorePages = page.cursor != nil
        } catch {
            errorMessage = error.longdyUserMessage
        }
    }

    func applySavedMemory(_ memory: MemoryNote) {
        memories.removeAll {
            $0.id == memory.id || ($0.userId == memory.userId && $0.dateKey == memory.dateKey)
        }
        memories.insert(memory, at: 0)
        memories.sort { $0.createdAt > $1.createdAt }
    }

    func removeMemory(_ memory: MemoryNote) {
        memories.removeAll { $0.id == memory.id }
    }

    func makePendingTodayPhoto(userId: String?, selectedPhotoData: Data?) -> MemoryNote? {
        do {
            errorMessage = nil
            guard let selectedPhotoData else { throw LongdyError.invalidInput("오늘 남길 사진을 선택해 주세요.") }
            guard let userId else { throw LongdyError.missingUser }
            let memoryId = "memory-\(UUID().uuidString)"
            let cleanCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let thumbnailData = thumbnailJPEGData(from: selectedPhotoData),
                  let originalURL = try writePendingAsset(
                    data: selectedPhotoData,
                    memoryId: memoryId,
                    kind: "original"
                  ),
                  let thumbnailURL = try writePendingAsset(
                    data: thumbnailData,
                    memoryId: memoryId,
                    kind: "thumbnail"
                  ) else {
                throw LongdyError.invalidInput("사진을 임시 저장하지 못했어요.")
            }
            let memory = MemoryNote(
                id: memoryId,
                userId: userId,
                text: cleanCaption,
                storageURL: originalURL.absoluteString,
                thumbnailURL: thumbnailURL.absoluteString,
                dateKey: DateKey.dateKey(),
                createdAt: Date(),
                syncState: .pending
            )
            caption = ""
            return memory
        } catch {
            errorMessage = error.longdyUserMessage
            return nil
        }
    }

    func persistPendingPhoto(coupleId: String?, memory: MemoryNote) async -> MemoryNote {
        guard !isSaving else { return memory }
        isSaving = true
        defer { isSaving = false }

        var result = memory
        result.syncState = .pending
        do {
            errorMessage = nil
            guard let coupleId else { throw LongdyError.missingCouple }
            guard let originalData = localData(from: memory.storageURL),
                  let thumbnailData = localData(from: memory.thumbnailURL) else {
                throw LongdyError.invalidInput("임시 저장된 사진을 찾지 못했어요. 사진을 다시 선택해 주세요.")
            }
            result = try await service.saveMemory(
                coupleId: coupleId,
                memoryId: memory.id,
                userId: memory.userId,
                text: memory.text,
                fileData: originalData,
                thumbnailData: thumbnailData,
                fileExtension: "jpg"
            )
            result.syncState = nil
            removePendingAssets(for: memory)
            postDelayedRefresh()
            return result
        } catch {
            result = memory
            result.syncState = .failed
            errorMessage = error.longdyUserMessage
            return result
        }
    }

    func updateTodayPhoto(coupleId: String?, memory: MemoryNote, caption: String, selectedPhotoData: Data?) async -> MemoryNote? {
        guard !isSaving else { return nil }
        isSaving = true
        defer { isSaving = false }

        do {
            errorMessage = nil
            guard let coupleId else { throw LongdyError.missingCouple }
            let cleanCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
            let thumbnailData = selectedPhotoData.flatMap(thumbnailJPEGData)
            var updatedMemory = try await service.updateMemory(
                coupleId: coupleId,
                memoryId: memory.id,
                text: cleanCaption,
                fileData: selectedPhotoData,
                thumbnailData: thumbnailData,
                fileExtension: selectedPhotoData == nil ? nil : "jpg"
            )
            if selectedPhotoData == nil {
                updatedMemory.storageURL = memory.storageURL
                updatedMemory.thumbnailURL = memory.thumbnailURL
            }
            postDelayedRefresh()
            return updatedMemory
        } catch {
            errorMessage = error.longdyUserMessage
            return nil
        }
    }

    func deleteTodayPhoto(coupleId: String?, memory: MemoryNote) async -> Bool {
        do {
            errorMessage = nil
            guard let coupleId else { throw LongdyError.missingCouple }
            try await service.deleteMemory(coupleId: coupleId, memoryId: memory.id)
            postDelayedRefresh()
            return true
        } catch {
            errorMessage = error.longdyUserMessage
            return false
        }
    }

    func compressedJPEGData(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return data }
        let maxLength: CGFloat = 1600
        let size = image.size
        let scale = min(1, maxLength / max(size.width, size.height))
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resizedImage.jpegData(compressionQuality: 0.78)
    }

    private func thumbnailJPEGData(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let maxLength: CGFloat = 320
        let scale = min(1, maxLength / max(image.size.width, image.size.height))
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }.jpegData(compressionQuality: 0.68)
    }

    private func writePendingAsset(data: Data, memoryId: String, kind: String) throws -> URL? {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("PendingMemoryUploads", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(memoryId)-\(kind).jpg")
        try data.write(to: url, options: .atomic)
        return url
    }

    private func localData(from urlString: String?) -> Data? {
        guard let urlString, let url = URL(string: urlString), url.isFileURL else { return nil }
        return try? Data(contentsOf: url)
    }

    private func removePendingAssets(for memory: MemoryNote) {
        [memory.storageURL, memory.thumbnailURL]
            .compactMap { $0 }
            .compactMap(URL.init(string:))
            .filter { $0.path.contains("/PendingMemoryUploads/") }
            .forEach { try? FileManager.default.removeItem(at: $0) }
    }

    private func deduplicated(_ values: [MemoryNote]) -> [MemoryNote] {
        var seen: Set<String> = []
        return values
            .sorted { $0.createdAt > $1.createdAt }
            .filter { seen.insert($0.id).inserted }
    }

    private func postDelayedRefresh() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            NotificationCenter.default.post(name: .longdyShouldRefreshCoupleData, object: nil)
        }
    }
}

@MainActor
final class MemoryDetailViewModel: ObservableObject {
    @Published private(set) var memory: MemoryNote
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let service = CloudKitService.shared

    init(memory: MemoryNote) {
        self.memory = memory
    }

    func loadOriginal(coupleId: String?) async {
        guard memory.storageURL == nil, !isLoading, let coupleId else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            errorMessage = nil
            memory = try await service.fetchMemoryDetail(coupleId: coupleId, memoryId: memory.id)
        } catch {
            errorMessage = error.longdyUserMessage
        }
    }
}
