import Foundation
import CloudKit
import Observation
import os
import CryptoKit
import UserNotifications

@Observable
final class CloudKitService: DataServiceProtocol {

    // MARK: - Observable State (mirrors MockDataService)

    var pair: Pair
    var currentUser: UserProfile
    var partner: UserProfile
    var weeklyGoals: [WeeklyGoal]
    var workouts: [Workout]
    var nudges: [Nudge]

    // MARK: - CloudKit Error State

    var cloudKitError: CloudKitServiceError?
    var isOffline: Bool = false
    var needsAuthentication: Bool = false
    var isStorageFull: Bool = false
    var hasGroup: Bool = false
    var isLoading: Bool = true
    var onboardingDebugLog: [String] = []

    // MARK: - CloudKit Internals

    private let container = CKContainer(identifier: "iCloud.com.sammyvanderpoel.FitPinky")
    private var groupZoneID: CKRecordZone.ID?
    private var memberCount: Int = 0
    private let photoCache = NSCache<NSUUID, NSData>()

    private let ensureWeekGoalLock = OSAllocatedUnfairLock(initialState: false)
    private var initialSyncComplete = false

    private static let changeTokenKeyPrefix = "FitPinky_serverChangeToken_"
    private static let subscriptionSetupKey = "FitPinky_subscriptionsCreated_v1"

    private enum GroupZoneLocation {
        case privateDB
        case sharedDB
    }

    private var groupZoneLocation: GroupZoneLocation = .sharedDB
    private let logger = Logger(subsystem: "com.sammyvanderpoel.fitpinky", category: "Onboarding")

    private var activeGroupDatabase: CKDatabase {
        switch groupZoneLocation {
        case .privateDB:
            return container.privateCloudDatabase
        case .sharedDB:
            return container.sharedCloudDatabase
        }
    }

    private static let inviteCodeCharacters = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
    static let pendingInviteCodeKey = "FitPinky_pendingInviteCode"

    // MARK: - Init

    init() {
        let placeholderId = UUID()
        self.pair = Pair(
            id: placeholderId,
            userAId: placeholderId,
            userBId: placeholderId,
            weekStartDay: 1,
            inviteCode: ""
        )
        self.currentUser = UserProfile(
            id: placeholderId,
            pairId: placeholderId,
            displayName: "Me",
            weeklyGoal: 4
        )
        self.partner = UserProfile(
            id: placeholderId,
            pairId: placeholderId,
            displayName: "Partner",
            weeklyGoal: 4
        )
        self.weeklyGoals = []
        self.workouts = []
        self.nudges = []
    }

    // MARK: - Setup

    func setup() async {
        addDebug("setup() started")
        isLoading = true
        cloudKitError = nil
        isOffline = false
        isStorageFull = false
        defer { isLoading = false }

        do {
            let status = try await container.accountStatus()
            addDebug("iCloud account status rawValue=\(status.rawValue)")
            switch status {
            case .available:
                needsAuthentication = false
            case .noAccount, .restricted, .couldNotDetermine:
                needsAuthentication = true
                hasGroup = false
                addDebug("setup() exited: needsAuthentication = true")
                return
            case .temporarilyUnavailable:
                isOffline = true
                hasGroup = false
                addDebug("setup() exited: temporarily unavailable")
                return
            @unknown default:
                needsAuthentication = true
                hasGroup = false
                addDebug("setup() exited: unknown account status")
                return
            }

            try await discoverGroupZone()
            guard groupZoneID != nil else {
                hasGroup = false
                memberCount = 0
                addDebug("no group zone found in private/shared databases")
                return
            }

            try await fetchAllRecords()
            hasGroup = memberCount >= 2
            if hasGroup {
                UserDefaults.standard.removeObject(forKey: Self.pendingInviteCodeKey)
                await ensureCurrentWeekGoal()
            }
            addDebug("setup() completed: members=\(memberCount), hasGroup=\(hasGroup), zone=\(groupZoneID?.zoneName ?? "nil")")
        } catch {
            addDebug("setup() failed: \(debugDescription(for: error))")
            handleError(error)
        }
    }

    // MARK: - DataServiceProtocol

    func getCurrentUser() -> UserProfile { currentUser }
    func getPartner() -> UserProfile { partner }
    func getPair() -> Pair { pair }

    func getCurrentWeek() -> WeeklyGoal {
        weeklyGoals.first { $0.result == nil } ?? weeklyGoals.first ?? WeeklyGoal(
            pairId: pair.id,
            weekStart: Date.now.startOfWeek(weekStartDay: pair.weekStartDay),
            goalUserA: currentUser.weeklyGoal,
            goalUserB: partner.weeklyGoal,
            wagerText: ""
        )
    }

    func getWorkouts(for weeklyGoal: WeeklyGoal) -> [Workout] {
        workouts.filter { $0.weeklyGoalId == weeklyGoal.id }
    }

    func logWorkout(photoData: Data, caption: String?) async throws {
        let currentWeek = getCurrentWeek()
        let workoutDate = effectiveWorkoutDate()

        let workout = Workout(
            userId: currentUser.id,
            pairId: pair.id,
            weeklyGoalId: currentWeek.id,
            photoData: photoData,
            caption: caption,
            loggedAt: .now,
            workoutDate: workoutDate
        )

        workouts.append(workout)

        guard let zoneID = groupZoneID else { return }
        let database = activeGroupDatabase

        let record = CKRecord(recordType: "Workout", recordID: CKRecord.ID(zoneID: zoneID))
        record["memberRef"] = CKRecord.Reference(
            recordID: CKRecord.ID(recordName: currentUser.id.uuidString, zoneID: zoneID),
            action: .none
        )
        record["groupRef"] = CKRecord.Reference(
            recordID: CKRecord.ID(recordName: pair.id.uuidString, zoneID: zoneID),
            action: .none
        )
        record["weeklyGoalRef"] = CKRecord.Reference(
            recordID: CKRecord.ID(recordName: currentWeek.id.uuidString, zoneID: zoneID),
            action: .none
        )
        record["caption"] = caption as CKRecordValue?
        record["loggedAt"] = Date.now as CKRecordValue
        record["workoutDate"] = workoutDate as CKRecordValue
        record["workoutId"] = workout.id.uuidString as CKRecordValue

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".heic")
        try photoData.write(to: tempURL)
        record["photo"] = CKAsset(fileURL: tempURL)

