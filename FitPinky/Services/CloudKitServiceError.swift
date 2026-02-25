import Foundation
import CloudKit

enum CloudKitServiceError: LocalizedError {
    case networkUnavailable
    case notAuthenticated
    case quotaExceeded
    case recordNotFound
    case inviteCodeNotFound
    case inviteCodeExpired
    case shareAcceptFailed
    case groupCreationFailed
    case serverError(String)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "No internet connection. Your workouts will sync when you're back online."
        case .notAuthenticated:
            return "Please sign in to iCloud in Settings to sync your data."
        case .quotaExceeded:
            return "iCloud storage is full. Free up space to continue syncing."
        case .recordNotFound:
            return "The requested data could not be found."
        case .inviteCodeNotFound:
            return "Invite code not found. Please check and try again."
        case .inviteCodeExpired:
            return "This invite code has expired. Ask your partner for a new code."
        case .shareAcceptFailed:
            return "Could not accept the shared group. Please try again."
        case .groupCreationFailed:
            return "Could not create your group right now. Please try again."
        case .serverError(let message):
            return "Server error: \(message)"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

func mapCKError(_ error: Error) -> CloudKitServiceError {
    guard let ckError = error as? CKError else {
        return .unknown(error)
    }
    switch ckError.code {
    case .networkUnavailable, .networkFailure:
        return .networkUnavailable
    case .notAuthenticated:
        return .notAuthenticated
    case .quotaExceeded:
        return .quotaExceeded
    case .unknownItem:
        return .recordNotFound
    case .serverRejectedRequest, .serviceUnavailable, .requestRateLimited:
        return .serverError(ckError.localizedDescription)
    default:
        return .unknown(error)
    }
}
