import Foundation
import CoreData
import CloudKit
import os.log
/*
 Reimplement without the PendingRemoteDeletionItem object
class BookDeleter: ErrorHandlingChangeProcessor<PendingRemoteDeletionItem>, UpstreamChangeProcessor {

    init(_ context: NSManagedObjectContext, _ remote: BookCloudKitRemote) {
        self.context = context
        self.remote = remote
        super.init()
        self.batchSize = 400
    }

    let debugDescription = String(describing: BookDeleter.self)
    let context: NSManagedObjectContext
    let remote: BookCloudKitRemote

    override func processLocalChanges(_ pendingRemoteDeletes: [PendingRemoteDeletionItem], completion: @escaping () -> Void) {
        os_log("Beginning push of %d delete instructions", type: .info, pendingRemoteDeletes.count)
        remote.remove(pendingRemoteDeletes.map { $0.recordID }) { error in
            self.context.perform {
                os_log("Remote delete complete. Processing results...", type: .info)
                self.processDeletionResults(pendingRemoteDeletes, error: error)
                completion()
            }
        }
    }

    private func processDeletionResults(_ deletionInstructions: [PendingRemoteDeletionItem], error: Error?) {
        var innerErrors: [AnyHashable: Error]?
        if let error = error {
            innerErrors = handleBatchLevelError(error, uploads: deletionInstructions)
            if innerErrors == nil {
                os_log("Batch-level error did not produce any item-level errors")
                return
            }
        } else {
            innerErrors = nil
        }

        for deletionInstruction in deletionInstructions {
            if let ckError = innerErrors?[deletionInstruction.recordID] as? CKError {
                handleItemLevelError(ckError, forItem: deletionInstruction)
            } else {
                deletionInstruction.delete()
            }
        }

        let deletedRemoteDeletionItemCount = deletionInstructions.filter { $0.isDeleted }.count
        if deletedRemoteDeletionItemCount != 0 {
            os_log("Deleted %d local remote delete instructions", type: .info, deletedRemoteDeletionItemCount)
            self.context.saveAndLogIfErrored()
        }
    }

    override func handleItemLevelError(_ ckError: CKError, forItem item: PendingRemoteDeletionItem) {
        switch ckError.code {
        case .unknownItem:
            os_log("Remote deletion of record %{public}s failed - the item could not be found. Deleting instruction.", item.recordID.recordName)
            item.delete()
        case .batchRequestFailed:
            return
        default:
            os_log("Unexpected record-level error during item deletion: %s", type: .error, ckError.code.name)
        }
    }

    override var unprocessedChangedLocalObjectsRequest: NSFetchRequest<PendingRemoteDeletionItem> {
        return NSManagedObject.fetchRequest(PendingRemoteDeletionItem.self, limit: batchSize)
    }
}
*/
