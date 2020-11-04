import Foundation
import CloudKit
import os.log

extension CKError {
    enum Strategy {
        case retryLater
        case retrySmallerBatch
        case resetChangeToken
        case disableSync
        case disableSyncUnexpectedError
        case handleInnerErrors
        case handleConcurrencyErrors
    }

    var strategy: Strategy {
        switch self.code {
        // User did something
        case .managedAccountRestricted, .notAuthenticated, .quotaExceeded, .userDeletedZone, .zoneNotFound, .incompatibleVersion:
            return .disableSync

        // Try again later
        case .networkFailure, .networkUnavailable, .serviceUnavailable, .serverResponseLost, .internalError, .operationCancelled,
             .zoneBusy, .requestRateLimited, .assetFileNotFound, .assetNotAvailable, .assetFileModified:
            return .retryLater

        // Try again with smalled batch size
        case .limitExceeded:
            return .retrySmallerBatch

        // Unexpected codes
        case .alreadyShared, .participantMayNeedVerification, .tooManyParticipants, .badContainer, .badDatabase,
             .constraintViolation, .invalidArguments, .missingEntitlement, .referenceViolation,
             .serverRejectedRequest, .resultsTruncated, .permissionFailure:
            return .disableSyncUnexpectedError

        // Delete change token
        case .changeTokenExpired:
            return .resetChangeToken

        // Batch failure
        case .batchRequestFailed, .partialFailure:
            return .handleInnerErrors

        // Handle on case-by-case basis
        case .unknownItem, .serverRecordChanged:
            return .handleConcurrencyErrors
        @unknown default:
            return .retryLater
        }
    }
}

extension CKError.Code {
    /**
     For logging and debugging purposes: a string representation of the enum name.
     */
    var name: String {
        switch self {
        case .internalError: return "internalError"
        case .networkUnavailable: return "networkUnavailable"
        case .networkFailure: return "networkFailure"
        case .badContainer: return "badContainer"
        case .serviceUnavailable: return "serviceUnavailable"
        case .requestRateLimited: return "requestRateLimited"
        case .missingEntitlement: return "missingEntitlement"
        case .notAuthenticated: return "notAuthenticated"
        case .permissionFailure: return "permissionFailure"
        case .unknownItem: return "unknownItem"
        case .invalidArguments: return "invalidArguments"
        case .resultsTruncated: return "resultsTruncated"
        case .serverRecordChanged: return "serverRecordChanged"
        case .serverRejectedRequest: return "serverRejectedRequest"
        case .assetFileNotFound: return "assetFileNotFound"
        case .assetFileModified: return "assetFileModified"
        case .incompatibleVersion: return "incompatibleVersion"
        case .constraintViolation: return "constraintViolation"
        case .operationCancelled: return "operationCancelled"
        case .changeTokenExpired: return "changeTokenExpired"
        case .batchRequestFailed: return "batchRequestFailed"
        case .zoneBusy: return "zoneBusy"
        case .badDatabase: return "badDatabase"
        case .quotaExceeded: return "quotaExceeded"
        case .zoneNotFound: return "zoneNotFound"
        case .limitExceeded: return "limitExceeded"
        case .userDeletedZone: return "userDeletedZone"
        case .tooManyParticipants: return "tooManyParticipants"
        case .alreadyShared: return "alreadyShared"
        case .referenceViolation: return "referenceViolation"
        case .managedAccountRestricted: return "managedAccountRestricted"
        case .participantMayNeedVerification: return "participantMayNeedVerification"
        case .serverResponseLost: return "serverResponseLost"
        case .assetNotAvailable: return "assetNotAvailable"
        case .partialFailure: return "partialFailure"
        @unknown default: return "unknown"
        }
    }
}

extension NSNotification.Name {
    static let DisableCloudSync = Notification.Name("disable-cloud-sync")
    static let PauseCloudSync = Notification.Name("pause-cloud-sync")
}

extension NotificationCenter {
    func postCloudSyncPauseNotification(restartAfter: Double?) {
        let postRestartAfter = restartAfter ?? 10.0
        os_log("Posting SyncCoordinator pause notification, to restart after %d seconds", postRestartAfter)
        NotificationCenter.default.post(name: .PauseCloudSync, object: postRestartAfter)
    }

    func postCloudSyncDisableNotification() {
        os_log("Posting SyncCoordinator stop notification")
        NotificationCenter.default.post(name: .DisableCloudSync, object: nil)
    }
}
