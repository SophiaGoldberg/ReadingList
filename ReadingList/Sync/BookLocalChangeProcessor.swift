import Foundation
import CoreData
import PersistedPropertyWrapper
import os.log

@available(iOS 13.0, *)
struct BookLocalChangeProcessor {
    let syncContext: NSManagedObjectContext
    let historyFetcher: PersistentHistoryFetcher
    let remote: BookCloudKitRemote
    
    init(syncContext: NSManagedObjectContext, remote: BookCloudKitRemote) {
        self.syncContext = syncContext
        self.historyFetcher = PersistentHistoryFetcher(context: syncContext)
        self.remote = remote
    }

    @Persisted("localChangeToken")
    var tokenData: Data?

    var historyToken: NSPersistentHistoryToken? {
        get {
            guard let tokenData = tokenData else { return nil }
            return try! NSKeyedUnarchiver.unarchivedObject(ofClass: NSPersistentHistoryToken.self, from: tokenData)
        }
        set {
            if let newValue = newValue {
                tokenData = try! NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: true)
            } else {
                tokenData = nil
            }
        }
    }
    
    func processLocalChanges() {
        if let historyToken = historyToken {
            
        }
    }

    private func processPendingLocalChanges(fromToken transactionToken: NSPersistentHistoryToken) {
        os_log(.debug, "Fetching local transactions")
        let transactions = historyFetcher.fetch(fromToken: transactionToken)
        os_log(.debug, "%d transactions found in history", transactions.count)
        
        for (index, transaction) in transactions.enumerated() {
            syncContext.perform {
                os_log(.debug, "Processing transaction %d", index)
                guard let changeSet = transaction.changes else { return }
                
                // Inserts
                let inserts = changeSet.filter { $0.changeType == .insert }
                let insertedObjects = inserts.map(\.changedObjectID)
                    .compactMap { self.syncContext.object(with: $0) as? Book }
                    .filter { !$0.isDeleted }
                let insertionRecords = insertedObjects.map { $0.recordForInsert(into: self.remote.bookZoneID) }
                os_log(.debug, "Uploading %d inserts", insertedObjects.count)
                
                let uploadOperation = self.remote.upload(insertionRecords) { err in
                    self.syncContext.performAndSaveIfChanged {
                        for (ckRecord, book) in zip(insertionRecords, insertedObjects) {
                            book.setSystemFields(ckRecord)
                            book.remoteIdentifier = ckRecord.recordID.recordName
                        }
                    }
                }
                
                // Updates
                let updates = changeSet.filter { $0.changeType == .update }
                    .compactMap { change -> (NSPersistentHistoryChange, Book)? in
                        guard let book = self.syncContext.object(with: change.changedObjectID) as? Book else { return nil }
                        return (change, book)
                    }
                    .filter { !$0.1.isDeleted }
                let updateRecordsAndBooks = updates.compactMap { (change, book) -> (CKRecord, Book)? in
                    guard let updatedProperties = change.updatedProperties else { return nil }
                    guard let ckrecord = book.recordForUpdate(changedCoreDataKeys: updatedProperties.map(\.name)) else { return nil }
                    for prop in updatedProperties {
                        guard let ckRecordKey = Book.CKRecordKey(rawValue: prop.name) else { continue }
                        ckrecord[ckRecordKey.rawValue] = book.getValue(for: ckRecordKey)
                    }
                    return (ckrecord, book)
                }
                os_log(.debug, "Uploading %d updates", updateRecordsAndBooks.count)
                let updateOpertion = self.remote.upload(updateRecordsAndBooks.map(\.0), dependentOperations: [uploadOperation]) { err in
                    self.syncContext.performAndSaveIfChanged {
                        for (ckRecord, book) in updateRecordsAndBooks {
                            // TODO: Needed?
                            book.setSystemFields(ckRecord)
                            book.remoteIdentifier = ckRecord.recordID.recordName
                        }
                    }
                }

                // Deletes
                let deletes = changeSet.filter { $0.changeType == .delete }
                    .compactMap(\.tombstone)
                    .compactMap { $0["remoteIdentifier"] as? String }
                    .map { CKRecord.ID(recordName: $0, zoneID: self.remote.bookZoneID) }
                os_log(.debug, "Uploading %d deletes", deletes.count)
                self.remote.remove(deletes, dependentOperations: [updateOpertion]) { error in
                    guard let self = self else { return }
                    self.syncContext.perform {
                        os_log(.debug, "Storing new transaction token")
                        self.fromToken = transaction.token
                        self.viewContext.performAndWait {
                            self.viewContext.mergeChanges(fromContextDidSave: transaction.objectIDNotification())
                        }
                    }
                }
            }
        }
    }
}
