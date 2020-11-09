import Foundation
import CoreData
import CloudKit
import os.log

class BookUploader: ErrorHandlingChangeProcessor<Book>, UpstreamChangeProcessor {

    init(_ context: NSManagedObjectContext, _ remote: BookCloudKitRemote) {
        self.context = context
        self.remote = remote
        super.init()
        self.batchSize = 100
    }

    let debugDescription = String(describing: BookUploader.self)
    let context: NSManagedObjectContext
    let remote: BookCloudKitRemote

    override func processLocalChanges(_ books: [Book], completion: @escaping () -> Void) {
        // Map the local Books to upload instructions
        let uploadInstructions = getUploadInstructions(from: books)
        let insertionCount = uploadInstructions.filter { $0.uploadType == .insert }.count
        os_log("Processing %d upload instructions (%d new insertions)", type: .info, uploadInstructions.count, insertionCount)

        // Initiate the upload of the CKRecords
        remote.upload(uploadInstructions.map { $0.ckRecord }) { [unowned self] error in
            self.context.perform {
                os_log("Upload complete. Processing results...", type: .info)
                self.processUploadResults(uploadInstructions, error: error)
                completion()
            }
        }
    }

    private func processUploadResults(_ uploadInstructions: [BookUploadInstruction], error: Error?) {
        let innerErrors: [AnyHashable: Error]?
        if let error = error {
            innerErrors = handleBatchLevelError(error, uploads: uploadInstructions.map { $0.book })
            if innerErrors == nil {
                os_log("Batch-level error did not produce any item-level errors")
                return
            }
        } else {
            innerErrors = nil
        }

        for instruction in uploadInstructions {
            // If the book has since been deleted, ignore it. A remote deletion will (should) be pushed.
            guard !instruction.book.isDeleted else {
                os_log("Local book which triggered remote %s of record %{public}s is deleted. Skipping processing.", instruction.uploadType.description, instruction.ckRecord.recordID.recordName)
                continue
            }

            if let error = innerErrors?[instruction.ckRecord.recordID] {
                handleItemLevelError(error, forItem: instruction.book)
                continue
            }

            // Assign the system fields and remote identifier.
            instruction.book.setSystemFields(instruction.ckRecord)

            // If this was an insertion, then the changed-field bitmask will not have been updated
            // to account for any changes since the upload was initiated. We should check that all in the book
            // have the same value as in the uploaded CKRecord. Those fields which differ should be marked as
            // changed, to be picked up by the next upload cycle.

            // If this was a differential update, then we should check whether the local values of the uploaded
            // fields are the same before we remove them from the changed-field bitmask. We don't need to check
            // any other fields, since the view context will have kept the bitmask up-to-date.

            // TODO: this might all be redundant with persistent history
            switch instruction.uploadType {
            case .insert:
                instruction.book.remoteIdentifier = instruction.ckRecord.recordID.recordName
                let differingKeys = Book.CKRecordKey.allCases.filter {
                    !CKRecord.valuesAreEqual(left: instruction.book.getValue(for: $0), right: instruction.ckRecord[$0])
                }
                if !differingKeys.isEmpty {
                    os_log("%d fields inserted book record %{public}s now differ from local book; updating bitmask.", type: .info, differingKeys.count, instruction.ckRecord.recordID.recordName)
                    //instruction.book.addKeysPendingRemoteUpdate(differingKeys)
                }
            case .update:
                let updatedKeys = instruction.delta.filter {
                    CKRecord.valuesAreEqual(left: instruction.book.getValue(for: $0), right: instruction.ckRecord[$0])
                }
                if updatedKeys.count != instruction.delta.count {
                    os_log("%d of %d updated fields now differ from local book; retaining bitmask", type: .info, instruction.delta.count - updatedKeys.count, updatedKeys.count)
                }
                //instruction.book.subtractKeysPendingRemoteUpdate(updatedKeys)
            }
        }

        self.context.saveAndLogIfErrored()
    }

    override func handleItemLevelError(_ error: CKError, forItem book: Book) {
        switch error.code {
        case .batchRequestFailed:
            // No special handling required.
            break
        case .serverRecordChanged:
            // We have tried to push a delta to the server, but the server record was different.
            // This indicates that there has been some other push to the server which this device has not
            // yet fetched. Our strategy is to wait until we have fetched the latest remove change before
            // pushing this change back. TODO: Consider whether we should persist some delay on this item
            os_log("Update of record %{public}s failed as the server record has changed", type: .error, book.remoteIdentifier ?? "?")
        case .unknownItem:
            // TODO: Find out whether this occurs when pushing to a deleted item?
            os_log("Remote update of record %{public}s failed - the item could not be found.", book.remoteIdentifier ?? "?")
        default:
            os_log("Unexpected record-level error for record %{public}s during upload: %s", type: .error, book.remoteIdentifier ?? "?", error.code.name)
        }
    }

    private func getUploadInstructions(from books: [Book]) -> [BookUploadInstruction] {
        return books.map { book -> BookUploadInstruction in
            let ckRecord: CKRecord
            let uploadType: BookUploadInstruction.UploadType
            if book.remoteIdentifier == nil {
                uploadType = .insert
                ckRecord = book.recordForInsert(into: remote.bookZoneID)
            } else {
                uploadType = .update
                // TODO ckRecord = book.recordForUpdate()
                ckRecord = book.recordForInsert(into: remote.bookZoneID)
            }
            return BookUploadInstruction(uploadType, book: book, ckRecord: ckRecord)
        }
    }

    override var unprocessedChangedLocalObjectsRequest: NSFetchRequest<Book> {
        let fetchRequest = NSManagedObject.fetchRequest(Book.self, limit: self.batchSize)
        fetchRequest.predicate = NSPredicate.or([
            // TODO: Use persistent history instead
            //Book.pendingRemoteUpdatesPredicate,
            NSPredicate(format: "%K = nil", #keyPath(Book.remoteIdentifier))
        ])
        return fetchRequest
    }
}

private struct BookUploadInstruction {
    let uploadType: UploadType
    let book: Book
    let ckRecord: CKRecord
    let delta: [Book.CKRecordKey]

    init(_ uploadType: UploadType, book: Book, ckRecord: CKRecord) {
        self.uploadType = uploadType
        self.book = book
        self.ckRecord = ckRecord
        // The changed keys should be stored now, since we lose that information after the upload has occurred.
        self.delta = ckRecord.changedBookKeys()
    }

    enum UploadType: CustomStringConvertible {
        case insert
        case update

        var description: String {
            switch self {
            case .insert: return "insert"
            case .update: return "update"
            }
        }
    }
}
