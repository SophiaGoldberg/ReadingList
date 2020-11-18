import Foundation
import CoreData
import CloudKit
import os.log

/*
protocol UpstreamChangeProcessor: CustomDebugStringConvertible {
    var batchSize: Int { get set }
    func processLocalChanges(_ objects: [NSManagedObject], completion: @escaping () -> Void)
    var unprocessedChangedObjectsRequest: NSFetchRequest<NSFetchRequestResult> { get }
}

class ErrorHandlingChangeProcessor<LocalType> where LocalType: NSManagedObject {
    var batchSize: Int = 100

    final func processLocalChanges(_ objects: [NSManagedObject], completion: @escaping () -> Void) {
        guard let localObjects = objects as? [LocalType] else { fatalError("Incorrect object type") }
        processLocalChanges(localObjects, completion: completion)
    }

    final var unprocessedChangedObjectsRequest: NSFetchRequest<NSFetchRequestResult> {
        return unprocessedChangedLocalObjectsRequest as! NSFetchRequest<NSFetchRequestResult>
    }

    var unprocessedChangedLocalObjectsRequest: NSFetchRequest<LocalType> {
        fatalError("Must be overriden")
    }

    func processLocalChanges(_ localObjects: [LocalType], completion: @escaping () -> Void) {
        fatalError("Must be overridden")
    }

    func handleItemLevelError(_ ckError: CKError, forItem: LocalType) {
        fatalError("Must be overriden")
    }

    /// Returns non-nil if inner errors need to be handled
    func handleBatchLevelError(_ error: Error, uploads: [LocalType]) -> [AnyHashable: Error]? {
        if let ckError = error as? CKError {
            os_log("Handling CKError with code %s", type: .info, ckError.code.name)

            switch ckError.strategy {
            case .disableSync:
                NotificationCenter.default.postCloudSyncDisableNotification()
            case .retryLater:
                NotificationCenter.default.postCloudSyncPauseNotification(restartAfter: ckError.retryAfterSeconds)
            case .retrySmallerBatch:
                let newBatchSize = self.batchSize / 2
                os_log("Reducing upload batch size from %d to %d", self.batchSize, newBatchSize)
                self.batchSize = newBatchSize
            case .handleInnerErrors:
                return ckError.partialErrorsByItemID
            case .handleConcurrencyErrors:
                // This should only happen if there is 1 upload instruction; otherwise, the batch should have failed
                if uploads.count == 1 {
                    handleItemLevelError(ckError, forItem: uploads[0])
                } else {
                    os_log("Unexpected error code %s occurred when pushing %d upload instructions", type: .error, ckError.code.name, uploads.count)
                    NotificationCenter.default.postCloudSyncDisableNotification()
                }
            case .disableSyncUnexpectedError, .resetChangeToken:
                os_log("Unexpected code returned in error response to upload instruction: %s", type: .fault, ckError.code.name)
                NotificationCenter.default.postCloudSyncDisableNotification()
            }
        } else {
            os_log("Unexpected error (non CK) occurred pushing upload instructions: %{public}s", type: .error, error.localizedDescription)
            NotificationCenter.default.postCloudSyncDisableNotification()
        }
        return nil
    }

    final func handleItemLevelError(_ error: Error, forItem item: LocalType) {
        if let ckError = error as? CKError {
            os_log("Handling concurrency CKError with code %s", type: .info, ckError.code.name)
            handleItemLevelError(ckError, forItem: item)
        } else {
            os_log("Unexpected error (non CK) occurred pushing upload instructions: %{public}s", type: .error, error.localizedDescription)
            NotificationCenter.default.post(name: NSNotification.Name.DisableCloudSync, object: error)
        }
    }
}
*/
