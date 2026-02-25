import Foundation

struct UserProfile: Identifiable, Codable {
    let id: UUID
    var pairId: UUID
    var displayName: String
    var weeklyGoal: Int // 1–7 days per week
    var timezone: String

    init(
        id: UUID = UUID(),
        pairId: UUID,
        displayName: String,
        weeklyGoal: Int = 4,
        timezone: String = TimeZone.current.identifier
    ) {
        self.id = id
        self.pairId = pairId
        self.displayName = displayName
        self.weeklyGoal = weeklyGoal
        self.timezone = timezone
    }
}
