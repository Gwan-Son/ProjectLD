import Combine
import Foundation
import UserNotifications

@MainActor
final class AppViewModel: ObservableObject {
    @Published var isLoadingSession = true
    @Published var isLoadingCoupleData = false
    @Published var appleSession = AppleSessionStore.shared.currentSession
    @Published var currentProfile: LongdyUser?
    @Published var couple: Couple?
    @Published var members: [LongdyUser] = []
    @Published var checkIns: [CheckIn] = []
    @Published var events: [CoupleEvent] = []
    @Published var careItems: [CareItem] = []
    @Published var memories: [MemoryNote] = []
    @Published var bridgeActivities: [BridgeActivity] = []
    @Published var homeCardOrder = HomeCardKind.allCases
    @Published var selectedMainTab: MainTab = .home
    @Published var weatherByUserId: [String: WeatherSummary] = [:]
    @Published var weatherErrorMessage: String?
    @Published var errorMessage: String?
    @Published var showReplaceInviteConfirmation = false
    @Published var isDisconnectingCouple = false
    @Published var isDeletingCoupleSpace = false
    @Published var isDeletingAccount = false
    @Published var accountDeletionErrorMessage: String?
    @Published var isSavingProfile = false
    @Published var isRefreshingLocationWeather = false

    private let appleSessionStore = AppleSessionStore.shared
    let cloudKitService: any AppDataRepository
    let weatherService = WeatherService.shared
    let partnerNotificationService = PartnerNotificationService.shared
    let locationService = LocationService()
    var hasRequestedCurrentLocation = false
    var hasLoadedCoupleData = false
    private var isAcceptingPendingShare = false
    var isRefreshingCoupleData = false
    var lastCoupleDataRefreshAt: Date?
    let minimumCoupleDataRefreshInterval: TimeInterval = 5
    var recentlyCommittedCareItemIDs: [String: Date] = [:]
    var recentlyCommittedMemoryIDs: [String: Date] = [:]
    let cloudKitReconciliationGrace: TimeInterval = 30

    init(cloudKitService: any AppDataRepository = DependencyContainer.live.appDataRepository) {
        self.cloudKitService = cloudKitService
        CloudKitChangeCoordinator.shared.handler = { [weak self] in
            guard let self else { return false }
            return await self.processRemoteCloudKitChange()
        }
        CoupleDataRefreshCoordinator.shared.handler = { [weak self] in
            self?.refreshCoupleData(force: true)
        }
    }

    var userId: String? { appleSession?.appleUserId }
    var coupleId: String? { currentProfile?.partnerCoupleId }

    var isCurrentUserCoupleOwner: Bool {
        guard let userId else { return false }
        return couple?.memberIds.first == userId
    }

    var partner: LongdyUser? {
        guard let userId else { return nil }
        return members.first { $0.id != userId }
    }

    var partnerLatestCheckIn: CheckIn? {
        guard let partnerId = partner?.id else { return nil }
        return checkIns.first { $0.userId == partnerId && !$0.isExpired }
            ?? checkIns.first { $0.userId != userId && !$0.isExpired }
    }

    var myLatestCheckIn: CheckIn? {
        guard let userId else { return nil }
        return checkIns.first { $0.userId == userId && !$0.isExpired }
            ?? checkIns.first { checkIn in
                partner?.id != checkIn.userId && !checkIn.isExpired
            }
    }

    var recentMemory: MemoryNote? {
        memories.first
    }

    var todayDateKey: String {
        DateKey.dateKey()
    }

    var myCareItems: [CareItem] {
        guard let userId else { return [] }
        return careItems.filter { $0.userId == userId }
    }

    var partnerCareItems: [CareItem] {
        guard let partnerId = partner?.id else { return [] }
        return careItems.filter { $0.userId == partnerId }
    }

    var dailyBridgeProgress: DailyBridgeProgress {
        BridgeProgressCalculator.calculate(
            userId: userId,
            partnerId: partner?.id,
            checkIns: checkIns,
            memories: memories,
            careItems: careItems,
            bridgeActivities: bridgeActivities
        )
    }

    static var preview: AppViewModel {
        let model = AppViewModel()
        model.isLoadingSession = false
        return model
    }

    func start() {
        isLoadingSession = true
        resetSessionData()
        appleSession = appleSessionStore.currentSession

        guard let session = appleSession else {
            isLoadingSession = false
            return
        }
        loadHomeCardOrder(for: session.appleUserId)

        Task {
            do {
                errorMessage = nil
                let profile: LongdyUser
                if let existingProfile = try await cloudKitService.fetchCurrentUserProfile(session: session) {
                    profile = existingProfile
                } else {
                    profile = try await cloudKitService.upsertUserProfile(session: session, nickname: session.displayName)
                }
                if PendingCloudKitShareStore.shared.peek() != nil {
                    try await preparePendingShareAcceptance(session: session, profile: profile)
                } else {
                    currentProfile = profile
                    restoreCachedCoupleDataIfAvailable(for: profile)
                    bindCoupleIfNeeded(profile.partnerCoupleId)
                }
                await ensureCloudKitChangeSubscriptions()
                loadWeather(for: profile)
                requestCurrentLocationIfNeeded(for: profile)
            } catch {
                errorMessage = error.longdyUserMessage
            }
            isLoadingSession = false
        }
    }

