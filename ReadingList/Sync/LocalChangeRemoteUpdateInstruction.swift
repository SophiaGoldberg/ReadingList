import Foundation
import CoreData
import os.log

struct LocalChangeRemoteUpdateInstruction: CustomDebugStringConvertible, Equatable {
    let finalTransactionToken: NSPersistentHistoryToken
    var isEmpty: Bool { deletions.isEmpty && updates.isEmpty && inserts.isEmpty }
    var deletions = Set<String>()
    var updates = [String: CKRecord]()
    var inserts = [String: CKRecord]()
    var operationCount: Int {
        return deletions.count + updates.count + inserts.count
    }

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

    mutating func appendLocalChanges(_ localChanges: [LocalChange]) {
        for change in localChanges {
            appendLocalChange(change)
        }
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
