import Combine
import CoreLocation
import Foundation

private struct CachedCoupleSnapshot: Codable {
    var userId: String
    var coupleId: String
    var couple: Couple?
    var members: [LongdyUser]
    var checkIns: [CheckIn]
    var events: [CoupleEvent]
    var careItems: [CareItem]
    var memories: [MemoryNote]
    var bridgeActivities: [BridgeActivity]?
}

private enum LocalCoupleDataCache {
    private static func key(for userId: String) -> String {
        "longdy.cachedCoupleData.\(userId)"
    }

    static func load(userId: String) -> CachedCoupleSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: key(for: userId)) else { return nil }
        return try? JSONDecoder().decode(CachedCoupleSnapshot.self, from: data)
    }

    static func save(_ snapshot: CachedCoupleSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: key(for: snapshot.userId))
    }

    static func clear(userId: String) {
        UserDefaults.standard.removeObject(forKey: key(for: userId))
    }
}

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
    @Published var weatherByUserId: [String: WeatherSummary] = [:]
    @Published var weatherErrorMessage: String?
    @Published var errorMessage: String?
    @Published var showReplaceInviteConfirmation = false
    @Published var isDisconnectingCouple = false
    @Published var isSavingProfile = false
    @Published var isRefreshingLocationWeather = false

    private let appleSessionStore = AppleSessionStore.shared
    private let cloudKitService = CloudKitService.shared
    private let weatherService = WeatherService.shared
    private let partnerNotificationService = PartnerNotificationService.shared
    private let locationService = LocationService()
    private var hasRequestedCurrentLocation = false
    private var hasLoadedCoupleData = false
    private var isAcceptingPendingShare = false
    private var isRefreshingCoupleData = false
    private var lastCoupleDataRefreshAt: Date?
    private let minimumCoupleDataRefreshInterval: TimeInterval = 5

    init() {
        CloudKitChangeCoordinator.shared.handler = { [weak self] in
            guard let self else { return false }
            return await self.processRemoteCloudKitChange()
        }
    }

    var userId: String? { appleSession?.appleUserId }
    var coupleId: String? { currentProfile?.partnerCoupleId }

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
        let calendar = Calendar.current
        let today = Date()
        let dateKey = DateKey.dateKey(for: today)
        let myId = userId
        let partnerId = partner?.id

        func hasTodayCheckIn(_ id: String?) -> Bool {
            guard let id else { return false }
            return checkIns.contains { $0.userId == id && calendar.isDate($0.createdAt, inSameDayAs: today) }
        }

        func hasTodayPhoto(_ id: String?) -> Bool {
            guard let id else { return false }
            return memories.contains { $0.userId == id && $0.dateKey == dateKey }
        }

        func hasCompletedCare(_ id: String?) -> Bool {
            guard let id else { return false }
            return careItems.contains { $0.userId == id && $0.doneDateKeys.contains(dateKey) }
        }

        let moodPoints = (hasTodayCheckIn(myId) ? 10 : 0) + (hasTodayCheckIn(partnerId) ? 10 : 0)
        let photoPoints = (hasTodayPhoto(myId) ? 15 : 0) + (hasTodayPhoto(partnerId) ? 15 : 0)
        let carePoints = (hasCompletedCare(myId) ? 15 : 0) + (hasCompletedCare(partnerId) ? 15 : 0)
        func hasViewedCalendar(_ id: String?) -> Bool {
            guard let id else { return false }
            return bridgeActivities.contains {
                $0.userId == id && $0.kind == .calendarViewed && $0.dateKey == dateKey
            }
        }

        let calendarPoints = (hasViewedCalendar(myId) ? 10 : 0) + (hasViewedCalendar(partnerId) ? 10 : 0)

        return DailyBridgeProgress(milestones: [
            BridgeMilestone(
                id: "mood",
                title: "마음 건네기",
                detail: "두 사람의 오늘 기분 공유",
                earnedPoints: moodPoints,
                goalPoints: 20
            ),
            BridgeMilestone(
                id: "photo",
                title: "장면 나누기",
                detail: "두 사람의 오늘의 한 장",
                earnedPoints: photoPoints,
                goalPoints: 30
            ),
            BridgeMilestone(
                id: "care",
                title: "서로 챙기기",
                detail: "두 사람이 챙김 하나씩 완료",
                earnedPoints: carePoints,
                goalPoints: 30
            ),
            BridgeMilestone(
                id: "calendar",
                title: "오늘 일정 확인하기",
                detail: "두 사람이 오늘 캘린더 확인",
                earnedPoints: calendarPoints,
                goalPoints: 20
            )
        ])
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
                try await cloudKitService.disconnectCouple(coupleId: coupleId, session: session)
                if var profile = try await cloudKitService.fetchCurrentUserProfile(session: session) {
                    profile.partnerCoupleId = nil
                    currentProfile = profile
                } else {
                    currentProfile?.partnerCoupleId = nil
                }
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
            } catch {
                errorMessage = error.longdyUserMessage
            }
            isDisconnectingCouple = false
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
        careItems.removeAll { $0.id == item.id }
        careItems.append(item)
        careItems.sort { $0.createdAt < $1.createdAt }
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
        saveCurrentCoupleCache()
    }

    func applySavedMemory(_ memory: MemoryNote) {
        memories.removeAll {
            $0.id == memory.id
                || ($0.userId == memory.userId && $0.dateKey == memory.dateKey)
        }
        memories.insert(memory, at: 0)
        memories.sort { $0.createdAt > $1.createdAt }
        saveCurrentCoupleCache()
    }

    func removeMemory(_ memory: MemoryNote) {
        memories.removeAll { $0.id == memory.id }
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

    func refreshCoupleData(force: Bool = false) {
        guard let coupleId else { return }
        Task {
            await loadCoupleData(coupleId: coupleId, forceRefresh: force)
        }
    }

    func processRemoteCloudKitChange() async -> Bool {
        guard let coupleId else { return false }
        let shouldNotify = hasLoadedCoupleData
        let previousCheckInIDs = Set(checkIns.map(\.id))
        let previousMemoryIDs = Set(memories.map(\.id))
        let previousEventIDs = Set(events.map(\.id))

        var didLoad = false
        for attempt in 0..<3 {
            if await loadCoupleData(coupleId: coupleId, forceRefresh: true) {
                didLoad = true
                break
            }
            if attempt < 2 {
                try? await Task.sleep(for: .milliseconds(500))
            }
        }

        guard didLoad, shouldNotify, let partnerId = partner?.id else { return didLoad }

        if checkIns.contains(where: { $0.userId == partnerId && !previousCheckInIDs.contains($0.id) }) {
            await partnerNotificationService.send(.mood)
        }
        if memories.contains(where: { $0.userId == partnerId && !previousMemoryIDs.contains($0.id) }) {
            await partnerNotificationService.send(.photo)
        }
        if events.contains(where: { $0.ownerUserId == partnerId && !previousEventIDs.contains($0.id) }) {
            await partnerNotificationService.send(.event)
        }
        return true
    }

    func refreshCoupleStatus() async {
        guard let coupleId else { return }
        do {
            if let refreshedCouple = try await cloudKitService.fetchCoupleRoot(recordName: coupleId) {
                couple = refreshedCouple
                if currentProfile?.partnerCoupleId != refreshedCouple.id {
                    currentProfile?.partnerCoupleId = refreshedCouple.id
                    if let appleSession {
                        try? await cloudKitService.repairUserCoupleReference(session: appleSession, coupleId: refreshedCouple.id)
                    }
                }
                bindMembers(from: refreshedCouple)
                if refreshedCouple.memberIds.count >= 2 {
                    await loadCoupleData(coupleId: refreshedCouple.id, forceRefresh: true)
                }
            } else {
                currentProfile?.partnerCoupleId = nil
                couple = nil
                members = []
            }
        } catch {
            errorMessage = error.longdyUserMessage
        }
    }

    func pollCoupleStatus() async {
        while !Task.isCancelled {
            guard coupleId != nil else { return }
            await refreshCoupleStatus()
            try? await Task.sleep(for: .seconds(60))
        }
    }

    private func ensureCloudKitChangeSubscriptions() async {
        do {
            try await cloudKitService.ensureChangeSubscriptions()
        } catch {
            #if DEBUG
            print("Longdy CloudKit subscription skipped: \(error.longdyUserMessage)")
            #endif
        }
    }

    private func resetSessionData() {
        isLoadingCoupleData = false
        hasLoadedCoupleData = false
        currentProfile = nil
        couple = nil
        members = []
        checkIns = []
        events = []
        careItems = []
        memories = []
        bridgeActivities = []
        homeCardOrder = HomeCardKind.allCases
        weatherByUserId = [:]
        weatherErrorMessage = nil
        hasRequestedCurrentLocation = false
        isRefreshingCoupleData = false
        lastCoupleDataRefreshAt = nil
    }

    private func bindCoupleIfNeeded(_ coupleId: String?) {
        let canKeepCachedData = hasLoadedCoupleData
            && (couple?.id == coupleId || currentProfile?.partnerCoupleId == coupleId)
        if !canKeepCachedData {
            couple = nil
            members = []
            checkIns = []
            events = []
            careItems = []
            memories = []
            bridgeActivities = []
            hasLoadedCoupleData = false
        }
        isLoadingCoupleData = false

        guard let coupleId else { return }
        Task {
            do {
                let couple = try await cloudKitService.fetchCoupleRoot(recordName: coupleId)
                if couple == nil {
                    self.currentProfile?.partnerCoupleId = nil
                    self.couple = nil
                    self.members = []
                    return
                }
                self.couple = couple
                if self.currentProfile?.partnerCoupleId != couple?.id {
                    self.currentProfile?.partnerCoupleId = couple?.id
                    if let session = self.appleSession, let repairedCoupleId = couple?.id {
                        try? await self.cloudKitService.repairUserCoupleReference(session: session, coupleId: repairedCoupleId)
                    }
                }
                self.bindMembers(from: couple)
                if (couple?.memberIds.count ?? 0) >= 2 {
                    let resolvedCoupleId = couple?.id ?? coupleId
                    Task {
                        await self.partnerNotificationService.requestAuthorizationIfNeeded()
                    }
                    await self.loadHomeData(coupleId: resolvedCoupleId, showLoading: !self.hasLoadedCoupleData)
                    Task { await self.loadCoupleData(coupleId: resolvedCoupleId, forceRefresh: true) }
                }
            } catch {
                self.errorMessage = error.longdyUserMessage
                self.isLoadingCoupleData = false
            }
        }
    }

    private func bindMembers(from couple: Couple?) {
        guard let couple else {
            members = []
            return
        }
        var nextMembers = couple.memberProfiles
        if let currentProfile, couple.memberIds.contains(currentProfile.id) {
            nextMembers.removeAll { $0.id == currentProfile.id }
            nextMembers.append(currentProfile)
        }
        members = nextMembers.filter { couple.memberIds.contains($0.id) }
        members.forEach { loadWeather(for: $0) }
    }

    @discardableResult
    private func loadCoupleData(coupleId: String, showLoading: Bool = false, forceRefresh: Bool = false) async -> Bool {
        guard !isRefreshingCoupleData else { return false }
        if !forceRefresh,
           hasLoadedCoupleData,
           let lastCoupleDataRefreshAt,
           Date().timeIntervalSince(lastCoupleDataRefreshAt) < minimumCoupleDataRefreshInterval {
            return true
        }

        isRefreshingCoupleData = true
        defer {
            isRefreshingCoupleData = false
        }

        let shouldShowLoading = showLoading || !hasLoadedCoupleData
        if shouldShowLoading {
            isLoadingCoupleData = true
        }
        defer {
            if shouldShowLoading {
                isLoadingCoupleData = false
            }
        }
        do {
            let data = try await cloudKitService.fetchCoupleData(coupleId: coupleId)
            checkIns = data.checkIns
            events = data.events
            careItems = data.careItems
            memories = data.memories
            bridgeActivities = try await cloudKitService.fetchBridgeActivities(
                coupleId: coupleId,
                userIds: members.map(\.id),
                dateKey: todayDateKey
            )
            hasLoadedCoupleData = true
            lastCoupleDataRefreshAt = Date()
            saveCurrentCoupleCache()
            #if DEBUG
            print("Longdy CloudKit load checkIns: \(data.checkIns.count), events: \(data.events.count), careItems: \(data.careItems.count) for \(coupleId)")
            #endif
            return true
        } catch {
            errorMessage = error.longdyUserMessage
            #if DEBUG
            print("Longdy CloudKit load failed: \(error.longdyUserMessage)")
            #endif
            return false
        }
    }

    private func loadHomeData(coupleId: String, showLoading: Bool) async {
        if showLoading {
            isLoadingCoupleData = true
        }
        defer {
            if showLoading {
                isLoadingCoupleData = false
            }
        }
        do {
            let data = try await cloudKitService.fetchHomeData(coupleId: coupleId)
            checkIns = data.checkIns
            events = data.events
            careItems = data.careItems
            bridgeActivities = try await cloudKitService.fetchBridgeActivities(
                coupleId: coupleId,
                userIds: members.map(\.id),
                dateKey: todayDateKey
            )
            hasLoadedCoupleData = true
            saveCurrentCoupleCache()
            #if DEBUG
            print("Longdy CloudKit load home checkIns: \(data.checkIns.count), events: \(data.events.count), careItems: \(data.careItems.count) for \(coupleId)")
            #endif
        } catch {
            errorMessage = error.longdyUserMessage
            #if DEBUG
            print("Longdy CloudKit home load failed: \(error.longdyUserMessage)")
            #endif
        }
    }

    private func restoreCachedCoupleDataIfAvailable(for profile: LongdyUser) {
        guard let targetCoupleId = profile.partnerCoupleId,
              let snapshot = LocalCoupleDataCache.load(userId: profile.id),
              snapshot.coupleId == targetCoupleId || snapshot.couple?.id == targetCoupleId else { return }

        couple = snapshot.couple
        members = snapshot.members
        checkIns = snapshot.checkIns
        events = snapshot.events
        careItems = snapshot.careItems
        memories = snapshot.memories
        bridgeActivities = snapshot.bridgeActivities ?? []
        hasLoadedCoupleData = true
        isLoadingCoupleData = false
    }

    private func saveCurrentCoupleCache() {
        guard let userId, let coupleId else { return }
        let snapshot = CachedCoupleSnapshot(
            userId: userId,
            coupleId: coupleId,
            couple: couple,
            members: members,
            checkIns: checkIns,
            events: events,
            careItems: careItems,
            memories: memories,
            bridgeActivities: bridgeActivities.filter { !$0.id.hasPrefix("pending-") }
        )
        LocalCoupleDataCache.save(snapshot)
    }

    private func loadHomeCardOrder(for userId: String) {
        let rawValues = UserDefaults.standard.stringArray(forKey: homeCardOrderKey(userId)) ?? []
        var seen: Set<HomeCardKind> = []
        var restored = rawValues
            .compactMap(HomeCardKind.init(rawValue:))
            .filter { seen.insert($0).inserted }
        restored.append(contentsOf: HomeCardKind.allCases.filter { seen.insert($0).inserted })
        homeCardOrder = restored
    }

    private func saveHomeCardOrder() {
        guard let userId else { return }
        UserDefaults.standard.set(homeCardOrder.map(\.rawValue), forKey: homeCardOrderKey(userId))
    }

    private func homeCardOrderKey(_ userId: String) -> String {
        "longdy.homeCardOrder.\(userId)"
    }

    private func requestCurrentLocationIfNeeded(for profile: LongdyUser?) {
        guard !hasRequestedCurrentLocation, let profile, profile.id == userId, appleSession != nil else { return }
        hasRequestedCurrentLocation = true

        Task {
            await refreshCurrentLocationAndWeather(for: profile)
        }
    }

    private func loadWeather(for user: LongdyUser?) {
        guard let user, let _ = user.latitude, let _ = user.longitude else { return }
        Task {
            await loadWeatherAsync(for: user)
        }
    }

    @discardableResult
    private func refreshCurrentLocationAndWeather(for profile: LongdyUser?) async -> Bool {
        guard let profile, profile.id == userId, let session = appleSession else { return false }

        do {
            let location = try await locationService.requestCurrentLocation()
            let latitude = roundedCoordinate(location.coordinate.latitude)
            let longitude = roundedCoordinate(location.coordinate.longitude)
            let cityName = await weatherService.cityName(latitude: latitude, longitude: longitude, fallback: profile.cityName)
            currentProfile = try await cloudKitService.updateUserLocation(
                session: session,
                latitude: latitude,
                longitude: longitude,
                timezoneId: TimeZone.current.identifier
            )
            currentProfile = try await cloudKitService.updateUserProfile(
                session: session,
                cityName: cityName,
                timezoneId: TimeZone.current.identifier
            )
            await refreshCoupleStatus()
            await fetchWeather(userId: profile.id, cityName: cityName, latitude: latitude, longitude: longitude)
            return true
        } catch let error as LocationError {
            weatherErrorMessage = error.longdyUserMessage
            await loadWeatherAsync(for: profile)
            return false
        } catch {
            weatherErrorMessage = error.longdyUserMessage
            return false
        }
    }

    private func loadWeatherAsync(for user: LongdyUser?) async {
        guard let user, let latitude = user.latitude, let longitude = user.longitude else { return }
        await fetchWeather(
            userId: user.id,
            cityName: user.cityName,
            latitude: latitude,
            longitude: longitude
        )
    }

    private func fetchWeather(userId: String, cityName: String, latitude: Double, longitude: Double) async {
        do {
            let weather = try await weatherService.currentWeather(latitude: latitude, longitude: longitude)
            weatherByUserId[userId] = weather
            if self.userId == userId { weatherErrorMessage = nil }
        } catch WeatherError.missingAPIKey {
            weatherByUserId[userId] = .placeholder(cityName: cityName)
        } catch {
            weatherByUserId[userId] = .placeholder(cityName: cityName)
            if self.userId == userId { weatherErrorMessage = error.longdyUserMessage }
        }
    }

    private func roundedCoordinate(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }

}
