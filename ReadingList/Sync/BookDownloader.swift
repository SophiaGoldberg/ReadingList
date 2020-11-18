import Foundation
import CoreData
import UIKit
import CloudKit
import os.log

@available(iOS 13.0, *)
struct BookRemoteChangeProcessor {

    let context: NSManagedObjectContext
    let remote: BookCloudKitRemote
    weak var syncCoordinator: SyncCoordinator?

    func processRemoteChanges(callback: ((UIBackgroundFetchResult) -> Void)? = nil) {
        let storedChangeToken = ChangeToken.get(fromContext: context, for: remote.bookZoneID)
        remote.fetchRecordChanges(changeToken: storedChangeToken?.changeToken,
                                  recordDeletion: processRemoteDeletion,
                                  recordChange: processRemoteChange,
                                  changeTokenUpdate: onChangeTokenUpdate) { changeToken, error, hasChanges in
            self.context.perform {
                if let error = error {
                    self.handleFetchChangesError(error: error, changeToken: storedChangeToken)
                    callback?(.failed)
                } else if hasChanges {
                    if let changeToken = changeToken {
                        os_log("Updating change token", log: .syncDownstream, type: .info)
                        let changeTokenToPersist = storedChangeToken ?? ChangeToken(context: self.context, zoneID: self.remote.bookZoneID)
                        changeTokenToPersist.changeToken = changeToken
                    }
                    self.context.saveAndLogIfErrored()
                    callback?(.newData)
                } else {
                    callback?(.noData)
                }
            }
        }
    }

    private func onChangeTokenUpdate(_ newToken: CKServerChangeToken) {
        handleChangeTokenChange(newToken, zone: remote.bookZoneID)
    }

    private func handleFetchChangesError(error: Error, changeToken: ChangeToken?) {
        if let ckError = error as? CKError {
            switch ckError.strategy {
            case .resetChangeToken:
                os_log("resetChangeToken error received: deleting change token...", log: .syncDownstream, type: .error)
                self.context.perform {
                    changeToken!.deleteAndSave()
                }
            case .disableSync:
                NotificationCenter.default.post(name: .DisableCloudSync, object: ckError)
            case .disableSyncUnexpectedError:
                os_log("Unexpected code returned in error response to deletion instruction: %s", type: .fault, ckError.code.name)
                NotificationCenter.default.post(name: .DisableCloudSync, object: ckError)
            case .retryLater:
                NotificationCenter.default.post(name: .PauseCloudSync, object: ckError.retryAfterSeconds)
            case .retrySmallerBatch, .handleInnerErrors, .handleConcurrencyErrors:
                fatalError("Unexpected strategy for failing change fetch: \(ckError.strategy), for error code \(ckError.code)")
            }
        } else {
            os_log("Unexpected error: %{public}s", type: .error, error.localizedDescription)
        }
    }

    func processRemoteDeletion(_ id: CKRecord.ID) {
        context.perform {
            if let localBook = self.locallyPresentBook(withId: id) {
                os_log("Deleting found local book", log: .syncDownstream, type: .info)
                localBook.delete()
            }
        }
    }

    func processRemoteChange(_ ckRecord: CKRecord) {
        context.perform {
            self.downloadBook(ckRecord)
        }
    }

    func handleChangeTokenChange(_ changeToken: CKServerChangeToken, zone: CKRecordZone.ID) {
        context.perform {
            let changeTokenToPersist: ChangeToken
            if let changeToken = ChangeToken.get(fromContext: self.context, for: zone) {
                os_log("Updating existing persisted change token", log: .syncDownstream, type: .info)
                changeTokenToPersist = changeToken
            } else {
                os_log("No existing persisted change token exists - creating one", log: .syncDownstream, type: .info)
                changeTokenToPersist = ChangeToken(context: self.context, zoneID: zone)
            }
            changeTokenToPersist.changeToken = changeToken
            self.context.saveAndLogIfErrored()
        }
    }

    private func downloadBook(_ remoteBook: CKRecord) {
        if remoteBook.recordType == Book.ckRecordType {
            if let localBook = self.lookupLocalBook(for: remoteBook) {
                os_log("Updating existing local book with remote record %{public}s", log: .syncDownstream, type: .info, remoteBook.recordID.recordName)
                let keysPendingUpdate = syncCoordinator?.pendingRemoteUpdates?.updates[remoteBook.recordID.recordName]?.changedKeys().compactMap(Book.CKRecordKey.init(rawValue:))
                localBook.update(from: remoteBook, excluding: keysPendingUpdate)
            } else {
                os_log("Creating new book from remote record %{public}s", log: .syncDownstream, type: .info, remoteBook.recordID.recordName)
                let book = Book(context: self.context)
                book.update(from: remoteBook, excluding: nil)
            }
        }
    }

    private func lookupLocalBook(for remoteBook: CKRecord) -> Book? {
        let remoteIdLookup = NSManagedObject.fetchRequest(Book.self)
        remoteIdLookup.predicate = Book.withRemoteIdentifier(remoteBook.recordID.recordName)
        remoteIdLookup.fetchLimit = 1
        if let book = (try! context.fetch(remoteIdLookup)).first {
            os_log("Found local book with specified remote identifier %{public}s", log: .syncDownstream, type: .debug, remoteBook.recordID.recordName)
            return book
        }

        let localIdLookup = NSManagedObject.fetchRequest(Book.self)
        localIdLookup.fetchLimit = 1
        localIdLookup.predicate = Book.candidateBookForRemoteIdentifier(remoteBook.recordID)
        if let book = (try! context.fetch(localIdLookup)).first {
            os_log("Found candidate local book corresponding to remote identifier %{public}s", log: .syncDownstream, type: .debug, remoteBook.recordID.recordName)
            return book
        }

        return nil
    }

    private func locallyPresentBook(withId id: CKRecord.ID) -> Book? {
        os_log("Fetching local book corresponding to supplied remote identifier %{public}s", log: .syncDownstream, type: .debug, id.recordName)
        let fetchRequest = NSManagedObject.fetchRequest(Book.self)
        fetchRequest.predicate = Book.withRemoteIdentifier(id.recordName)
        return (try! context.fetch(fetchRequest)).first
    }
}
