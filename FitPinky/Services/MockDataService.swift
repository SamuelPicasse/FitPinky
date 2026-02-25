import Foundation
import Observation
import UIKit

@Observable
final class MockDataService: DataServiceProtocol {
    var pair: Pair
    var currentUser: UserProfile
    var partner: UserProfile
    var weeklyGoals: [WeeklyGoal]
    var workouts: [Workout]
    var nudges: [Nudge]

    init() {
        let pairId = UUID()
        let userAId = UUID()
        let userBId = UUID()

        self.pair = Pair(
            id: pairId,
            userAId: userAId,
            userBId: userBId,
            weekStartDay: 1,
            inviteCode: "SWEAT1"
        )

        let sammy = UserProfile(
            id: userAId,
            pairId: pairId,
            displayName: "Sammy",
            weeklyGoal: 4
        )
        let jotta = UserProfile(
            id: userBId,
            pairId: pairId,
            displayName: "Jotta",
            weeklyGoal: 4
        )
        self.currentUser = sammy
        self.partner = jotta

        let weekStart = Date.now.startOfWeek()
        let currentWeek = WeeklyGoal(
            pairId: pairId,
            weekStart: weekStart,
            goalUserA: 4,
            goalUserB: 4,
            wagerText: "Loser buys sushi 🍣"
        )

        // A completed past week
        let lastWeekStart = Calendar.current.date(byAdding: .day, value: -7, to: weekStart)!
        let lastWeek = WeeklyGoal(
            pairId: pairId,
            weekStart: lastWeekStart,
            goalUserA: 4,
            goalUserB: 4,
            wagerText: "Loser does the dishes for a week",
            result: .bothHit
        )

        self.weeklyGoals = [currentWeek, lastWeek]

        // Sample workouts for the current week
        let today = Date.now
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: today)!

        self.workouts = [
            Workout(
                userId: userAId,
                pairId: pairId,
                weeklyGoalId: currentWeek.id,
                caption: "Leg day 🦵",
                loggedAt: twoDaysAgo,
                workoutDate: twoDaysAgo
            ),
            Workout(
                userId: userBId,
                pairId: pairId,
                weeklyGoalId: currentWeek.id,
                caption: "Morning run",
                loggedAt: twoDaysAgo,
                workoutDate: twoDaysAgo
            ),
            Workout(
                userId: userAId,
                pairId: pairId,
                weeklyGoalId: currentWeek.id,
                caption: "Push day",
                loggedAt: yesterday,
                workoutDate: yesterday
            ),
        ]

        self.nudges = []
    }

    // MARK: - DataServiceProtocol

    func getCurrentUser() -> UserProfile { currentUser }
    func getPartner() -> UserProfile { partner }
    func getPair() -> Pair { pair }

    func getCurrentWeek() -> WeeklyGoal {
        weeklyGoals.first { $0.result == nil } ?? weeklyGoals[0]
    }

    func getWorkouts(for weeklyGoal: WeeklyGoal) -> [Workout] {
        workouts.filter { $0.weeklyGoalId == weeklyGoal.id }
    }

    func logWorkout(photoData: Data, caption: String?) async throws {
        let currentWeek = getCurrentWeek()
        let workout = Workout(
            userId: currentUser.id,
            pairId: pair.id,
            weeklyGoalId: currentWeek.id,
            photoData: photoData,
            caption: caption,
            loggedAt: .now,
            workoutDate: .now
        )
        workouts.append(workout)
    }

    func updateWager(text: String) async throws {
        guard let index = weeklyGoals.firstIndex(where: { $0.result == nil }) else { return }
        weeklyGoals[index].wagerText = text
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

    func getPastWeeks() -> [WeeklyGoal] {
        weeklyGoals
            .filter { $0.result != nil }
            .sorted { $0.weekStart > $1.weekStart }
    }

    func updateDisplayName(_ name: String) async throws {
        currentUser.displayName = name
    }

    func updateWeeklyGoal(_ days: Int) async throws {
        currentUser.weeklyGoal = days
        // Sync to the active WeeklyGoal
        guard let index = weeklyGoals.firstIndex(where: { $0.result == nil }) else { return }
        weeklyGoals[index].goalUserA = days
    }

    func updateWeekStartDay(_ day: Int) async throws {
        pair.weekStartDay = day
    }

    func latestWorkout(for userId: UUID) -> Workout? {
        let currentWeek = getCurrentWeek()
        return workouts
            .filter { $0.weeklyGoalId == currentWeek.id && $0.userId == userId }
            .sorted { $0.loggedAt > $1.loggedAt }
            .first
    }

    func hasLoggedToday() -> Bool {
        let today = Date.now.calendarDate
        return workouts.contains {
            $0.userId == currentUser.id && $0.workoutDate.calendarDate == today
        }
    }

    /// Count unique workout days for a user in a given week
    func workoutDays(for userId: UUID, in weeklyGoal: WeeklyGoal) -> Int {
        let weekWorkouts = workouts.filter {
            $0.weeklyGoalId == weeklyGoal.id && $0.userId == userId
        }
        let uniqueDays = Set(weekWorkouts.map { $0.workoutDate.calendarDate })
        return uniqueDays.count
    }
}
