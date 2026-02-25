import Foundation

struct Nudge: Identifiable, Codable {
    let id: UUID
    var senderId: UUID
    var pairId: UUID
    var message: String
    var sentAt: Date
    var ckRecordName: String?

    init(
        id: UUID = UUID(),
        senderId: UUID,
        pairId: UUID,
        message: String,
        sentAt: Date = .now,
        ckRecordName: String? = nil
    ) {
        self.id = id
        self.senderId = senderId
        self.pairId = pairId
        self.message = message
        self.sentAt = sentAt
        self.ckRecordName = ckRecordName
    }
}
