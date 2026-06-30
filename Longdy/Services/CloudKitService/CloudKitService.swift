import CloudKit
import Foundation

actor CloudKitService {
    static let shared = CloudKitService()

    enum RecordType {
        static let userProfile = "UserProfile"
        static let coupleRoot = "CoupleRoot"
        static let inviteCode = "InviteCode"
        static let checkIn = "CheckIn"
        static let coupleEvent = "CoupleEvent"
        static let careItem = "CareItem"
        static let memoryNote = "MemoryNote"
        static let bridgeActivity = "BridgeActivity"
    }

    enum UserProfileField {
        static let appleUserId = "appleUserId"
        static let email = "email"
        static let displayName = "displayName"
        static let nickname = "nickname"
        static let cityName = "cityName"
        static let timezoneId = "timezoneId"
        static let latitude = "latitude"
        static let longitude = "longitude"
        static let locationUpdatedAt = "locationUpdatedAt"
        static let profilePhotoAsset = "profilePhotoAsset"
        static let coupleRootRecordName = "coupleRootRecordName"
        static let createdAt = "createdAt"
        static let updatedAt = "updatedAt"
    }

    enum CoupleRootField {
        static let ownerAppleUserId = "ownerAppleUserId"
        static let partnerAppleUserId = "partnerAppleUserId"
        static let inviteCode = "inviteCode"
        static let ownerDisplayName = "ownerDisplayName"
        static let ownerNickname = "ownerNickname"
        static let ownerCityName = "ownerCityName"
        static let ownerTimezoneId = "ownerTimezoneId"
        static let ownerLatitude = "ownerLatitude"
        static let ownerLongitude = "ownerLongitude"
        static let ownerLocationUpdatedAt = "ownerLocationUpdatedAt"
        static let ownerProfilePhotoAsset = "ownerProfilePhotoAsset"
        static let partnerDisplayName = "partnerDisplayName"
        static let partnerNickname = "partnerNickname"
        static let partnerCityName = "partnerCityName"
        static let partnerTimezoneId = "partnerTimezoneId"
        static let partnerLatitude = "partnerLatitude"
        static let partnerLongitude = "partnerLongitude"
        static let partnerLocationUpdatedAt = "partnerLocationUpdatedAt"
        static let partnerProfilePhotoAsset = "partnerProfilePhotoAsset"
        static let nextMeetDate = "nextMeetDate"
        static let anniversaryDate = "anniversaryDate"
        static let createdAt = "createdAt"
        static let updatedAt = "updatedAt"
    }

    enum SharedField {
        static let coupleRootRecordName = "coupleRootRecordName"
        static let appleUserId = "appleUserId"
        static let createdAt = "createdAt"
        static let updatedAt = "updatedAt"
    }

    enum MemoryField {
        static let type = "type"
        static let text = "text"
        static let dateKey = "dateKey"
        static let asset = "asset"
        static let thumbnailAsset = "thumbnailAsset"
    }

    enum InviteCodeField {
        static let code = "code"
        static let ownerAppleUserId = "ownerAppleUserId"
        static let shareURL = "shareURL"
        static let expiresAt = "expiresAt"
        static let usedAt = "usedAt"
        static let usedByAppleUserId = "usedByAppleUserId"
        static let createdAt = "createdAt"
    }

    enum MemberSnapshotPrefix {
        case owner
        case partner
    }

    let container: CKContainer

    init(container: CKContainer = .default()) {
        self.container = container
    }

    var privateDatabase: CKDatabase {
        container.privateCloudDatabase
    }

    var sharedDatabase: CKDatabase {
        container.sharedCloudDatabase
    }

    var publicDatabase: CKDatabase {
        container.publicCloudDatabase
    }

    nonisolated var sharingContainer: CKContainer {
        container
    }

    func fetchAccountStatus() async throws -> CKAccountStatus {
        try await withCheckedThrowingContinuation { continuation in
            container.accountStatus { status, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: status)
                }
            }
        }
    }
}

extension Error {
    var longdyUserMessage: String {
        if let longdyError = self as? LongdyError {
            return longdyError.localizedDescription
        }

        guard let cloudKitError = self as? CKError else {
            return localizedDescription
        }

        switch cloudKitError.code {
        case .notAuthenticated:
            return "iCloud 로그인이 필요해요. 설정 앱에서 iCloud 계정을 확인해 주세요."
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited:
            return "iCloud 연결이 원활하지 않아요. 잠시 후 다시 시도해 주세요."
        case .permissionFailure:
            return "iCloud 공유 권한을 확인하지 못했어요. 커플 연결 상태를 확인한 뒤 다시 시도해 주세요."
        case .quotaExceeded:
            return "iCloud 저장 공간이 부족해요. iCloud 용량을 확인해 주세요."
        case .zoneNotFound, .userDeletedZone:
            return "커플 공간을 찾을 수 없어요. 앱을 다시 실행하거나 다시 연결해 주세요."
        case .unknownItem:
            return "iCloud 데이터를 아직 찾지 못했어요. 잠시 후 다시 동기화해 주세요."
        case .serverRecordChanged:
            return "같은 데이터가 다른 기기에서 먼저 바뀌었어요. 새로고침 후 다시 시도해 주세요."
        default:
            return cloudKitError.localizedDescription
        }
    }
}
