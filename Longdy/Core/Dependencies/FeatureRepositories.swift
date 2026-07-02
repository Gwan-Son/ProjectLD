import CloudKit
import Foundation

protocol AuthProfileRepository: Sendable {
    func upsertUserProfile(
        session: AppleSession,
        nickname: String?,
        cityName: String,
        timezoneId: String
    ) async throws -> LongdyUser
}

extension AuthProfileRepository {
    func upsertUserProfile(session: AppleSession, nickname: String?) async throws -> LongdyUser {
        try await upsertUserProfile(
            session: session,
            nickname: nickname,
            cityName: "Seoul",
            timezoneId: TimeZone.current.identifier
        )
    }
}

protocol CoupleRepository: Sendable {
    func createCoupleRootShare(session: AppleSession) async throws -> (couple: Couple, share: CKShare)
    func regenerateCoupleRootShare(
        session: AppleSession,
        currentCoupleId: String?
    ) async throws -> (couple: Couple, share: CKShare)
    func joinCouple(
        inviteCode: String,
        session: AppleSession,
        currentCoupleId: String?
    ) async throws -> Couple
}

protocol CheckInRepository: Sendable {
    func saveCheckIn(
        coupleId: String,
        userId: String,
        mood: Mood,
        status: LongdyStatus,
        expiresAt: Date?
    ) async throws -> CheckIn
}

protocol CalendarRepository: Sendable {
    func saveEvent(
        coupleId: String,
        ownerUserId: String,
        title: String,
        startAt: Date,
        endAt: Date,
        type: EventType,
        memo: String
    ) async throws -> CoupleEvent
    func updateEvent(
        coupleId: String,
        eventId: String,
        title: String,
        startAt: Date,
        endAt: Date,
        type: EventType,
        memo: String
    ) async throws -> CoupleEvent
    func deleteEvent(coupleId: String, eventId: String) async throws
}

protocol CareRepository: Sendable {
    func saveCareItem(
        coupleId: String,
        itemId: String,
        dateKey: String,
        userId: String,
        title: String,
        iconName: String,
        repeatRule: CareRepeatRule,
        reminderHour: Int?,
        reminderMinute: Int?,
        note: String
    ) async throws -> String
    func updateCareItem(
        coupleId: String,
        itemId: String,
        dateKey: String,
        isDone: Bool
    ) async throws
    func updateCareItemDetails(
        coupleId: String,
        itemId: String,
        title: String,
        iconName: String,
        repeatRule: CareRepeatRule,
        reminderHour: Int?,
        reminderMinute: Int?,
        note: String
    ) async throws
    func deleteCareItem(coupleId: String, itemId: String) async throws
}

protocol MemoryRepository: Sendable {
    func fetchMemoryPage(
        coupleId: String,
        cursor: CKQueryOperation.Cursor?,
        limit: Int
    ) async throws -> MemoryPage
    func saveMemory(
        coupleId: String,
        memoryId: String,
        userId: String,
        text: String,
        fileData: Data?,
        thumbnailData: Data?,
        fileExtension: String?
    ) async throws -> MemoryNote
    func updateMemory(
        coupleId: String,
        memoryId: String,
        text: String,
        fileData: Data?,
        thumbnailData: Data?,
        fileExtension: String?
    ) async throws -> MemoryNote
    func deleteMemory(coupleId: String, memoryId: String) async throws
    func fetchMemoryDetail(coupleId: String, memoryId: String) async throws -> MemoryNote
}

extension MemoryRepository {
    func fetchMemoryPage(coupleId: String) async throws -> MemoryPage {
        try await fetchMemoryPage(coupleId: coupleId, cursor: nil, limit: 20)
    }

    func fetchMemoryPage(
        coupleId: String,
        cursor: CKQueryOperation.Cursor?
    ) async throws -> MemoryPage {
        try await fetchMemoryPage(coupleId: coupleId, cursor: cursor, limit: 20)
    }
}

