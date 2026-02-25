import Foundation

struct Pair: Identifiable, Codable {
    let id: UUID
    var userAId: UUID
    var userBId: UUID
    var weekStartDay: Int // 1=Monday, 7=Sunday
    var inviteCode: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        userAId: UUID,
        userBId: UUID,
        weekStartDay: Int = 1,
        inviteCode: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.userAId = userAId
        self.userBId = userBId
        self.weekStartDay = weekStartDay
        self.inviteCode = inviteCode
        self.createdAt = createdAt
    }
}
