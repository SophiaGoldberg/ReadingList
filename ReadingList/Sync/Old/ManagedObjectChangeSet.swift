//import Foundation
//import CoreData
//import os.log
//
//typealias RemoteIdentifier = String
//
//struct ManagedObjectChangeSet: CustomDebugStringConvertible, Equatable {
//    let timestamp: Date
//    var deletions = Set<RemoteIdentifier>()
//    var updates = [NSManagedObjectID: [String]]()
//    var inserts = Set<NSManagedObjectID>()
//
//    var isEmpty: Bool { operationCount == 0 }
//    var operationCount: Int {
//        return deletions.count + updates.count + inserts.count
//    }
//
//    var debugDescription: String {
//        isEmpty ? "Empty" : "\(updates.count) updates, \(inserts.count) inserts, \(deletions.count) deletions"
//    }
//
//    init(timestamp: Date, changes: [ManagedObjectChange]) {
//        self.timestamp = timestamp
//        for change in changes {
//            switch change {
//            case .insert(let id):
//                inserts.insert(id)
//            case .update(let id, let keys):
//                if inserts.contains(id) { continue }
//                updates[id] = keys
//            case .delete(let remoteId):
//                deletions.insert(remoteId)
//            }
//        }
//    }
//}
//
//enum ManagedObjectChange {
//    case delete(remoteId: RemoteIdentifier)
//    case update(id: NSManagedObjectID, keys: [String])
//    case insert(id: NSManagedObjectID)
//}
//
//extension NSPersistentHistoryTransaction {
//    func changeSet() -> ManagedObjectChangeSet? {
//        guard let changes = changes else { return nil }
//        let managedObjectChanges = changes.compactMap { $0.localChangeRepresentation() }
//        if managedObjectChanges.isEmpty { return nil }
//        return ManagedObjectChangeSet(timestamp: timestamp, changes: managedObjectChanges)
//    }
//}
//
//extension NSPersistentHistoryChange {
//    func localChangeRepresentation() -> ManagedObjectChange? {
//        switch changeType {
//        case .insert:
//            self.entityDescription
//            return .insert(id: changedObjectID)
//        case .delete:
//            guard let remoteId = tombstone?[SyncConstants.remoteIdentifierKeyPath] as? String else { return nil }
//            return .delete(remoteId: remoteId)
//        case .update:
//            guard let updatedProperties = updatedProperties?.map(\.name) else { return nil }
//            return .update(id: changedObjectID, keys: updatedProperties)
//        @unknown default:
//            os_log(.default, log: .syncCoordinator, "Unexpected changeType value %d", changeType.rawValue)
//            return nil
//        }
//    }
//}
