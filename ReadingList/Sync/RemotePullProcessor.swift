//import Foundation
//import CloudKit
//import CoreData
//import os.log
//import PersistedPropertyWrapper
//
//class RemotePullProcessor {
//    init(remote: BookCloudKitRemote, syncContext: NSManagedObjectContext, delegate: RemotePullProcessorDelegate) {
//        self.remote = remote
//        self.syncContext = syncContext
//        self.delegate = delegate
//    }
//
//    let remote: BookCloudKitRemote
//    let syncContext: NSManagedObjectContext
//    weak var delegate: RemotePullProcessorDelegate?
//
//    @Persisted(archivedDataKey: "sync-server-change-token")
//    var serverChangeToken: CKServerChangeToken?
//
//    func pullOperation() -> CKDatabaseOperation {
//        let operationId = UUID().uuidString
//        let fetchOperation = remote.fetchRecordChangesOperation(
//            changeToken: serverChangeToken,
//            recordDeletion: processRemoteDeletion,
//            recordChange: processRemoteChange(_:),
//            changeTokenUpdate: onChangeTokenUpdate(_:)) { [weak self] error in
//            guard let self = self else { return }
//            if let error = error {
//                self.handleFetchChangesError(error: error)
//            }
//            if self.syncContext.hasChanges {
//                self.syncContext.performAndWait {
//                    self.syncContext.saveAndLogIfErrored()
//                }
//                self.delegate?.onPullSuccess(operationName: operationId)
//            }
//        }
//        fetchOperation.name = operationId
//        return fetchOperation
//    }
//
//    private func onChangeTokenUpdate(_ newToken: CKServerChangeToken) {
//        serverChangeToken = newToken
//    }
//
//    private func handleFetchChangesError(error: Error) {
//        if let ckError = error as? CKError {
//            switch ckError.strategy {
//            case .resetChangeToken:
//                os_log("resetChangeToken error received: deleting change token...", log: .syncDownstream, type: .error)
//                serverChangeToken = nil
//            case .disableSync:
//                NotificationCenter.default.post(name: .DisableCloudSync, object: ckError)
//            case .disableSyncUnexpectedError:
//                os_log("Unexpected code returned in error response to deletion instruction: %s", type: .fault, ckError.code.name)
//                NotificationCenter.default.post(name: .DisableCloudSync, object: ckError)
//            case .retryLater:
//                NotificationCenter.default.post(name: .PauseCloudSync, object: ckError.retryAfterSeconds)
//            case .retrySmallerBatch, .handleInnerErrors, .handleConcurrencyErrors:
//                fatalError("Unexpected strategy for failing change fetch: \(ckError.strategy), for error code \(ckError.code)")
//            }
//        } else {
//            os_log("Unexpected error: %{public}s", type: .error, error.localizedDescription)
//        }
//    }
//
//    func processRemoteDeletion(_ id: CKRecord.ID) {
//        syncContext.performAndWait {
//            if let localBook = self.locallyPresentBook(withId: id) {
//                os_log("Deleting found local book", log: .syncDownstream, type: .info)
//                localBook.delete()
//            }
//        }
//    }
//
//    func processRemoteChange(_ ckRecord: CKRecord) {
//        syncContext.performAndWait {
//            self.downloadBook(ckRecord)
//        }
//    }
//
//    private func downloadBook(_ remoteBook: CKRecord) {
//        if remoteBook.recordType == Book.ckRecordType {
//            if let localBook = self.lookupLocalBook(for: remoteBook) {
//                os_log("Updating existing local book with remote record %{public}s", log: .syncDownstream, type: .info, remoteBook.recordID.recordName)
//                let keysPendingUpdate = delegate?.pendingUpdateRecordKeys(for: remoteBook.recordID.recordName)?.compactMap(Book.CKRecordKey.init(rawValue:))
//                localBook.update(from: remoteBook, excluding: keysPendingUpdate)
//            } else {
//                os_log("Creating new book from remote record %{public}s", log: .syncDownstream, type: .info, remoteBook.recordID.recordName)
//                let book = Book(context: self.syncContext)
//                book.update(from: remoteBook, excluding: nil)
//            }
//        }
//    }
//
//    private func lookupLocalBook(for remoteBook: CKRecord) -> Book? {
//        let remoteIdLookup = NSManagedObject.fetchRequest(Book.self)
//        remoteIdLookup.predicate = Book.withRemoteIdentifier(remoteBook.recordID.recordName)
//        remoteIdLookup.fetchLimit = 1
//        if let book = (try! syncContext.fetch(remoteIdLookup)).first {
//            os_log("Found local book with specified remote identifier %{public}s", log: .syncDownstream, type: .debug, remoteBook.recordID.recordName)
//            return book
//        }
//
//        let localIdLookup = NSManagedObject.fetchRequest(Book.self)
//        localIdLookup.fetchLimit = 1
//        localIdLookup.predicate = Book.candidateBookForRemoteIdentifier(remoteBook.recordID)
//        if let book = (try! syncContext.fetch(localIdLookup)).first {
//            os_log("Found candidate local book corresponding to remote identifier %{public}s", log: .syncDownstream, type: .debug, remoteBook.recordID.recordName)
//            return book
//        }
//
//        return nil
//    }
//
//    private func locallyPresentBook(withId id: CKRecord.ID) -> Book? {
//        os_log("Fetching local book corresponding to supplied remote identifier %{public}s", log: .syncDownstream, type: .debug, id.recordName)
//        let fetchRequest = NSManagedObject.fetchRequest(Book.self)
//        fetchRequest.predicate = Book.withRemoteIdentifier(id.recordName)
//        return (try! syncContext.fetch(fetchRequest)).first
//    }
//}
//
//protocol RemotePullProcessorDelegate: class {
//    func onPullSuccess(operationName: String)
//    func pendingUpdateRecordKeys(for id: String) -> Set<String>?
//}
