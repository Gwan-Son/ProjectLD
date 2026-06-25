import Combine
import Foundation
import SwiftUI
import UIKit

@MainActor
final class MemoriesViewModel: ObservableObject {
    @Published var caption = ""
    @Published var errorMessage: String?
    @Published var isSaving = false

    private let service = CloudKitService.shared

    func saveTodayPhoto(userId: String?, coupleId: String?, selectedPhotoData: Data?) async -> MemoryNote? {
        guard !isSaving else { return nil }
        isSaving = true
        defer { isSaving = false }

        do {
            errorMessage = nil
            guard let selectedPhotoData else { throw LongdyError.invalidInput("오늘 남길 사진을 선택해 주세요.") }
            guard let userId else { throw LongdyError.missingUser }
            guard let coupleId else { throw LongdyError.missingCouple }

            let cleanCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
            var memory = try await service.saveMemory(
                coupleId: coupleId,
                userId: userId,
                text: cleanCaption,
                fileData: selectedPhotoData,
                fileExtension: "jpg"
            )
            if let localURL = writeLocalPreview(data: selectedPhotoData, memoryId: memory.id) {
                memory.storageURL = localURL.absoluteString
            }

            caption = ""
            postDelayedRefresh()
            return memory
        } catch {
            errorMessage = error.longdyUserMessage
            return nil
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
            var updatedMemory = try await service.updateMemory(
                coupleId: coupleId,
                memoryId: memory.id,
                text: cleanCaption,
                fileData: selectedPhotoData,
                fileExtension: selectedPhotoData == nil ? nil : "jpg"
            )
            if let selectedPhotoData, let localURL = writeLocalPreview(data: selectedPhotoData, memoryId: memory.id) {
                updatedMemory.storageURL = localURL.absoluteString
            } else if selectedPhotoData == nil {
                updatedMemory.storageURL = memory.storageURL
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

    private func writeLocalPreview(data: Data, memoryId: String) -> URL? {
        do {
            let directory = try FileManager.default.url(
                for: .cachesDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            removeOldLocalPreviews(memoryId: memoryId, in: directory)
            let url = directory.appendingPathComponent("\(memoryId)-\(UUID().uuidString).jpg")
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private func removeOldLocalPreviews(memoryId: String, in directory: URL) {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return }

        urls
            .filter { $0.lastPathComponent.hasPrefix("\(memoryId)-") }
            .forEach { try? FileManager.default.removeItem(at: $0) }
    }

    private func postDelayedRefresh() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            NotificationCenter.default.post(name: .longdyShouldRefreshCoupleData, object: nil)
        }
    }
}