protocol ProfilePhotoRepository: Sendable {
    func updateUserProfilePhoto(session: AppleSession, fileData: Data?) async throws -> LongdyUser
}

protocol AppDataRepository: AuthProfileRepository {
    func fetchCurrentUserProfile(session: AppleSession) async throws -> LongdyUser?
    func fetchCoupleRoot(recordName: String) async throws -> Couple?
    func fetchShareMetadata(from url: URL) async throws -> CKShare.Metadata
    func acceptShare(
        metadata: CKShare.Metadata,
        session: AppleSession,
        replacingCurrentCoupleId: String?
    ) async throws -> Couple
    func canReplaceWithIncomingShare(currentCoupleId: String, session: AppleSession) async throws -> Bool
    func disconnectCouple(coupleId: String, session: AppleSession) async throws -> CoupleDisconnectResult
    func deleteCoupleSpace(coupleId: String, session: AppleSession) async throws -> LongdyUser
    func clearUserCoupleRoot(session: AppleSession) async throws
    func resetUserProfileAfterCoupleDeletion(session: AppleSession) async throws -> LongdyUser
    func repairUserCoupleReference(session: AppleSession, coupleId: String) async throws
    func ensureChangeSubscriptions() async throws
    func fetchCoupleData(coupleId: String) async throws -> (
        checkIns: [CheckIn],
        events: [CoupleEvent],
        careItems: [CareItem],
        memories: [MemoryNote]
    )
    func fetchHomeData(coupleId: String) async throws -> (
        checkIns: [CheckIn],
        events: [CoupleEvent],
        careItems: [CareItem]
    )
    func fetchBridgeActivities(
        coupleId: String,
        userIds: [String],
        dateKey: String
    ) async throws -> [BridgeActivity]
    func saveCalendarViewedActivity(
        coupleId: String,
        userId: String,
        dateKey: String
    ) async throws -> BridgeActivity
    func updateUserLocation(
        session: AppleSession,
        latitude: Double,
        longitude: Double,
        timezoneId: String
    ) async throws -> LongdyUser
    func updateUserProfile(
        session: AppleSession,
        nickname: String?,
        cityName: String?,
        timezoneId: String?
    ) async throws -> LongdyUser
}

extension AppDataRepository {
    func updateUserProfile(session: AppleSession, nickname: String) async throws -> LongdyUser {
        try await updateUserProfile(
            session: session,
            nickname: nickname,
            cityName: nil,
            timezoneId: nil
        )
    }

    func updateUserProfile(
        session: AppleSession,
        cityName: String,
        timezoneId: String
    ) async throws -> LongdyUser {
        try await updateUserProfile(
            session: session,
            nickname: nil,
            cityName: cityName,
            timezoneId: timezoneId
        )
    }
}

extension CloudKitService: AuthProfileRepository,
    CoupleRepository,
    CheckInRepository,
    CalendarRepository,
    CareRepository,
    MemoryRepository,
    ProfilePhotoRepository,
    AppDataRepository {}

struct DependencyContainer {
    nonisolated static let live = DependencyContainer(cloudKitService: .shared)

    let authProfileRepository: any AuthProfileRepository
    let coupleRepository: any CoupleRepository
    let checkInRepository: any CheckInRepository
    let calendarRepository: any CalendarRepository
    let careRepository: any CareRepository
    let memoryRepository: any MemoryRepository
    let profilePhotoRepository: any ProfilePhotoRepository
    let appDataRepository: any AppDataRepository

    nonisolated init(cloudKitService: CloudKitService) {
        authProfileRepository = cloudKitService
        coupleRepository = cloudKitService
        checkInRepository = cloudKitService
        calendarRepository = cloudKitService
        careRepository = cloudKitService
        memoryRepository = cloudKitService
        profilePhotoRepository = cloudKitService
        appDataRepository = cloudKitService
    }
}
