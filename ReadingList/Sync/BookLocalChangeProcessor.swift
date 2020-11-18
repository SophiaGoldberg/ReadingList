import Foundation
import CoreData
import PersistedPropertyWrapper
import os.log

extension OSLog {
    static let syncLocalChangeProcessor = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "sync_upstream")
}

@available(iOS 13.0, *)
class BookLocalChangeProcessor {
    let syncContext: NSManagedObjectContext
    let historyFetcher: PersistentHistoryFetcher
    let remote: BookCloudKitRemote

    init(syncContext: NSManagedObjectContext, viewContext: NSManagedObjectContext, remote: BookCloudKitRemote) {
        self.syncContext = syncContext
        self.historyFetcher = PersistentHistoryFetcher(context: viewContext)
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

    func getRemoteUpdateInstructions() -> LocalChangeRemoteUpdateInstruction? {
        let transactions: [NSPersistentHistoryTransaction]
        if let historyToken = historyToken {
            transactions = historyFetcher.fetch(fromToken: historyToken)
            os_log(.debug, log: .syncLocalChangeProcessor, "%d transactions retrieved using token", transactions.count)
        } else {
            transactions = historyFetcher.fetch(fromDate: Date().addingTimeInterval(-5))
            os_log(.debug, log: .syncLocalChangeProcessor, "%d transactions retrieved using timespan", transactions.count)
        }

        guard let lastTransaction = transactions.last else { return nil }
        os_log(.debug, log: .syncLocalChangeProcessor, "Processing %d transactions", transactions.count)

        let localChanges = transactions.compactMap { $0.localChangeRepresentations() }.flatMap { $0 }
        return localChanges.remoteInstruction(context: syncContext, zoneId: remote.bookZoneID, finalTransactionToken: lastTransaction.token)
    }

    func performRemoteUpdate(_ remoteUpdate: LocalChangeRemoteUpdateInstruction, completion: @escaping () -> Void) {
        guard !remoteUpdate.isEmpty else {
            completion()
            return
        }

        remote.upload(recordsToSave: remoteUpdate.allCKRecords(), recordsToDelete: remoteUpdate.allDeletionIDs()) { error in
            os_log(.info, log: .syncLocalChangeProcessor, "Remote upload operation response received %s", error != nil ? "(errored)" : "")
            self.historyToken = remoteUpdate.finalTransactionToken
            completion()
        }
    }
}

protocol CKRecordRepresentable {
    static var ckRecordType: String { get }
    var isDeleted: Bool { get }
    func recordForInsert(into zone: CKRecordZone.ID) -> CKRecord
    func recordForUpdate(changedCoreDataKeys: [String]) -> CKRecord?
}

struct LocalChangeRemoteUpdateInstruction: CustomDebugStringConvertible {
    let finalTransactionToken: NSPersistentHistoryToken
    var deletions = Set<String>()
    var updates = [String: CKRecord]()
    var inserts = [String: CKRecord]()
    var isEmpty: Bool { deletions.isEmpty && updates.isEmpty && inserts.isEmpty }

    func allCKRecords() -> [CKRecord] {
        Array(inserts.values) + Array(updates.values)
    }

    func allDeletionIDs() -> [CKRecord.ID] {
        Array(deletions.map { CKRecord.ID(recordName: $0, zoneID: zoneId) })
    }

    let context: NSManagedObjectContext
    let zoneId: CKRecordZone.ID

    var debugDescription: String {
        isEmpty ? "Empty" : "\(updates.count) updates, \(inserts.count) inserts, \(deletions.count) deletions"
    }

    mutating func appendLocalChange(_ localChange: LocalChange) {
        switch localChange {
        case .insert(let id):
            guard let managedObject = context.object(with: id) as? CKRecordRepresentable else { return }
            if managedObject.isDeleted {
                os_log(.error, log: .syncUpstream, "Unexpected deleted object in an Insert operation")
                return
            }
            let ckRecordInsert = managedObject.recordForInsert(into: zoneId)
            inserts[ckRecordInsert.recordID.recordName] = ckRecordInsert
        case .update(let id, let keys):
            guard let managedObject = context.object(with: id) as? CKRecordRepresentable else { return }
            if managedObject.isDeleted {
                os_log(.error, log: .syncUpstream, "Unexpected deleted object in an Insert operation")
                return
            }
            if let ckRecordUpdate = managedObject.recordForUpdate(changedCoreDataKeys: keys) {
                updates[ckRecordUpdate.recordID.recordName] = ckRecordUpdate
            } else {
                os_log(.info, log: .syncUpstream, "Update operation for an object which has not been inserted; inserting instead")
                let ckRecordForInsert = managedObject.recordForInsert(into: zoneId)
                inserts[ckRecordForInsert.recordID.recordName] = ckRecordForInsert
            }
        case .delete(let remoteId):
            // Any insertions followed by deletions can just be skipped
            guard inserts[remoteId] == nil else {
                inserts.removeValue(forKey: remoteId)
                return
            }

            // Any updates aren't necessary, but we still need the deletion
            if updates[remoteId] != nil {
                updates.removeValue(forKey: remoteId)
            }
            deletions.insert(remoteId)
        }
    }
}

enum LocalChange {
    case delete(remoteId: String)
    case update(id: NSManagedObjectID, keys: [String])
    case insert(id: NSManagedObjectID)
}

extension NSPersistentHistoryTransaction {
    func localChangeRepresentations() -> [LocalChange]? {
        guard let changes = changes else { return nil }
        let localChangeRepresentations = changes.compactMap { $0.localChangeRepresentation() }
        if localChangeRepresentations.isEmpty { return nil }
        return localChangeRepresentations
    }
}

extension Array where Element == LocalChange {
    func remoteInstruction(context: NSManagedObjectContext, zoneId: CKRecordZone.ID, finalTransactionToken: NSPersistentHistoryToken) -> LocalChangeRemoteUpdateInstruction {
        var remoteInstruction = LocalChangeRemoteUpdateInstruction(finalTransactionToken: finalTransactionToken, context: context, zoneId: zoneId)
        for item in self {
            remoteInstruction.appendLocalChange(item)
        }
        return remoteInstruction
    }
}

extension NSPersistentHistoryChange {
    func localChangeRepresentation() -> LocalChange? {
        switch changeType {
        case .insert:
            return .insert(id: changedObjectID)
        case .delete:
            guard let remoteId = tombstone?[#keyPath(Book.remoteIdentifier)] as? String else { return nil }
            return .delete(remoteId: remoteId)
        case .update:
            guard let updatedProperties = updatedProperties?.map(\.name) else { return nil }
            return .update(id: changedObjectID, keys: updatedProperties)
        @unknown default:
            os_log(.default, log: .syncLocalChangeProcessor, "Unexpected changeType value %d", changeType.rawValue)
            return nil
        }
    }
}
