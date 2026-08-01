import CloudKit
import Foundation

extension AppViewModel {
    func refreshCoupleData(force: Bool = false) {
        guard let coupleId else { return }
        Task {
            await loadCoupleData(coupleId: coupleId, forceRefresh: force)
        }
    }

    func processRemoteCloudKitChange(suppressLocalNotification: Bool = false) async -> Bool {
        guard let coupleId else { return false }
        let shouldNotify = hasLoadedCoupleData
        let previousCheckInIDs = Set(checkIns.map(\.id))
        let previousMemoryIDs = Set(memories.map(\.id))
        let previousEventIDs = Set(events.map(\.id))

        do {
            if let refreshedCouple = try await cloudKitService.fetchCoupleRoot(recordName: coupleId) {
                couple = refreshedCouple
                bindMembers(from: refreshedCouple)
                saveCurrentCoupleCache()
            } else {
                await clearStaleCoupleConnection()
                return true
            }
        } catch {
            if isMissingCoupleAccessError(error) {
                await clearStaleCoupleConnection()
                return true
            }
            #if DEBUG
            print("Longdy CloudKit root refresh failed: \(error.longdyUserMessage)")
            #endif
        }

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

        guard didLoad, shouldNotify, !suppressLocalNotification, let partnerId = partner?.id else { return didLoad }

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
                await clearStaleCoupleConnection()
            }
        } catch {
            if isMissingCoupleAccessError(error) {
                await clearStaleCoupleConnection()
                return
            }
            errorMessage = error.longdyUserMessage
        }
    }

    func pollCoupleStatus() async {
        while !Task.isCancelled {
            guard coupleId != nil else { return }
            await refreshCoupleStatus()
            try? await Task.sleep(for: .seconds(5))
        }
    }

    func ensureCloudKitChangeSubscriptions() async {
        do {
            try await cloudKitService.ensureChangeSubscriptions()
        } catch {
            #if DEBUG
            print("Longdy CloudKit subscription skipped: \(error.longdyUserMessage)")
            #endif
        }
    }

    func resetSessionData() {
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
        selectedMainTab = .home
        weatherByUserId = [:]
        weatherErrorMessage = nil
        hasRequestedCurrentLocation = false
        isRefreshingCoupleData = false
        lastCoupleDataRefreshAt = nil
        isDisconnectingCouple = false
        isDeletingCoupleSpace = false
        isDeletingAccount = false
        accountDeletionErrorMessage = nil
    }

    func bindCoupleIfNeeded(_ coupleId: String?) {
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
                    await self.clearStaleCoupleConnection()
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
                if self.isMissingCoupleAccessError(error) {
                    await self.clearStaleCoupleConnection()
                    self.isLoadingCoupleData = false
                    return
                }
                self.errorMessage = error.longdyUserMessage
                self.isLoadingCoupleData = false
            }
        }
    }

    func bindMembers(from couple: Couple?) {
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

    func clearStaleCoupleConnection() async {
        if let appleSession {
            if let resetProfile = try? await cloudKitService.resetUserProfileAfterCoupleDeletion(
                session: appleSession
            ) {
                currentProfile = resetProfile
            } else {
                currentProfile?.partnerCoupleId = nil
            }
            LocalCoupleDataCache.clear(userId: appleSession.appleUserId)
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
    }

    func isMissingCoupleAccessError(_ error: Error) -> Bool {
        guard let cloudKitError = error as? CKError else { return false }
        switch cloudKitError.code {
        case .unknownItem, .permissionFailure, .zoneNotFound, .userDeletedZone:
            return true
        default:
            return false
        }
    }

    @discardableResult
    func loadCoupleData(coupleId: String, showLoading: Bool = false, forceRefresh: Bool = false) async -> Bool {
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
            careItems = mergeUnsyncedCareItems(with: data.careItems)
            memories = mergeUnsyncedMemories(with: data.memories)
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

    func loadHomeData(coupleId: String, showLoading: Bool) async {
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
            careItems = mergeUnsyncedCareItems(with: data.careItems)
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

    func restoreCachedCoupleDataIfAvailable(for profile: LongdyUser) {
        guard let targetCoupleId = profile.partnerCoupleId,
              let snapshot = LocalCoupleDataCache.load(userId: profile.id),
              snapshot.coupleId == targetCoupleId || snapshot.couple?.id == targetCoupleId else { return }

        couple = snapshot.couple
        members = snapshot.members
        checkIns = snapshot.checkIns
        events = snapshot.events
        careItems = snapshot.careItems.map { item in
            var restored = item
            if restored.effectiveSyncState == .pending { restored.syncState = .failed }
            if restored.effectiveSyncState == .deleting { restored.syncState = .deleteFailed }
            return restored
        }
        memories = snapshot.memories.map { memory in
            var restored = memory
            if restored.effectiveSyncState == .pending { restored.syncState = .failed }
            if restored.effectiveSyncState == .deleting { restored.syncState = .deleteFailed }
            return restored
        }
        bridgeActivities = snapshot.bridgeActivities ?? []
        hasLoadedCoupleData = true
        isLoadingCoupleData = false
    }

    func saveCurrentCoupleCache() {
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

    func mergeUnsyncedCareItems(with remoteItems: [CareItem]) -> [CareItem] {
        let now = Date()
        let remoteIDs = Set(remoteItems.map(\.id))
        recentlyCommittedCareItemIDs = recentlyCommittedCareItemIDs.filter { id, committedAt in
            !remoteIDs.contains(id) && now.timeIntervalSince(committedAt) < cloudKitReconciliationGrace
        }
        let protectedIDs = Set(recentlyCommittedCareItemIDs.keys)
        let localItems = careItems.filter {
            $0.effectiveSyncState != .synced || protectedIDs.contains($0.id)
        }
        let localIDs = Set(localItems.map(\.id))
        return localItems + remoteItems.filter { !localIDs.contains($0.id) }
    }

    func mergeUnsyncedMemories(with remoteMemories: [MemoryNote]) -> [MemoryNote] {
        let now = Date()
        let remoteIDs = Set(remoteMemories.map(\.id))
        recentlyCommittedMemoryIDs = recentlyCommittedMemoryIDs.filter { id, committedAt in
            !remoteIDs.contains(id) && now.timeIntervalSince(committedAt) < cloudKitReconciliationGrace
        }
        let protectedIDs = Set(recentlyCommittedMemoryIDs.keys)
        let localMemories = memories.filter {
            $0.effectiveSyncState != .synced || protectedIDs.contains($0.id)
        }
        let localIDs = Set(localMemories.map(\.id))
        return (localMemories + remoteMemories.filter { !localIDs.contains($0.id) })
            .sorted { $0.createdAt > $1.createdAt }
    }

    func loadHomeCardOrder(for userId: String) {
        homeCardOrder = HomeCardOrderStore.load(userId: userId)
    }

    func saveHomeCardOrder() {
        guard let userId else { return }
        HomeCardOrderStore.save(homeCardOrder, userId: userId)
    }
}
