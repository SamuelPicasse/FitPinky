import Foundation

enum WeekResult: String, Codable {
    case bothHit = "both_hit"
    case aOwes = "a_owes"
    case bOwes = "b_owes"
    case bothMissed = "both_missed"
}

struct WeeklyGoal: Identifiable, Codable {
    let id: UUID
    var pairId: UUID
    var weekStart: Date
    var goalUserA: Int
    var goalUserB: Int
    var wagerText: String
    var result: WeekResult?

    init(
        id: UUID = UUID(),
        pairId: UUID,
        weekStart: Date,
        goalUserA: Int = 4,
        goalUserB: Int = 4,
        wagerText: String = "",
        result: WeekResult? = nil
    ) {
        self.id = id
        self.pairId = pairId
        self.weekStart = weekStart
        self.goalUserA = goalUserA
        self.goalUserB = goalUserB
        self.wagerText = wagerText
        self.result = result
    }
}
