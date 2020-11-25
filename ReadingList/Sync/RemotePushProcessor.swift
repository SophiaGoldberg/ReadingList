import Foundation
import CloudKit
import CoreData
import os.log

class RemotePushProcessor {
    init(remote: BookCloudKitRemote, syncContext: NSManagedObjectContext, delegate: RemotePushProcessorDelegate) {
        self.remote = remote
        self.syncContext = syncContext
        self.delegate = delegate
    }

    let remote: BookCloudKitRemote
    let syncContext: NSManagedObjectContext
    weak var delegate: RemotePushProcessorDelegate?

    func pushOperation(_ remoteUpdate: LocalChangeRemoteUpdateInstruction) -> CKDatabaseOperation {
        let operationId = UUID().uuidString
        let uploadOperation = remote.uploadOperation(recordsToSave: remoteUpdate.allCKRecords(), recordsToDelete: remoteUpdate.allDeletionIDs()) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                self.handleBatchLevelError(error, remoteUpdate: remoteUpdate)
            } else {
                self.delegate?.onPushSuccess(operationName: operationId, remoteUpdate: remoteUpdate)
            }
        }
        uploadOperation.name = operationId
        return uploadOperation
    }
    
    func handleBatchLevelError(_ error: Error, remoteUpdate: LocalChangeRemoteUpdateInstruction) {
        if let ckError = error as? CKError {
            os_log("Handling CKError with code %s", type: .info, ckError.code.name)

            switch ckError.strategy {
            case .disableSync:
                NotificationCenter.default.postCloudSyncDisableNotification()
            case .retryLater:
                NotificationCenter.default.postCloudSyncPauseNotification(restartAfter: ckError.retryAfterSeconds)
            case .retrySmallerBatch:
                //let newBatchSize = self.batchSize / 2
                //os_log("Reducing upload batch size from %d to %d", self.batchSize, newBatchSize)
                //self.batchSize = newBatchSize
                // TODO
                break
            case .handleInnerErrors:
                guard let innerErrors = ckError.partialErrorsByItemID else {
                    assertionFailure("Unexpected nil partialErrorByItemID")
                    return
                }
                for error in innerErrors.values {
                    handleItemLevelError(error, for: remoteUpdate)
                }
            case .handleConcurrencyErrors:
                // This should only happen if there is 1 upload instruction; otherwise, the batch should have failed
                if remoteUpdate.operationCount == 1 {
                    handleItemLevelError(ckError, for: remoteUpdate)
                } else {
                    os_log("Unexpected error code %s occurred when pushing %d upload instructions", type: .error, ckError.code.name, remoteUpdate.operationCount)
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
    }

    func handleItemLevelError(_ error: Error, for item: LocalChangeRemoteUpdateInstruction) {
        if let ckError = error as? CKError {
            os_log("Handling concurrency CKError with code %s", type: .info, ckError.code.name)
            switch ckError.code {
            case .batchRequestFailed:
                // No special handling required.
                break
            case .serverRecordChanged:
                // We have tried to push a delta to the server, but the server record was different.
                // This indicates that there has been some other push to the server which this device has not
                // yet fetched. Our strategy is to wait until we have fetched the latest remove change before
                // pushing this change back. TODO: Consider whether we should persist some delay on this item
                
                /*CKRecordChangedErrorClientRecordKey: A copy of the record the client attempted to save
                 CKRecordChangedErrorServerRecordKey: A copy of the record as it currently exists on the server
                 CKRecordChangedErrorAncestorRecordKey: A copy of the client record without any of the pending changes the client just attempted to save*/
                guard let serverRecord = ckError.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord,
                      let clientRecord = ckError.userInfo[CKRecordChangedErrorClientRecordKey] as? CKRecord else {
                    preconditionFailure()
                }
                for key in clientRecord.changedBookKeys() {
                    if let clientValue = clientRecord[key] as? CKAsset, let clientURL = clientValue.fileURL {
                        let newAssetURL = URL.temporary()
                        do {
                            try FileManager.default.copyItem(at: clientURL, to: newAssetURL)
                            serverRecord[key] = CKAsset(fileURL: newAssetURL)
                        } catch {
                            os_log("Error copying CKAsset file")
                        }
                    } else {
                        serverRecord[key] = clientRecord[key]
                    }
                }
                os_log("Update of record failed as the server record has changed", type: .error)
            case .unknownItem:
                // TODO: Find out whether this occurs when pushing to a deleted item?
                os_log("Remote update of record failed - the item could not be found.")
            default:
                os_log("Unexpected record-level error for record during upload: %{public}s", type: .error, ckError.code.name)
            }
        } else {
            os_log("Unexpected error (non CK) occurred pushing upload instructions: %{public}s", type: .error, error.localizedDescription)
            NotificationCenter.default.post(name: NSNotification.Name.DisableCloudSync, object: error)
        }
    }
}

protocol RemotePushProcessorDelegate: class {
    func onPushSuccess(operationName: String, remoteUpdate: LocalChangeRemoteUpdateInstruction)
}