        do {
            try await database.save(record)
            try? FileManager.default.removeItem(at: tempURL)
            // Delta sync in background to pick up server-side changes
            Task { [weak self] in await self?.performDeltaSync() }
        } catch {
            workouts.removeAll { $0.id == workout.id }
            try? FileManager.default.removeItem(at: tempURL)
            handleError(error)
            throw mapCKError(error)
        }
    }

    func updateWager(text: String) async throws {
        guard let index = weeklyGoals.firstIndex(where: { $0.result == nil }) else { return }
        guard let zoneID = groupZoneID else { return }
        let database = activeGroupDatabase

        let weeklyGoal = weeklyGoals[index]
        let recordID = CKRecord.ID(recordName: weeklyGoal.id.uuidString, zoneID: zoneID)

        do {
            let record = try await database.record(for: recordID)
            record["wagerText"] = text as CKRecordValue
            try await database.save(record)
            weeklyGoals[index].wagerText = text
        } catch {
            handleError(error)
            throw mapCKError(error)
        }
    }

    func getStreak() -> Int {
        let completed = weeklyGoals
            .filter { $0.result != nil }
            .sorted { $0.weekStart > $1.weekStart }

        var streak = 0
        for week in completed {
            if week.result == .bothHit {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    func getBestStreak() -> Int {
        let completed = weeklyGoals
            .filter { $0.result != nil }
            .sorted { $0.weekStart > $1.weekStart }

        var best = 0
        var current = 0
        for week in completed {
            if week.result == .bothHit {
                current += 1
                best = max(best, current)
            } else {
                current = 0
            }
        }
        return best
    }

    func getPastWeeks() -> [WeeklyGoal] {
        weeklyGoals
            .filter { $0.result != nil }
            .sorted { $0.weekStart > $1.weekStart }
    }

    func updateDisplayName(_ name: String) async throws {
        guard let zoneID = groupZoneID else { return }
        let database = activeGroupDatabase

        let recordID = CKRecord.ID(recordName: currentUser.id.uuidString, zoneID: zoneID)

        do {
            let record = try await database.record(for: recordID)
            record["displayName"] = name as CKRecordValue
            try await database.save(record)
            currentUser.displayName = name
        } catch {
            handleError(error)
            throw mapCKError(error)
        }
    }

    func updateWeeklyGoal(_ days: Int) async throws {
        guard let zoneID = groupZoneID else { return }
        let database = activeGroupDatabase

        let memberRecordID = CKRecord.ID(recordName: currentUser.id.uuidString, zoneID: zoneID)

        do {
            let memberRecord = try await database.record(for: memberRecordID)
            memberRecord["weeklyGoal"] = days as CKRecordValue
            try await database.save(memberRecord)
            currentUser.weeklyGoal = days

            if let index = weeklyGoals.firstIndex(where: { $0.result == nil }) {
                let goalRecordID = CKRecord.ID(recordName: weeklyGoals[index].id.uuidString, zoneID: zoneID)
                let goalRecord = try await database.record(for: goalRecordID)

                let goalFieldName = currentUser.id == pair.userAId ? "goalUserA" : "goalUserB"
                goalRecord[goalFieldName] = days as CKRecordValue
                try await database.save(goalRecord)

                if goalFieldName == "goalUserA" {
                    weeklyGoals[index].goalUserA = days
                } else {
                    weeklyGoals[index].goalUserB = days
                }
            }
        } catch {
            handleError(error)
            throw mapCKError(error)
        }
    }

    func updateWeekStartDay(_ day: Int) async throws {
        guard let zoneID = groupZoneID else { return }
        let database = activeGroupDatabase

        let recordID = CKRecord.ID(recordName: pair.id.uuidString, zoneID: zoneID)

        do {
            let record = try await database.record(for: recordID)
            record["weekStartDay"] = day as CKRecordValue
            try await database.save(record)
            pair.weekStartDay = day
        } catch {
            handleError(error)
            throw mapCKError(error)
        }
    }

    func latestWorkout(for userId: UUID) -> Workout? {
        let currentWeek = getCurrentWeek()
        return workouts
            .filter { $0.weeklyGoalId == currentWeek.id && $0.userId == userId }
            .sorted { $0.loggedAt > $1.loggedAt }
            .first
    }

    func hasLoggedToday() -> Bool {
        let today = effectiveWorkoutDate()
        return workouts.contains {
            $0.userId == currentUser.id && $0.workoutDate.calendarDate == today
        }
    }

    func workoutDays(for userId: UUID, in weeklyGoal: WeeklyGoal) -> Int {
        let weekWorkouts = workouts.filter {
            $0.weeklyGoalId == weeklyGoal.id && $0.userId == userId
        }
        let uniqueDays = Set(weekWorkouts.map { $0.workoutDate.calendarDate })
        return uniqueDays.count
    }

    func loadPhoto(for workout: Workout) async -> Data? {
        if let data = workout.photoData { return data }
        if let cached = photoCache.object(forKey: workout.id as NSUUID) {
            return cached as Data
        }

        guard let recordName = workout.photoRecordName, let zoneID = groupZoneID else { return nil }
        let database = activeGroupDatabase
        let recordID = CKRecord.ID(recordName: recordName, zoneID: zoneID)

        do {
            let record = try await database.record(for: recordID)
            if let asset = record["photo"] as? CKAsset, let fileURL = asset.fileURL {
                let data = try Data(contentsOf: fileURL)
                photoCache.setObject(data as NSData, forKey: workout.id as NSUUID)
                return data
            }
        } catch {
            // Photo load failed — view will show placeholder
        }
        return nil
    }

    // MARK: - Weekly Goal Auto-Creation

    func ensureCurrentWeekGoal() async {
        let didAcquire = ensureWeekGoalLock.withLock { locked -> Bool in
            guard !locked else { return false }
            locked = true
            return true
        }
        guard didAcquire, hasGroup, let zoneID = groupZoneID else { return }
        defer { ensureWeekGoalLock.withLock { $0 = false } }

        let currentWeekStart = Date.now.startOfWeek(weekStartDay: pair.weekStartDay)

        await evaluatePreviousWeekIfNeeded(currentWeekStart: currentWeekStart)

        let currentCalendarDate = currentWeekStart.calendarDate
        if weeklyGoals.contains(where: { $0.weekStart.calendarDate == currentCalendarDate }) {
            return
        }

        let goalUserA: Int
        let goalUserB: Int
        if currentUser.id == pair.userAId {
            goalUserA = currentUser.weeklyGoal
            goalUserB = partner.weeklyGoal
        } else {
            goalUserA = partner.weeklyGoal
            goalUserB = currentUser.weeklyGoal
        }

        let previousWager = weeklyGoals
            .sorted { $0.weekStart > $1.weekStart }
            .first?.wagerText ?? ""

        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        let iso8601 = formatter.string(from: currentWeekStart)
        let recordName = "\(pair.id.uuidString)_\(iso8601)"

        let newGoal = WeeklyGoal(
            id: UUID(),
            pairId: pair.id,
            weekStart: currentWeekStart,
            goalUserA: goalUserA,
            goalUserB: goalUserB,
            wagerText: previousWager
        )

        weeklyGoals.append(newGoal)

        let database = activeGroupDatabase
        let record = CKRecord(
            recordType: "WeeklyGoal",
            recordID: CKRecord.ID(recordName: recordName, zoneID: zoneID)
        )
        record["weeklyGoalId"] = newGoal.id.uuidString as CKRecordValue
        record["groupRef"] = CKRecord.Reference(
            recordID: CKRecord.ID(recordName: pair.id.uuidString, zoneID: zoneID),
            action: .none
        )
        record["weekStart"] = currentWeekStart as CKRecordValue
        record["goalUserA"] = goalUserA as CKRecordValue
        record["goalUserB"] = goalUserB as CKRecordValue
        record["wagerText"] = previousWager as CKRecordValue

        do {
            try await database.save(record)
            addDebug("ensureCurrentWeekGoal() created goal for \(iso8601)")
        } catch let ckError as CKError where ckError.code == .serverRecordChanged {
            // Another device already created it — fetch instead
            weeklyGoals.removeAll { $0.id == newGoal.id }
            do {
                try await fetchWeeklyGoalRecords(zoneID: zoneID, database: database)
            } catch {
                addDebug("ensureCurrentWeekGoal() re-fetch failed: \(debugDescription(for: error))")
            }
        } catch {
            weeklyGoals.removeAll { $0.id == newGoal.id }
            addDebug("ensureCurrentWeekGoal() failed: \(debugDescription(for: error))")
        }
    }

    private func evaluatePreviousWeekIfNeeded(currentWeekStart: Date) async {
        // Only the zone owner writes results to avoid race conditions between devices
        guard groupZoneLocation == .privateDB else { return }

        let unevaluated = weeklyGoals.filter { goal in
            goal.result == nil && goal.weekStart.calendarDate < currentWeekStart.calendarDate
        }

        guard !unevaluated.isEmpty, let zoneID = groupZoneID else { return }

        for goal in unevaluated {
            let daysA = workoutDays(for: pair.userAId, in: goal)
            let daysB = workoutDays(for: pair.userBId, in: goal)
            let hitA = daysA >= goal.goalUserA
            let hitB = daysB >= goal.goalUserB

            let result: WeekResult
            switch (hitA, hitB) {
            case (true, true): result = .bothHit
            case (false, true): result = .aOwes
            case (true, false): result = .bOwes
            case (false, false): result = .bothMissed
            }

            if let safeIndex = weeklyGoals.firstIndex(where: { $0.id == goal.id }) {
                weeklyGoals[safeIndex].result = result
            }
            addDebug("evaluatePreviousWeek() \(goal.weekStart.calendarDate): A=\(daysA)/\(goal.goalUserA) B=\(daysB)/\(goal.goalUserB) → \(result.rawValue)")

            if initialSyncComplete {
                postWeekResultNotification(result: result, wagerText: goal.wagerText)
            }

            let database = activeGroupDatabase
            let recordName = goal.id.uuidString
            Task {
                do {
                    let record = try await database.record(for: CKRecord.ID(recordName: recordName, zoneID: zoneID))
                    record["result"] = result.rawValue as CKRecordValue
                    try await database.save(record)
                } catch let ckError as CKError where ckError.code == .serverRecordChanged {
                    if let serverRecord = ckError.serverRecord {
                        serverRecord["result"] = result.rawValue as CKRecordValue
                        try? await database.save(serverRecord)
                    }
                } catch {
                    self.addDebug("evaluatePreviousWeek() save failed for \(recordName): \(self.debugDescription(for: error))")
                }
            }
        }
    }

    // MARK: - Onboarding Flow

    /// Create group: zone + Group record + Member record + CKShare + invite code
    func createGroup(displayName: String, weeklyGoal: Int) async throws -> String {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw CloudKitServiceError.groupCreationFailed }
        addDebug("createGroup() start: name=\(trimmedName), goal=\(weeklyGoal)")

        let groupID = UUID()
        let zoneName = "FitPinkyGroup_\(groupID.uuidString)"
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        let zone = CKRecordZone(zoneID: zoneID)

        let userRecordName = try? await container.userRecordID().recordName
        let myMemberID = stableMemberID(for: userRecordName) ?? UUID()
        let inviteCode = try await reserveInviteCode()
        addDebug("createGroup() reserved invite code: \(inviteCode)")

        let groupRecordID = CKRecord.ID(recordName: groupID.uuidString, zoneID: zoneID)
        let groupRecord = CKRecord(recordType: "Group", recordID: groupRecordID)
        groupRecord["userAId"] = myMemberID.uuidString as CKRecordValue
        groupRecord["userBId"] = "" as CKRecordValue
        groupRecord["weekStartDay"] = 1 as CKRecordValue
        groupRecord["maxMembers"] = 2 as CKRecordValue
        groupRecord["inviteCode"] = inviteCode as CKRecordValue

        let memberRecordID = CKRecord.ID(recordName: myMemberID.uuidString, zoneID: zoneID)
        let memberRecord = CKRecord(recordType: "Member", recordID: memberRecordID)
        memberRecord["groupRef"] = CKRecord.Reference(recordID: groupRecordID, action: .none)
        memberRecord["displayName"] = trimmedName as CKRecordValue
        memberRecord["weeklyGoal"] = weeklyGoal as CKRecordValue
        memberRecord["role"] = "owner" as CKRecordValue
        memberRecord["timezone"] = TimeZone.current.identifier as CKRecordValue
        memberRecord["joinedAt"] = Date.now as CKRecordValue
        if let userRecordName {
            memberRecord["userRecordName"] = userRecordName as CKRecordValue
        }

        let share = CKShare(recordZoneID: zoneID)
        share.publicPermission = .readWrite
        share[CKShare.SystemFieldKey.title] = "FitPinky Group" as CKRecordValue

        do {
            try await saveZone(zone, to: container.privateCloudDatabase)
            addDebug("createGroup() saved zone: \(zoneName)")
            let savedRecords = try await saveRecords([groupRecord, memberRecord, share], to: container.privateCloudDatabase)
            addDebug("createGroup() saved group/member/share records")

            guard let savedShare = savedRecords.compactMap({ $0 as? CKShare }).first,
                  let shareURL = savedShare.url else {
                throw CloudKitServiceError.groupCreationFailed
            }
            addDebug("createGroup() got CKShare URL")

            let inviteCodeRecordID = CKRecord.ID(recordName: inviteCode)
            let inviteCodeRecord = try await container.publicCloudDatabase.record(for: inviteCodeRecordID)
            inviteCodeRecord["shareURL"] = shareURL.absoluteString as CKRecordValue
            inviteCodeRecord["creatorName"] = trimmedName as CKRecordValue
            inviteCodeRecord["status"] = "active" as CKRecordValue
            _ = try await container.publicCloudDatabase.save(inviteCodeRecord)
            addDebug("createGroup() activated invite code in public DB")

            try await createInitialWeeklyGoal(
                pairID: groupID,
                ownerGoal: weeklyGoal,
                partnerGoal: weeklyGoal,
                weekStartDay: 1,
                zoneID: zoneID,
                database: container.privateCloudDatabase
            )
            addDebug("createGroup() created initial WeeklyGoal")

            groupZoneID = zoneID
            groupZoneLocation = .privateDB
            memberCount = 1

            pair = Pair(
                id: groupID,
                userAId: myMemberID,
                userBId: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
                weekStartDay: 1,
                inviteCode: inviteCode
            )
            currentUser = UserProfile(
                id: myMemberID,
                pairId: groupID,
                displayName: trimmedName,
                weeklyGoal: weeklyGoal
            )
            partner = UserProfile(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
                pairId: groupID,
                displayName: "Waiting for partner",
                weeklyGoal: weeklyGoal
            )

            try await fetchAllRecords()
            hasGroup = false

            UserDefaults.standard.set(inviteCode, forKey: Self.pendingInviteCodeKey)
            addDebug("createGroup() success; waiting for partner join")
            return inviteCode
        } catch {
            addDebug("createGroup() failed: \(debugDescription(for: error))")
            handleError(error)
            if let cloudError = error as? CloudKitServiceError {
                throw cloudError
            }
            throw mapCKError(error)
        }
    }

    /// Join group: look up invite code in public DB, accept CKShare, create Member
    func joinGroup(code: String, displayName: String, weeklyGoal: Int) async throws {
        let normalizedCode = code
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedCode.isEmpty, !trimmedName.isEmpty else {
            throw CloudKitServiceError.inviteCodeNotFound
        }
        addDebug("joinGroup() start: code=\(normalizedCode), name=\(trimmedName), goal=\(weeklyGoal)")

        do {
            let inviteCodeRecord = try await fetchActiveInviteCodeRecord(code: normalizedCode)
            addDebug("joinGroup() invite code found and active")

            guard let expiresAt = inviteCodeRecord["expiresAt"] as? Date else {
                throw CloudKitServiceError.inviteCodeNotFound
            }
            guard expiresAt > Date.now else {
                throw CloudKitServiceError.inviteCodeExpired
            }
            addDebug("joinGroup() invite code valid until \(expiresAt.ISO8601Format())")

            guard let shareURLString = inviteCodeRecord["shareURL"] as? String,
                  let shareURL = URL(string: shareURLString) else {
                throw CloudKitServiceError.shareAcceptFailed
            }
            addDebug("joinGroup() loaded share URL from invite record")

            let metadata = try await fetchShareMetadata(from: shareURL)
            addDebug("joinGroup() fetched share metadata")
            try await acceptShare(metadata)
            addDebug("joinGroup() accepted CKShare")

            let shareZoneName = metadata.share.recordID.zoneID.zoneName
            try await discoverGroupZone(preferShared: true, preferredZoneName: shareZoneName)

            guard let zoneID = groupZoneID else {
                throw CloudKitServiceError.shareAcceptFailed
            }
            groupZoneLocation = .sharedDB
            addDebug("joinGroup() discovered shared zone: \(zoneID.zoneName)")

            let database = activeGroupDatabase
            let groupRecordName = String(zoneID.zoneName.dropFirst("FitPinkyGroup_".count))
            let groupRecordID = CKRecord.ID(recordName: groupRecordName, zoneID: zoneID)
            let groupRecord = try await database.record(for: groupRecordID)

            let userRecordName = try? await container.userRecordID().recordName
            let memberRecord = try await upsertMemberRecord(
                in: zoneID,
                database: database,
                groupRecordID: groupRecordID,
                userRecordName: userRecordName,
                displayName: trimmedName,
                weeklyGoal: weeklyGoal
            )
            addDebug("joinGroup() created/updated member record: \(memberRecord.recordID.recordName)")

            let currentMemberID = memberRecord.recordID.recordName
            let ownerID = groupRecord["userAId"] as? String
            let existingUserB = groupRecord["userBId"] as? String
            if existingUserB == nil || existingUserB == ownerID || existingUserB?.isEmpty == true {
                groupRecord["userBId"] = currentMemberID as CKRecordValue
                _ = try await database.save(groupRecord)
            }

            try await updateCurrentWeekGoalForJoiner(
                zoneID: zoneID,
                database: database,
                groupRecordID: groupRecordID,
                joinerID: currentMemberID,
                joinerGoal: weeklyGoal
            )

            inviteCodeRecord["status"] = "accepted" as CKRecordValue
            inviteCodeRecord["acceptedAt"] = Date.now as CKRecordValue
            _ = try await container.publicCloudDatabase.save(inviteCodeRecord)
            addDebug("joinGroup() marked invite code accepted")

            try await fetchAllRecords()
            hasGroup = memberCount >= 2
            addDebug("joinGroup() success: members=\(memberCount), hasGroup=\(hasGroup)")
        } catch {
            addDebug("joinGroup() failed: \(debugDescription(for: error))")
            handleError(error)
            if let cloudError = error as? CloudKitServiceError {
                throw cloudError
            }
            throw mapCKError(error)
        }
    }

    /// Poll for partner joining the shared zone
    func checkForPartner() async -> Bool {
        guard let zoneID = groupZoneID else { return false }
        let database = activeGroupDatabase

        do {
            let query = CKQuery(recordType: "Member", predicate: NSPredicate(value: true))
            let (results, _) = try await database.records(
                matching: query,
                inZoneWith: zoneID,
                resultsLimit: 10
            )

            memberCount = results.count
            if memberCount >= 2 {
                try await fetchAllRecords()
                hasGroup = true
                UserDefaults.standard.removeObject(forKey: Self.pendingInviteCodeKey)
                addDebug("checkForPartner() partner found; members=\(memberCount)")
                return true
            }

            hasGroup = false
            addDebug("checkForPartner() still waiting; members=\(memberCount)")
            return false
        } catch {
            addDebug("checkForPartner() failed: \(debugDescription(for: error))")
            handleError(error)
            return false
        }
    }

    // MARK: - 3AM Rule

    /// Workouts logged between midnight and 3AM count for the previous day.
    private func effectiveWorkoutDate(for date: Date = .now) -> Date {
        let hour = Calendar.current.component(.hour, from: date)
        if hour < 3 {
            return Calendar.current.date(byAdding: .day, value: -1, to: date)!.calendarDate
        }
        return date.calendarDate
    }

    // MARK: - CloudKit Internals

    private func discoverGroupZone(
        preferShared: Bool = false,
        preferredZoneName: String? = nil
    ) async throws {
        if preferShared {
            if let zone = try await findGroupZone(in: container.sharedCloudDatabase, preferredZoneName: preferredZoneName) {
                groupZoneID = zone.zoneID
                groupZoneLocation = .sharedDB
                addDebug("discoverGroupZone() found shared zone: \(zone.zoneID.zoneName)")
                return
            }
            if let zone = try await findGroupZone(in: container.privateCloudDatabase, preferredZoneName: preferredZoneName) {
                groupZoneID = zone.zoneID
                groupZoneLocation = .privateDB
                addDebug("discoverGroupZone() fell back to private zone: \(zone.zoneID.zoneName)")
                return
            }
        } else {
            if let zone = try await findGroupZone(in: container.privateCloudDatabase, preferredZoneName: preferredZoneName) {
                groupZoneID = zone.zoneID
                groupZoneLocation = .privateDB
                addDebug("discoverGroupZone() found private zone: \(zone.zoneID.zoneName)")
                return
            }
            if let zone = try await findGroupZone(in: container.sharedCloudDatabase, preferredZoneName: preferredZoneName) {
                groupZoneID = zone.zoneID
                groupZoneLocation = .sharedDB
                addDebug("discoverGroupZone() found shared zone: \(zone.zoneID.zoneName)")
                return
            }
        }

        groupZoneID = nil
        addDebug("discoverGroupZone() found no matching FitPinky group zone")
    }

    private func findGroupZone(
        in database: CKDatabase,
        preferredZoneName: String?
    ) async throws -> CKRecordZone? {
        let zones = try await database.allRecordZones()

        if let preferredZoneName,
           let exactMatch = zones.first(where: { $0.zoneID.zoneName == preferredZoneName }) {
            return exactMatch
        }

        return zones.first(where: { $0.zoneID.zoneName.hasPrefix("FitPinkyGroup_") })
    }

    private func fetchAllRecords() async throws {
        guard let zoneID = groupZoneID else { return }
        let database = activeGroupDatabase

        try await fetchGroupRecord(zoneID: zoneID, database: database)
        try await fetchMemberRecords(zoneID: zoneID, database: database)
        do {
            try await fetchWeeklyGoalRecords(zoneID: zoneID, database: database)
        } catch {
            addDebug("fetchAllRecords() weekly goal fetch failed: \(debugDescription(for: error))")
        }
        do {
            try await fetchWorkoutRecords(zoneID: zoneID, database: database)
        } catch {
            addDebug("fetchAllRecords() workout fetch failed: \(debugDescription(for: error))")
        }
        addDebug("fetchAllRecords() done: members=\(memberCount), goals=\(weeklyGoals.count), workouts=\(workouts.count)")
    }

    private func fetchGroupRecord(zoneID: CKRecordZone.ID, database: CKDatabase) async throws {
        let prefix = "FitPinkyGroup_"
        guard zoneID.zoneName.hasPrefix(prefix) else {
            throw CloudKitServiceError.recordNotFound
        }

        let groupRecordName = String(zoneID.zoneName.dropFirst(prefix.count))
        let groupRecordID = CKRecord.ID(recordName: groupRecordName, zoneID: zoneID)
        let groupRecord = try await database.record(for: groupRecordID)
        pair = pairFromRecord(groupRecord)
        addDebug("fetchGroupRecord() loaded group via record ID \(groupRecordName)")
    }

    private func fetchMemberRecords(zoneID: CKRecordZone.ID, database: CKDatabase) async throws {
        var members: [(profile: UserProfile, userRecordName: String?)] = []
        let zeroUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        let memberIDs = Array(Set([pair.userAId, pair.userBId])).filter { $0 != zeroUUID }

        for memberID in memberIDs {
            let recordID = CKRecord.ID(recordName: memberID.uuidString, zoneID: zoneID)
            do {
                let record = try await database.record(for: recordID)
                let profile = userProfileFromRecord(record)
                let userRecordName = record["userRecordName"] as? String
                members.append((profile, userRecordName))
            } catch let ckError as CKError where ckError.code == .unknownItem {
                addDebug("fetchMemberRecords() member record missing for \(memberID.uuidString)")
                continue
            }
        }

        memberCount = members.count
        addDebug("fetchMemberRecords() loaded \(memberCount) members via direct IDs")

        let iCloudRecordName = try? await container.userRecordID().recordName

        if let iCloudRecordName,
           let me = members.first(where: { $0.userRecordName == iCloudRecordName })?.profile {
            currentUser = me
        } else if let fallback = members.first?.profile {
            currentUser = fallback
        }

        if let foundPartner = members
            .map(\.profile)
            .first(where: { $0.id != currentUser.id }) {
            partner = foundPartner
        } else {
            partner = UserProfile(
                id: currentUser.id,
                pairId: currentUser.pairId,
                displayName: "Waiting for partner",
                weeklyGoal: currentUser.weeklyGoal,
                timezone: currentUser.timezone
            )
        }
    }

    private func fetchWeeklyGoalRecords(zoneID: CKRecordZone.ID, database: CKDatabase) async throws {
        let query = CKQuery(recordType: "WeeklyGoal", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "weekStart", ascending: false)]
        let (results, _) = try await database.records(
            matching: query,
            inZoneWith: zoneID,
            resultsLimit: 100
        )

        var goals: [WeeklyGoal] = []
        for (_, result) in results {
            let record = try result.get()
            goals.append(weeklyGoalFromRecord(record))
        }
        weeklyGoals = goals
    }

    private func fetchWorkoutRecords(zoneID: CKRecordZone.ID, database: CKDatabase) async throws {
        let query = CKQuery(recordType: "Workout", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "loggedAt", ascending: false)]
        let (results, _) = try await database.records(
            matching: query,
            inZoneWith: zoneID,
            resultsLimit: 500
        )

        var fetchedWorkouts: [Workout] = []
        for (_, result) in results {
            let record = try result.get()
            fetchedWorkouts.append(workoutFromRecord(record))
        }
        workouts = fetchedWorkouts
    }

    private func createInitialWeeklyGoal(
        pairID: UUID,
        ownerGoal: Int,
        partnerGoal: Int,
        weekStartDay: Int,
        zoneID: CKRecordZone.ID,
        database: CKDatabase
    ) async throws {
        let weekStart = Date.now.startOfWeek(weekStartDay: weekStartDay)
        let weeklyGoalID = UUID()

        let goalRecord = CKRecord(
            recordType: "WeeklyGoal",
            recordID: CKRecord.ID(recordName: weeklyGoalID.uuidString, zoneID: zoneID)
        )
        goalRecord["weeklyGoalId"] = weeklyGoalID.uuidString as CKRecordValue
        goalRecord["groupRef"] = CKRecord.Reference(
            recordID: CKRecord.ID(recordName: pairID.uuidString, zoneID: zoneID),
            action: .none
        )
        goalRecord["weekStart"] = weekStart as CKRecordValue
        goalRecord["goalUserA"] = ownerGoal as CKRecordValue
        goalRecord["goalUserB"] = partnerGoal as CKRecordValue
        goalRecord["wagerText"] = "" as CKRecordValue

        _ = try await database.save(goalRecord)
    }

    private func updateCurrentWeekGoalForJoiner(
        zoneID: CKRecordZone.ID,
        database: CKDatabase,
        groupRecordID: CKRecord.ID,
        joinerID: String,
        joinerGoal: Int
    ) async throws {
        let query = CKQuery(recordType: "WeeklyGoal", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "weekStart", ascending: false)]
        let (results, _) = try await database.records(
            matching: query,
            inZoneWith: zoneID,
            resultsLimit: 1
        )

        guard let (_, firstResult) = results.first else { return }
        let latestGoal = try firstResult.get()

        let groupRecord = try await database.record(for: groupRecordID)
        let ownerID = groupRecord["userAId"] as? String
        let goalField = (ownerID == joinerID) ? "goalUserA" : "goalUserB"

        latestGoal[goalField] = joinerGoal as CKRecordValue
        _ = try await database.save(latestGoal)
    }

    private func fetchActiveInviteCodeRecord(code: String) async throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: code)
        do {
            let record = try await container.publicCloudDatabase.record(for: recordID)
            let status = (record["status"] as? String)?.lowercased()
            guard status == "active" else {
                throw CloudKitServiceError.inviteCodeNotFound
            }
            return record
        } catch let ckError as CKError where ckError.code == .unknownItem {
            throw CloudKitServiceError.inviteCodeNotFound
        }
    }

    private func upsertMemberRecord(
        in zoneID: CKRecordZone.ID,
        database: CKDatabase,
        groupRecordID: CKRecord.ID,
        userRecordName: String?,
        displayName: String,
        weeklyGoal: Int
    ) async throws -> CKRecord {
        let preferredMemberID = stableMemberID(for: userRecordName)
        if let preferredMemberID {
            let preferredRecordID = CKRecord.ID(recordName: preferredMemberID.uuidString, zoneID: zoneID)
            do {
                let existing = try await database.record(for: preferredRecordID)
                existing["displayName"] = displayName as CKRecordValue
                existing["weeklyGoal"] = weeklyGoal as CKRecordValue
                existing["timezone"] = TimeZone.current.identifier as CKRecordValue
                existing["role"] = "member" as CKRecordValue
                if existing["joinedAt"] == nil {
                    existing["joinedAt"] = Date.now as CKRecordValue
                }
                existing["groupRef"] = CKRecord.Reference(recordID: groupRecordID, action: .none)
                if let userRecordName {
                    existing["userRecordName"] = userRecordName as CKRecordValue
                }
                addDebug("upsertMemberRecord() updated existing member \(preferredMemberID.uuidString)")
                return try await database.save(existing)
            } catch let ckError as CKError where ckError.code == .unknownItem {
                addDebug("upsertMemberRecord() no existing member for \(preferredMemberID.uuidString), creating")
            }
        }

        let newMemberID = preferredMemberID ?? UUID()
        let newRecord = CKRecord(
            recordType: "Member",
            recordID: CKRecord.ID(recordName: newMemberID.uuidString, zoneID: zoneID)
        )
        newRecord["groupRef"] = CKRecord.Reference(recordID: groupRecordID, action: .none)
        newRecord["displayName"] = displayName as CKRecordValue
        newRecord["weeklyGoal"] = weeklyGoal as CKRecordValue
        newRecord["role"] = "member" as CKRecordValue
        newRecord["timezone"] = TimeZone.current.identifier as CKRecordValue
        newRecord["joinedAt"] = Date.now as CKRecordValue
        if let userRecordName {
            newRecord["userRecordName"] = userRecordName as CKRecordValue
        }
        addDebug("upsertMemberRecord() created member \(newMemberID.uuidString)")
        return try await database.save(newRecord)
    }

    private func reserveInviteCode() async throws -> String {
        for _ in 0..<20 {
            let code = generateInviteCode()
            let record = CKRecord(
                recordType: "InviteCode",
                recordID: CKRecord.ID(recordName: code)
            )
            record["code"] = code as CKRecordValue
            record["status"] = "pending" as CKRecordValue
            record["expiresAt"] = Date.now.addingTimeInterval(48 * 60 * 60) as CKRecordValue

            do {
                _ = try await container.publicCloudDatabase.save(record)
                addDebug("reserveInviteCode() reserved code \(code)")
                return code
            } catch let error as CKError where error.code == .serverRecordChanged {
                addDebug("reserveInviteCode() collision for \(code), retrying")
                continue
            }
        }
        addDebug("reserveInviteCode() exhausted attempts")
        throw CloudKitServiceError.groupCreationFailed
    }

    private func generateInviteCode(length: Int = 6) -> String {
        String((0..<length).map { _ in Self.inviteCodeCharacters.randomElement()! })
    }

    private func stableMemberID(for userRecordName: String?) -> UUID? {
        guard let userRecordName, !userRecordName.isEmpty else { return nil }
        let digest = SHA256.hash(data: Data(userRecordName.utf8))
        let bytes = Array(digest)
        guard bytes.count >= 16 else { return nil }
        let uuid = UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
        return uuid
    }

    private func fetchShareMetadata(from url: URL) async throws -> CKShare.Metadata {
        addDebug("fetchShareMetadata() requesting metadata from share URL")
        let operation = CKFetchShareMetadataOperation(shareURLs: [url])
        operation.shouldFetchRootRecord = true
        operation.qualityOfService = .userInitiated

        return try await withCheckedThrowingContinuation { continuation in
            var fetchedMetadata: CKShare.Metadata?

            operation.perShareMetadataResultBlock = { _, result in
                if case .success(let metadata) = result {
                    fetchedMetadata = metadata
                }
            }
            operation.fetchShareMetadataResultBlock = { result in
                switch result {
                case .success:
                    if let metadata = fetchedMetadata {
                        self.addDebug("fetchShareMetadata() success")
                        continuation.resume(returning: metadata)
                    } else {
                        self.addDebug("fetchShareMetadata() missing metadata in success response")
                        continuation.resume(throwing: CloudKitServiceError.shareAcceptFailed)
                    }
                case .failure(let error):
                    self.addDebug("fetchShareMetadata() failed: \(self.debugDescription(for: error))")
                    continuation.resume(throwing: error)
                }
            }
            container.add(operation)
        }
    }

    private func acceptShare(_ metadata: CKShare.Metadata) async throws {
        addDebug("acceptShare() submitting CKAcceptSharesOperation")
        let operation = CKAcceptSharesOperation(shareMetadatas: [metadata])
        operation.qualityOfService = .userInitiated

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.acceptSharesResultBlock = { result in
                switch result {
                case .success:
                    self.addDebug("acceptShare() success")
                    continuation.resume()
                case .failure(let error):
                    self.addDebug("acceptShare() failed: \(self.debugDescription(for: error))")
                    continuation.resume(throwing: error)
                }
            }
            container.add(operation)
        }
    }

    private func saveZone(_ zone: CKRecordZone, to database: CKDatabase) async throws {
        let (saveResults, _) = try await database.modifyRecordZones(
            saving: [zone],
            deleting: []
        )
        if case .failure(let error) = saveResults[zone.zoneID] {
            throw error
        }
    }

    private func saveRecords(_ records: [CKRecord], to database: CKDatabase) async throws -> [CKRecord] {
        let (saveResults, _) = try await database.modifyRecords(
            saving: records,
            deleting: [],
            savePolicy: .allKeys
        )
        var saved: [CKRecord] = []
        for record in records {
            switch saveResults[record.recordID] {
            case .success(let savedRecord):
                saved.append(savedRecord)
            case .failure(let error):
                throw error
            case .none:
                throw CloudKitServiceError.groupCreationFailed
            }
        }
        return saved
    }

    // MARK: - CKRecord ↔ Model Mapping

    private static let partnerPlaceholderID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    private func pairFromRecord(_ record: CKRecord) -> Pair {
        let userA = UUID(uuidString: record["userAId"] as? String ?? "") ?? UUID()
        let userB = UUID(uuidString: record["userBId"] as? String ?? "") ?? Self.partnerPlaceholderID

        return Pair(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            userAId: userA,
            userBId: userB,
            weekStartDay: record["weekStartDay"] as? Int ?? 1,
            inviteCode: record["inviteCode"] as? String ?? "",
            createdAt: record.creationDate ?? .now
        )
    }

    private func userProfileFromRecord(_ record: CKRecord) -> UserProfile {
        UserProfile(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            pairId: UUID(uuidString: (record["groupRef"] as? CKRecord.Reference)?.recordID.recordName ?? "") ?? pair.id,
            displayName: record["displayName"] as? String ?? "Unknown",
            weeklyGoal: record["weeklyGoal"] as? Int ?? 4,
            timezone: record["timezone"] as? String ?? TimeZone.current.identifier
        )
    }

    private func weeklyGoalFromRecord(_ record: CKRecord) -> WeeklyGoal {
        var result: WeekResult?
        if let resultString = record["result"] as? String {
            result = WeekResult(rawValue: resultString)
        }

        return WeeklyGoal(
            id: UUID(uuidString: record["weeklyGoalId"] as? String ?? record.recordID.recordName) ?? UUID(),
            pairId: UUID(uuidString: (record["groupRef"] as? CKRecord.Reference)?.recordID.recordName ?? "") ?? pair.id,
            weekStart: record["weekStart"] as? Date ?? .now,
            goalUserA: record["goalUserA"] as? Int ?? 4,
            goalUserB: record["goalUserB"] as? Int ?? 4,
            wagerText: record["wagerText"] as? String ?? "",
            result: result
        )
    }

    private func workoutFromRecord(_ record: CKRecord) -> Workout {
        Workout(
            id: UUID(uuidString: record["workoutId"] as? String ?? record.recordID.recordName) ?? UUID(),
            userId: UUID(uuidString: (record["memberRef"] as? CKRecord.Reference)?.recordID.recordName ?? "") ?? UUID(),
            pairId: UUID(uuidString: (record["groupRef"] as? CKRecord.Reference)?.recordID.recordName ?? "") ?? pair.id,
            weeklyGoalId: UUID(uuidString: (record["weeklyGoalRef"] as? CKRecord.Reference)?.recordID.recordName ?? "") ?? UUID(),
            photoRecordName: record.recordID.recordName,
            caption: record["caption"] as? String,
            loggedAt: record["loggedAt"] as? Date ?? .now,
            workoutDate: record["workoutDate"] as? Date ?? .now
        )
    }

    private func nudgeFromRecord(_ record: CKRecord) -> Nudge {
        Nudge(
            id: UUID(uuidString: record["nudgeId"] as? String ?? record.recordID.recordName) ?? UUID(),
            senderId: UUID(uuidString: (record["senderRef"] as? CKRecord.Reference)?.recordID.recordName ?? "") ?? UUID(),
            pairId: UUID(uuidString: (record["groupRef"] as? CKRecord.Reference)?.recordID.recordName ?? "") ?? pair.id,
            message: record["message"] as? String ?? "",
            sentAt: record["sentAt"] as? Date ?? .now,
            ckRecordName: record.recordID.recordName
        )
    }

    // MARK: - Delta Sync

    private var serverChangeToken: CKServerChangeToken? {
        get {
            guard let zoneID = groupZoneID,
                  let data = UserDefaults.standard.data(forKey: Self.changeTokenKeyPrefix + zoneID.zoneName) else { return nil }
            return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
        }
        set {
            guard let zoneID = groupZoneID else { return }
            if let token = newValue,
               let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) {
                UserDefaults.standard.set(data, forKey: Self.changeTokenKeyPrefix + zoneID.zoneName)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.changeTokenKeyPrefix + zoneID.zoneName)
            }
        }
    }

    func performDeltaSync() async {
        guard let zoneID = groupZoneID else { return }
        let database = activeGroupDatabase

        addDebug("performDeltaSync() starting")

        do {
            var moreComing = true
            while moreComing {
                moreComing = try await fetchZoneChanges(zoneID: zoneID, database: database)
            }
            initialSyncComplete = true
            await ensureCurrentWeekGoal()
            addDebug("performDeltaSync() completed")
        } catch let ckError as CKError where ckError.code == .changeTokenExpired {
            addDebug("performDeltaSync() token expired, doing full fetch")
            serverChangeToken = nil
            do {
                try await fetchAllRecords()
                initialSyncComplete = true
            } catch {
                addDebug("performDeltaSync() full re-fetch failed: \(debugDescription(for: error))")
            }
        } catch {
            addDebug("performDeltaSync() failed: \(debugDescription(for: error))")
            handleError(error)
        }
    }

    private func fetchZoneChanges(zoneID: CKRecordZone.ID, database: CKDatabase) async throws -> Bool {
        let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration(
            previousServerChangeToken: serverChangeToken
        )

        let operation = CKFetchRecordZoneChangesOperation(
            recordZoneIDs: [zoneID],
            configurationsByRecordZoneID: [zoneID: config]
        )
        operation.qualityOfService = .userInitiated

        var changedRecords: [CKRecord] = []
        var deletedRecordIDs: [(CKRecord.ID, CKRecord.RecordType)] = []
        var hasMoreComing = false
        var zoneError: Error?

        return try await withCheckedThrowingContinuation { continuation in
            operation.recordWasChangedBlock = { _, result in
                if case .success(let record) = result {
                    changedRecords.append(record)
                }
            }

            operation.recordWithIDWasDeletedBlock = { recordID, recordType in
                deletedRecordIDs.append((recordID, recordType))
            }

            operation.recordZoneFetchResultBlock = { _, result in
                switch result {
                case .success(let (token, _, moreComing)):
                    hasMoreComing = moreComing
                    // Token stored temporarily; will be persisted on MainActor below
                    let tokenData = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
                    if let tokenData {
                        UserDefaults.standard.set(tokenData, forKey: Self.changeTokenKeyPrefix + zoneID.zoneName)
                    }
                case .failure(let error):
                    zoneError = error
                }
            }

            operation.fetchRecordZoneChangesResultBlock = { [weak self] result in
                switch result {
                case .success:
                    if let zoneError {
                        continuation.resume(throwing: zoneError)
                        return
                    }
                    let changed = changedRecords
                    let deleted = deletedRecordIDs
                    let more = hasMoreComing
                    Task { @MainActor [weak self] in
                        self?.processChangedRecords(changed)
                        self?.processDeletedRecords(deleted)
                        continuation.resume(returning: more)
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            database.add(operation)
        }
    }

    @MainActor
    private func processChangedRecords(_ records: [CKRecord]) {
        for record in records {
            switch record.recordType {
            case "Group":
                pair = pairFromRecord(record)
                addDebug("deltaSync: updated Group")

            case "Member":
                let profile = userProfileFromRecord(record)
                if profile.id == currentUser.id {
                    currentUser = profile
                } else {
                    partner = profile
                    if memberCount < 2 {
                        memberCount = 2
                        hasGroup = true
                    }
                }
                addDebug("deltaSync: updated Member \(profile.displayName)")

            case "WeeklyGoal":
                let goal = weeklyGoalFromRecord(record)
                if let index = weeklyGoals.firstIndex(where: { $0.id == goal.id }) {
                    weeklyGoals[index] = goal
                } else {
                    weeklyGoals.append(goal)
                }
                addDebug("deltaSync: updated WeeklyGoal")

            case "Workout":
                var workout = workoutFromRecord(record)
                if let index = workouts.firstIndex(where: { $0.id == workout.id }) {
                    // Preserve in-memory photoData from local capture
                    if workout.photoData == nil {
                        workout.photoData = workouts[index].photoData
                    }
                    workouts[index] = workout
                } else {
                    workouts.append(workout)
                    if workout.userId != currentUser.id && initialSyncComplete {
                        postPartnerWorkoutNotification(partnerName: partner.displayName)
                    }
                }
                addDebug("deltaSync: updated Workout")

            case "Nudge":
                let nudge = nudgeFromRecord(record)
                if !nudges.contains(where: { $0.id == nudge.id }) {
                    nudges.append(nudge)
                    if nudge.senderId != currentUser.id && initialSyncComplete {
                        let senderName = nudge.senderId == partner.id ? partner.displayName : "Partner"
                        postNudgeNotification(senderName: senderName, message: nudge.message)
                    }
                }
                addDebug("deltaSync: processed Nudge")

            default:
                break
            }
        }
    }

    @MainActor
    private func processDeletedRecords(_ deletions: [(CKRecord.ID, CKRecord.RecordType)]) {
        for (recordID, recordType) in deletions {
            switch recordType {
            case "Workout":
                workouts.removeAll { $0.photoRecordName == recordID.recordName || $0.id.uuidString == recordID.recordName }
            case "WeeklyGoal":
                weeklyGoals.removeAll { $0.id.uuidString == recordID.recordName }
            case "Nudge":
                nudges.removeAll { $0.ckRecordName == recordID.recordName }
            default:
                break
            }
        }
    }

    // MARK: - Nudge

    func sendNudge(message: String) async throws {
        guard let zoneID = groupZoneID else { return }
        let database = activeGroupDatabase

        let nudge = Nudge(
            senderId: currentUser.id,
            pairId: pair.id,
            message: message
        )

        let record = CKRecord(recordType: "Nudge", recordID: CKRecord.ID(zoneID: zoneID))
        record["nudgeId"] = nudge.id.uuidString as CKRecordValue
        record["senderRef"] = CKRecord.Reference(
            recordID: CKRecord.ID(recordName: currentUser.id.uuidString, zoneID: zoneID),
            action: .none
        )
        record["groupRef"] = CKRecord.Reference(
            recordID: CKRecord.ID(recordName: pair.id.uuidString, zoneID: zoneID),
            action: .none
        )
        record["message"] = message as CKRecordValue
        record["sentAt"] = Date.now as CKRecordValue

        do {
            try await database.save(record)
            nudges.append(nudge)
            addDebug("sendNudge() saved: \(message)")
        } catch {
            handleError(error)
            throw mapCKError(error)
        }
    }

    // MARK: - Push Notification Subscriptions

    func setupSubscriptions() async {
        guard let zoneID = groupZoneID else { return }

        let key = Self.subscriptionSetupKey + "_" + zoneID.zoneName
        guard !UserDefaults.standard.bool(forKey: key) else {
            addDebug("setupSubscriptions() already created")
            return
        }

        let database = activeGroupDatabase
        let subscriptionID = "fitpinky-zone-changes-\(groupZoneLocation == .privateDB ? "private" : "shared")"

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true

        let subscription: CKSubscription
        if groupZoneLocation == .sharedDB {
            // Shared DB doesn't support CKDatabaseSubscription; use zone subscription
            let zoneSub = CKRecordZoneSubscription(zoneID: zoneID, subscriptionID: subscriptionID)
            zoneSub.notificationInfo = notificationInfo
            subscription = zoneSub
        } else {
            let dbSub = CKDatabaseSubscription(subscriptionID: subscriptionID)
            dbSub.notificationInfo = notificationInfo
            subscription = dbSub
        }

        do {
            try await database.save(subscription)
            UserDefaults.standard.set(true, forKey: key)
            addDebug("setupSubscriptions() created subscription (\(groupZoneLocation == .sharedDB ? "zone" : "database"))")
        } catch let error as CKError where error.code == .serverRejectedRequest {
            // Subscription already exists — mark as done
            UserDefaults.standard.set(true, forKey: key)
            addDebug("setupSubscriptions() subscription likely already exists")
        } catch {
            // Don't mark as done so it retries next launch
            addDebug("setupSubscriptions() failed: \(debugDescription(for: error))")
        }
    }

    // MARK: - Local Notifications

    private func postPartnerWorkoutNotification(partnerName: String) {
        let content = UNMutableNotificationContent()
        content.title = "FitPinky"
        content.body = "\(partnerName) just showed up! \u{1F4AA}"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "workout-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func postNudgeNotification(senderName: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = "FitPinky"
        content.body = "\(senderName) says: \(message)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "nudge-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func postWeekResultNotification(result: WeekResult, wagerText: String) {
        let content = UNMutableNotificationContent()
        content.title = "FitPinky"

        switch result {
        case .bothHit:
            content.body = "Week's over! You both hit your goals \u{1F389}"
        case .aOwes:
            let name = currentUser.id == pair.userAId ? currentUser.displayName : partner.displayName
            content.body = wagerText.isEmpty ? "\(name) missed their goal this week" : "\(name) owes: \(wagerText)"
        case .bOwes:
            let name = currentUser.id == pair.userBId ? currentUser.displayName : partner.displayName
            content.body = wagerText.isEmpty ? "\(name) missed their goal this week" : "\(name) owes: \(wagerText)"
        case .bothMissed:
            content.body = "You both missed your goals this week \u{1F605}"
        }

        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "week-result-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Diagnostics

    private func addDebug(_ message: String) {
        let timestamp = Self.debugTimestampFormatter.string(from: Date())
        let line = "[\(timestamp)] \(message)"
        logger.debug("\(line, privacy: .public)")
        Task { @MainActor [weak self] in
            self?.appendDebugLine(line)
        }
    }

    private func appendDebugLine(_ line: String) {
        onboardingDebugLog.append(line)
        if onboardingDebugLog.count > 120 {
            onboardingDebugLog.removeFirst(onboardingDebugLog.count - 120)
        }
    }

    private func debugDescription(for error: Error) -> String {
        if let ckError = error as? CKError {
            return "CKError(\(ckError.code.rawValue)): \(ckError.localizedDescription)"
        }
        if let cloudError = error as? CloudKitServiceError {
            return "CloudKitServiceError: \(cloudError.localizedDescription)"
        }
        return error.localizedDescription
    }

    private static let debugTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    // MARK: - Error Handling

    private func handleError(_ error: Error) {
        addDebug("handleError(): \(debugDescription(for: error))")
        let mapped = mapCKError(error)
        cloudKitError = mapped
        switch mapped {
        case .networkUnavailable:
            isOffline = true
        case .notAuthenticated:
            needsAuthentication = true
        case .quotaExceeded:
            isStorageFull = true
        default:
            break
        }
    }
}
