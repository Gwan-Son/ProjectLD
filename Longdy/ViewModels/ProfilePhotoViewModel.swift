import Combine
import Foundation
import UIKit

@MainActor
final class ProfilePhotoViewModel: ObservableObject {
    @Published var isSaving = false
    @Published var errorMessage: String?

    private let service = CloudKitService.shared

    func save(session: AppleSession?, photoData: Data) async -> LongdyUser? {
        guard !isSaving else { return nil }
        isSaving = true
        defer { isSaving = false }

        do {
            errorMessage = nil
            guard let session else { throw LongdyError.missingUser }
            guard let compressedData = squareJPEGData(from: photoData) else {
                throw LongdyError.invalidInput("사진을 불러오지 못했어요.")
            }
            return try await service.updateUserProfilePhoto(session: session, fileData: compressedData)
        } catch {
            errorMessage = error.longdyUserMessage
            return nil
        }
    }

    func remove(session: AppleSession?) async -> LongdyUser? {
        guard !isSaving else { return nil }
        isSaving = true
        defer { isSaving = false }

        do {
            errorMessage = nil
            guard let session else { throw LongdyError.missingUser }
            return try await service.updateUserProfilePhoto(session: session, fileData: nil)
        } catch {
            errorMessage = error.longdyUserMessage
            return nil
        }
    }

    private func squareJPEGData(from data: Data) -> Data? {
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else { return nil }
        let targetSide: CGFloat = 512
        let scale = max(targetSide / image.size.width, targetSide / image.size.height)
        let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let drawOrigin = CGPoint(
            x: (targetSide - drawSize.width) / 2,
            y: (targetSide - drawSize.height) / 2
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: targetSide, height: targetSide),
            format: format
        )
        let resized = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: targetSide, height: targetSide))
            image.draw(in: CGRect(origin: drawOrigin, size: drawSize))
        }
        return resized.jpegData(compressionQuality: 0.82)
    }
}
