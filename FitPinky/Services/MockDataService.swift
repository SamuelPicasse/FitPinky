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
    var hasGroup: Bool = true
    var isLoading: Bool = false
    var needsAuthentication: Bool = false
    var onboardingDebugLog: [String] = []

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

        let cal = Calendar.current
        let weekStart = Date.now.startOfWeek()

        // --- Week definitions (current + 5 past) ---
        let currentWeek = WeeklyGoal(
            pairId: pairId, weekStart: weekStart,
            goalUserA: 4, goalUserB: 4,
            wagerText: "Loser buys sushi 🍣"
        )
        let week1 = WeeklyGoal(
            pairId: pairId,
            weekStart: cal.date(byAdding: .day, value: -7, to: weekStart)!,
            goalUserA: 4, goalUserB: 4,
            wagerText: "Loser does the dishes for a week",
            result: .bothHit
        )
        let week2 = WeeklyGoal(
            pairId: pairId,
            weekStart: cal.date(byAdding: .day, value: -14, to: weekStart)!,
            goalUserA: 5, goalUserB: 3,
            wagerText: "Loser cooks dinner 🍝",
            result: .bothHit
        )
        let week3 = WeeklyGoal(
            pairId: pairId,
            weekStart: cal.date(byAdding: .day, value: -21, to: weekStart)!,
            goalUserA: 4, goalUserB: 4,
            wagerText: "Loser plans date night 🌹",
            result: .aOwes
        )
        let week4 = WeeklyGoal(
            pairId: pairId,
            weekStart: cal.date(byAdding: .day, value: -28, to: weekStart)!,
            goalUserA: 4, goalUserB: 4,
            wagerText: "Loser gives a massage 💆",
            result: .bOwes
        )
        let week5 = WeeklyGoal(
            pairId: pairId,
            weekStart: cal.date(byAdding: .day, value: -35, to: weekStart)!,
            goalUserA: 4, goalUserB: 3,
            wagerText: "Loser buys coffee all week ☕️",
            result: .bothMissed
        )

        self.weeklyGoals = [currentWeek, week1, week2, week3, week4, week5]

        // --- Helper to create workouts for a week ---
        let colors: [UIColor] = [.systemIndigo, .systemTeal, .systemPurple, .systemPink, .systemOrange, .systemCyan, .systemMint]
        var colorIndex = 0
        func nextColor() -> UIColor {
            let c = colors[colorIndex % colors.count]
            colorIndex += 1
            return c
        }

        let captions = [
            "Leg day 🦵", "Morning run", "Push day", "Yoga flow 🧘", "HIIT session",
            "Chest & back", "Spin class 🚴", "Rest day jk", "Arms day 💪", "Swimming 🏊",
            "Pilates", "Boxing 🥊", "Trail run 🏃", "CrossFit", "Dance class 💃"
        ]
        var captionIndex = 0
        func nextCaption() -> String {
            let c = captions[captionIndex % captions.count]
            captionIndex += 1
            return c
        }

        func makeWorkouts(
            week: WeeklyGoal,
            sammyDays: [Int],
            jottaDays: [Int]
        ) -> [Workout] {
            var result: [Workout] = []
            for dayOffset in sammyDays {
                let date = cal.date(byAdding: .day, value: dayOffset, to: week.weekStart)!
                let hour = 7 + (dayOffset * 2) % 12
                let loggedAt = cal.date(bySettingHour: hour, minute: 30, second: 0, of: date)!
                result.append(Workout(
                    userId: userAId, pairId: pairId, weeklyGoalId: week.id,
                    photoData: MockDataService.makeSamplePhoto(color: nextColor()),
                    caption: nextCaption(), loggedAt: loggedAt, workoutDate: date
                ))
            }
            for dayOffset in jottaDays {
                let date = cal.date(byAdding: .day, value: dayOffset, to: week.weekStart)!
                let hour = 8 + (dayOffset * 3) % 10
                let loggedAt = cal.date(bySettingHour: hour, minute: 15, second: 0, of: date)!
                result.append(Workout(
                    userId: userBId, pairId: pairId, weeklyGoalId: week.id,
                    photoData: MockDataService.makeSamplePhoto(color: nextColor()),
                    caption: nextCaption(), loggedAt: loggedAt, workoutDate: date
                ))
            }
            return result
        }

        var allWorkouts: [Workout] = []

        // Current week: Sammy 2 days, Jotta 1 day
        allWorkouts += makeWorkouts(week: currentWeek, sammyDays: [0, 1], jottaDays: [0])

        // Week 1 ago: both hit 4/4
        allWorkouts += makeWorkouts(week: week1, sammyDays: [0, 1, 3, 5], jottaDays: [0, 2, 4, 6])

        // Week 2 ago: Sammy 5/5, Jotta 3/3
        allWorkouts += makeWorkouts(week: week2, sammyDays: [0, 1, 2, 4, 6], jottaDays: [1, 3, 5])

        // Week 3 ago: Sammy 3/4 (missed), Jotta 4/4
        allWorkouts += makeWorkouts(week: week3, sammyDays: [0, 2, 5], jottaDays: [0, 2, 4, 6])

        // Week 4 ago: Sammy 4/4, Jotta 3/4 (missed)
        allWorkouts += makeWorkouts(week: week4, sammyDays: [0, 1, 3, 5], jottaDays: [1, 3, 6])

        // Week 5 ago: Sammy 2/4, Jotta 1/3 (both missed)
        allWorkouts += makeWorkouts(week: week5, sammyDays: [2, 5], jottaDays: [3])

        self.workouts = allWorkouts
        self.nudges = []
    }

    // MARK: - DataServiceProtocol

    func setup() async {}

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

    func loadPhoto(for workout: Workout) async -> Data? {
        workout.photoData
    }

    /// Count unique workout days for a user in a given week
    func workoutDays(for userId: UUID, in weeklyGoal: WeeklyGoal) -> Int {
        let weekWorkouts = workouts.filter {
            $0.weeklyGoalId == weeklyGoal.id && $0.userId == userId
        }
        let uniqueDays = Set(weekWorkouts.map { $0.workoutDate.calendarDate })
        return uniqueDays.count
    }

    private static func makeSamplePhoto(color: UIColor, size: CGSize = CGSize(width: 200, height: 200)) -> Data? {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        return image.jpegData(compressionQuality: 0.5)
    }
}
