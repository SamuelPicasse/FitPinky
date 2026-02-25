import Foundation

struct Workout: Identifiable, Codable {
    let id: UUID
    var userId: UUID
    var pairId: UUID
    var weeklyGoalId: UUID
    var photoData: Data?
    var photoRecordName: String?
    var caption: String?
    var loggedAt: Date
    var workoutDate: Date

    var hasPhoto: Bool { photoData != nil || photoRecordName != nil }

    init(
        id: UUID = UUID(),
        userId: UUID,
        pairId: UUID,
        weeklyGoalId: UUID,
        photoData: Data? = nil,
        photoRecordName: String? = nil,
        caption: String? = nil,
        loggedAt: Date = .now,
        workoutDate: Date = .now
    ) {
        self.id = id
        self.userId = userId
        self.pairId = pairId
        self.weeklyGoalId = weeklyGoalId
        self.photoData = photoData
        self.photoRecordName = photoRecordName
        self.caption = caption
        self.loggedAt = loggedAt
        self.workoutDate = workoutDate
    }
}