    func handlePendingCloudKitShare() {
        guard PendingCloudKitShareStore.shared.peek() != nil else { return }
        guard let session = appleSessionStore.currentSession else {
            errorMessage = "초대를 받았어요. Apple로 계속하기 후 자동으로 연결돼요."
            return
        }

        Task {
            do {
                let profile: LongdyUser
                if let currentProfile {
                    profile = currentProfile
                } else if let fetchedProfile = try await cloudKitService.fetchCurrentUserProfile(session: session) {
                    profile = fetchedProfile
                    currentProfile = fetchedProfile
                } else {
                    profile = try await cloudKitService.upsertUserProfile(session: session, nickname: session.displayName)
                    currentProfile = profile
                }
                try await preparePendingShareAcceptance(session: session, profile: profile)
            } catch {
                errorMessage = error.longdyUserMessage
            }
        }
    }

    func handleIncomingShareURL(_ url: URL) {
        Task {
            do {
                errorMessage = nil
                let metadata = try await cloudKitService.fetchShareMetadata(from: url)
                PendingCloudKitShareStore.shared.save(metadata)
                handlePendingCloudKitShare()
            } catch {
                errorMessage = "초대 링크를 확인할 수 없어요. iCloud 로그인 상태와 링크 유효성을 확인해 주세요."
            }
        }
    }

    func acceptPendingShareReplacingCurrentInvite() {
        Task {
            await acceptPendingShare(replacingCurrentInvite: true)
        }
    }

    func cancelPendingShareAcceptance() {
        PendingCloudKitShareStore.shared.discard()
        showReplaceInviteConfirmation = false
        bindCoupleIfNeeded(currentProfile?.partnerCoupleId)
    }

    private func preparePendingShareAcceptance(session: AppleSession, profile: LongdyUser) async throws {
        guard PendingCloudKitShareStore.shared.peek() != nil else {
            currentProfile = profile
            bindCoupleIfNeeded(profile.partnerCoupleId)
            return
        }

        guard let currentCoupleId = profile.partnerCoupleId else {
            await acceptPendingShare(replacingCurrentInvite: false)
            return
        }

        if try await cloudKitService.canReplaceWithIncomingShare(currentCoupleId: currentCoupleId, session: session) {
            currentProfile = profile
            bindCoupleIfNeeded(profile.partnerCoupleId)
            showReplaceInviteConfirmation = true
        } else {
            PendingCloudKitShareStore.shared.discard()
            currentProfile = profile
            bindCoupleIfNeeded(profile.partnerCoupleId)
            throw LongdyError.invalidInput("이미 연결된 커플 공간이 있어요. 새 초대를 수락하려면 먼저 연결을 정리해야 해요.")
        }
    }

    private func acceptPendingShare(replacingCurrentInvite: Bool) async {
        guard !isAcceptingPendingShare else { return }
        guard let session = appleSessionStore.currentSession else {
            errorMessage = "초대를 받았어요. Apple로 계속하기 후 자동으로 연결돼요."
            return
        }
        guard let metadata = PendingCloudKitShareStore.shared.take() else { return }

        isAcceptingPendingShare = true
        defer { isAcceptingPendingShare = false }

        do {
            errorMessage = nil
            let replacingCoupleId = replacingCurrentInvite ? currentProfile?.partnerCoupleId : nil
            let acceptedCouple = try await cloudKitService.acceptShare(
                metadata: metadata,
                session: session,
                replacingCurrentCoupleId: replacingCoupleId
            )
            if var updatedProfile = try await cloudKitService.fetchCurrentUserProfile(session: session) {
                updatedProfile.partnerCoupleId = updatedProfile.partnerCoupleId ?? acceptedCouple.id
                currentProfile = updatedProfile
            } else {
                currentProfile = try await cloudKitService.upsertUserProfile(session: session, nickname: session.displayName)
                currentProfile?.partnerCoupleId = acceptedCouple.id
            }
            couple = acceptedCouple
            showReplaceInviteConfirmation = false
            bindCoupleIfNeeded(currentProfile?.partnerCoupleId)
        } catch {
            showReplaceInviteConfirmation = false
            errorMessage = error.longdyUserMessage
        }
    }

