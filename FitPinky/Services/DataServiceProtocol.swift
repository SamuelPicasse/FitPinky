import Foundation

protocol DataServiceProtocol {
    func getCurrentUser() -> UserProfile
    func getPartner() -> UserProfile
    func getPair() -> Pair
    func getCurrentWeek() -> WeeklyGoal
    func getWorkouts(for weeklyGoal: WeeklyGoal) -> [Workout]
    func logWorkout(photoData: Data, caption: String?) async throws
    func updateWager(text: String) async throws
    func getStreak() -> Int
    func getPastWeeks() -> [WeeklyGoal]
    func updateDisplayName(_ name: String) async throws
    func updateWeeklyGoal(_ days: Int) async throws
    func updateWeekStartDay(_ day: Int) async throws
    func latestWorkout(for userId: UUID) -> Workout?
    func hasLoggedToday() -> Bool
}
