import Foundation

protocol DataServiceProtocol {
    func setup() async
    func getCurrentUser() -> UserProfile
    func getPartner() -> UserProfile
    func getPair() -> Pair
    func getCurrentWeek() -> WeeklyGoal
    func getWorkouts(for weeklyGoal: WeeklyGoal) -> [Workout]
    func logWorkout(photoData: Data, caption: String?) async throws
    func updateWager(text: String) async throws
    func getStreak() -> Int
    func getBestStreak() -> Int
    func getPastWeeks() -> [WeeklyGoal]
    func updateDisplayName(_ name: String) async throws
    func updateWeeklyGoal(_ days: Int) async throws
    func updateWeekStartDay(_ day: Int) async throws
    func latestWorkout(for userId: UUID) -> Workout?
    func hasLoggedToday() -> Bool
    func workoutDays(for userId: UUID, in weeklyGoal: WeeklyGoal) -> Int
    func loadPhoto(for workout: Workout) async -> Data?
}

#if targetEnvironment(simulator)
typealias ActiveDataService = MockDataService
#else
typealias ActiveDataService = CloudKitService
#endif