    func signOut() {
        appleSessionStore.clear()
        appleSession = nil
        resetSessionData()
    }

    func disconnectCouple() {
        guard !isDisconnectingCouple else { return }
        guard let session = appleSession, let coupleId = currentProfile?.partnerCoupleId else { return }
        isDisconnectingCouple = true

        Task {
            do {
                errorMessage = nil
                let result = try await cloudKitService.disconnectCouple(coupleId: coupleId, session: session)
                if var profile = try await cloudKitService.fetchCurrentUserProfile(session: session) {
                    profile.partnerCoupleId = result.retainedCouple?.id
                    currentProfile = profile
                } else {
                    currentProfile?.partnerCoupleId = result.retainedCouple?.id
                }
                if let userId = appleSession?.appleUserId {
                    LocalCoupleDataCache.clear(userId: userId)
                }
                couple = result.retainedCouple
                bindMembers(from: result.retainedCouple)
                checkIns = []
                events = []
                careItems = []
                memories = []
                bridgeActivities = []
                weatherByUserId = [:]
                recentlyCommittedCareItemIDs = [:]
                recentlyCommittedMemoryIDs = [:]
                if result.retainedCouple != nil {
                    saveCurrentCoupleCache()
                }
            } catch {
                errorMessage = error.longdyUserMessage
            }
            isDisconnectingCouple = false
        }
    }

    func deleteCoupleSpace() {
        guard !isDeletingCoupleSpace else { return }
        guard let session = appleSession, let coupleId = currentProfile?.partnerCoupleId else { return }
        isDeletingCoupleSpace = true

        Task {
            do {
                errorMessage = nil
                currentProfile = try await cloudKitService.deleteCoupleSpace(
                    coupleId: coupleId,
                    session: session
                )
                if let userId = appleSession?.appleUserId {
                    LocalCoupleDataCache.clear(userId: userId)
                }
                couple = nil
                members = []
                checkIns = []
                events = []
                careItems = []
                memories = []
                bridgeActivities = []
                weatherByUserId = [:]
                recentlyCommittedCareItemIDs = [:]
                recentlyCommittedMemoryIDs = [:]
                hasLoadedCoupleData = false
                isLoadingCoupleData = false
                isRefreshingCoupleData = false
                lastCoupleDataRefreshAt = nil
                selectedMainTab = .home
            } catch {
                errorMessage = error.longdyUserMessage
            }
            isDeletingCoupleSpace = false
        }
    }

    func deleteAccount() {
        guard !isDeletingAccount, let session = appleSession else { return }
        isDeletingAccount = true

        Task {
            do {
                errorMessage = nil
                accountDeletionErrorMessage = nil
                try await cloudKitService.deleteAccount(
                    session: session,
                    coupleId: currentProfile?.partnerCoupleId
                )
                LocalCoupleDataCache.clear(userId: session.appleUserId)
                HomeCardOrderStore.clear(userId: session.appleUserId)
                PendingCloudKitShareStore.shared.discard()
                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                UNUserNotificationCenter.current().removeAllDeliveredNotifications()
                appleSessionStore.clear()
                appleSession = nil
                resetSessionData()
            } catch {
                accountDeletionErrorMessage = error.longdyUserMessage
                isDeletingAccount = false
            }
        }
    }

    func applySavedCheckIn(_ checkIn: CheckIn) {
        checkIns.removeAll { $0.id == checkIn.id }
        checkIns.insert(checkIn, at: 0)
        checkIns.sort { $0.createdAt > $1.createdAt }
        saveCurrentCoupleCache()
    }

    func applySavedEvent(_ event: CoupleEvent) {
        events.removeAll { $0.id == event.id }
        events.append(event)
        events.sort { $0.startAt < $1.startAt }
        if event.type == .meet {
            couple?.nextMeetDate = event.startAt
            Task {
                await refreshCoupleStatus()
            }
        }
        saveCurrentCoupleCache()
    }

    func removeEvent(_ event: CoupleEvent) {
        events.removeAll { $0.id == event.id }
        saveCurrentCoupleCache()
    }

    func applySavedCareItem(_ item: CareItem) {
        let previousState = careItems.first(where: { $0.id == item.id })?.effectiveSyncState
        careItems.removeAll { $0.id == item.id }
        careItems.append(item)
        careItems.sort { $0.createdAt < $1.createdAt }
        if item.effectiveSyncState == .synced,
           let previousState,
           previousState != .synced {
            recentlyCommittedCareItemIDs[item.id] = Date()
        }
        saveCurrentCoupleCache()
    }

    func toggleCareItemLocally(_ item: CareItem, dateKey: String) {
        guard let index = careItems.firstIndex(where: { $0.id == item.id }) else { return }
        if careItems[index].doneDateKeys.contains(dateKey) {
            careItems[index].doneDateKeys.removeAll { $0 == dateKey }
        } else {
            careItems[index].doneDateKeys.append(dateKey)
        }
        saveCurrentCoupleCache()
    }

    func removeCareItem(_ item: CareItem) {
        careItems.removeAll { $0.id == item.id }
        recentlyCommittedCareItemIDs.removeValue(forKey: item.id)
        saveCurrentCoupleCache()
    }

    func applySavedMemory(_ memory: MemoryNote) {
        let previousState = memories.first(where: { $0.id == memory.id })?.effectiveSyncState
        memories.removeAll {
            $0.id == memory.id
                || ($0.userId == memory.userId && $0.dateKey == memory.dateKey)
        }
        memories.insert(memory, at: 0)
        memories.sort { $0.createdAt > $1.createdAt }
        if memory.effectiveSyncState == .synced,
           let previousState,
           previousState != .synced {
            recentlyCommittedMemoryIDs[memory.id] = Date()
        }
        saveCurrentCoupleCache()
    }

    func removeMemory(_ memory: MemoryNote) {
        memories.removeAll { $0.id == memory.id }
        recentlyCommittedMemoryIDs.removeValue(forKey: memory.id)
        saveCurrentCoupleCache()
    }

    func markCalendarViewedToday() {
        guard let userId, let coupleId else { return }
        let dateKey = todayDateKey
        guard !bridgeActivities.contains(where: {
            $0.userId == userId && $0.kind == .calendarViewed && $0.dateKey == dateKey
        }) else { return }

        let pending = BridgeActivity(
            id: "pending-calendar-\(userId)-\(dateKey)",
            userId: userId,
            kind: .calendarViewed,
            dateKey: dateKey,
            createdAt: Date()
        )
        bridgeActivities.append(pending)
        saveCurrentCoupleCache()

        Task {
            do {
                let saved = try await cloudKitService.saveCalendarViewedActivity(
                    coupleId: coupleId,
                    userId: userId,
                    dateKey: dateKey
                )
                bridgeActivities.removeAll {
                    $0.id == pending.id
                        || ($0.userId == userId && $0.kind == .calendarViewed && $0.dateKey == dateKey)
                }
                bridgeActivities.append(saved)
                saveCurrentCoupleCache()
            } catch {
                bridgeActivities.removeAll { $0.id == pending.id }
                saveCurrentCoupleCache()
                errorMessage = error.longdyUserMessage
            }
        }
    }

    func moveHomeCard(from source: IndexSet, to destination: Int) {
        let movingCards = source.sorted().map { homeCardOrder[$0] }
        var remainingCards = homeCardOrder.enumerated()
            .filter { !source.contains($0.offset) }
            .map(\.element)
        let removedBeforeDestination = source.filter { $0 < destination }.count
        let insertionIndex = min(max(destination - removedBeforeDestination, 0), remainingCards.count)
        remainingCards.insert(contentsOf: movingCards, at: insertionIndex)
        homeCardOrder = remainingCards
        saveHomeCardOrder()
    }

    func resetHomeCardOrder() {
        homeCardOrder = HomeCardKind.allCases
        saveHomeCardOrder()
    }

    func weather(for user: LongdyUser?) -> WeatherSummary {
        guard let user else { return .placeholder(cityName: "위치 없음") }
        return weatherByUserId[user.id] ?? .placeholder(cityName: user.cityName)
    }

    func refreshLocationAndWeather() {
        Task {
            await refreshLocationAndWeatherNow()
        }
    }

    @discardableResult
    func refreshLocationAndWeatherNow() async -> Bool {
        guard !isRefreshingLocationWeather else { return false }
        isRefreshingLocationWeather = true
        defer { isRefreshingLocationWeather = false }

        weatherErrorMessage = nil
        hasRequestedCurrentLocation = false
        let didRefreshCurrentUser = await refreshCurrentLocationAndWeather(for: currentProfile)
        await loadWeatherAsync(for: partner)
        return didRefreshCurrentUser && weatherErrorMessage == nil
    }

    func updateNickname(_ nickname: String) {
        let cleanName = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, let session = appleSession else { return }
        isSavingProfile = true
        Task {
            do {
                currentProfile = try await cloudKitService.updateUserProfile(session: session, nickname: cleanName)
                await refreshCoupleStatus()
            } catch {
                errorMessage = error.longdyUserMessage
            }
            isSavingProfile = false
        }
    }

    func applyUpdatedProfile(_ profile: LongdyUser) {
        currentProfile = profile
        if let index = couple?.memberProfiles.firstIndex(where: { $0.id == profile.id }) {
            couple?.memberProfiles[index] = profile
        }
        bindMembers(from: couple)
        saveCurrentCoupleCache()
        Task {
            await refreshCoupleStatus()
        }
    }
}
