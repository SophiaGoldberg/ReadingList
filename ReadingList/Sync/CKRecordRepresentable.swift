import Foundation
import CloudKit
import CoreData
import os.log

struct SyncConstants {
    static let remoteIdentifierKeyPath = "remoteIdentifier"
    static let zoneID = CKRecordZone.ID(zoneName: "ReadingListZone", ownerName: CKCurrentUserDefaultName)
}

protocol CKRecordRepresentable: NSManagedObject {
    static var ckRecordType: String { get }
    static var allCKRecordKeys: [String] { get }
    var isDeleted: Bool { get }

    var remoteIdentifier: String? { get set }
    var ckRecordEncodedSystemFields: Data? { get set }
    func newRecordName() -> String

    func localPropertyKeys(forCkRecordKey ckRecordKey: String) -> [String]
    func ckRecordKey(forLocalPropertyKey localPropertyKey: String) -> String?

    static func matchCandidateItemForRemoteRecord(_ record: CKRecord) -> NSPredicate

    func getValue(for key: String) -> CKRecordValueProtocol?
    func setValue(_ value: CKRecordValueProtocol?, for ckRecordKey: String)
}

extension CKRecordRepresentable {
    func getSystemFieldsRecord() -> CKRecord? {
        guard let systemFieldsData = ckRecordEncodedSystemFields else { return nil }
        return CKRecord(systemFieldsData: systemFieldsData)!
    }

    func setSystemFields(_ ckRecord: CKRecord?) {
        ckRecordEncodedSystemFields = ckRecord?.encodedSystemFields()
    }

    static func remoteIdentifierPredicate(_ id: String) -> NSPredicate {
        return NSPredicate(format: "%K == %@", SyncConstants.remoteIdentifierKeyPath, id)
    }

    func newRecordID(in zone: CKRecordZone.ID) -> CKRecord.ID {
        let recordName = newRecordName()
        return CKRecord.ID(recordName: recordName, zoneID: zone)
    }

    func recordForInsert(into zone: CKRecordZone.ID) -> CKRecord {
        let ckRecord = CKRecord(recordType: Self.ckRecordType, recordID: newRecordID(in: zone))
        for key in Self.allCKRecordKeys {
            guard let valueForKey = getValue(for: key) else { continue }
            ckRecord[key] = valueForKey
        }
        return ckRecord
    }

    func recordForUpdate(changedCoreDataKeys: [String]) -> CKRecord? {
        guard let ckRecord = getSystemFieldsRecord() else { return nil }
        let changeCkRecordKeys = changedCoreDataKeys.compactMap(ckRecordKey(forLocalPropertyKey:)).distinct()
        if changeCkRecordKeys.isEmpty { return nil }
        for changedKey in changeCkRecordKeys {
            ckRecord[changedKey] = getValue(for: changedKey)
        }
        return ckRecord
    }

    func setSystemAndIdentifierFields(from ckRecord: CKRecord) {
        guard remoteIdentifier == nil || remoteIdentifier == ckRecord.recordID.recordName else {
            os_log("Attempted to update local object with remoteIdentifier %{public}s from a CKRecord which has record name %{public}s", log: .syncCoordinator, type: .fault, remoteIdentifier!, ckRecord.recordID.recordName)
            os_log("%{public}s", log: .syncCoordinator, type: .fault, Thread.callStackSymbols.joined(separator: "\n"))
            fatalError("Attempted to update local object from CKRecord with different remoteIdentifier")
        }

        if let existingCKRecordSystemFields = getSystemFieldsRecord(), existingCKRecordSystemFields.recordChangeTag == ckRecord.recordChangeTag {
            os_log("CKRecord %{public}s has same change tag as local book; no update made", log: .syncCoordinator, type: .debug, ckRecord.recordID.recordName)
            return
        }

        if remoteIdentifier == nil {
            remoteIdentifier = ckRecord.recordID.recordName
        }
        setSystemFields(ckRecord)
    }

    /**
     Updates values in this book with those from the provided CKRecord. Values in this books which have a pending
     change are not updated.
    */
    func update(from ckRecord: CKRecord, excluding excludedKeys: [String]?) {
        setSystemAndIdentifierFields(from: ckRecord)

        // This book may have local changes which we don't want to overwrite with the values on the server.
        for key in Self.allCKRecordKeys {
            if let excludedKeys = excludedKeys, excludedKeys.contains(key) {
                os_log(.info, log: .syncCoordinator, "CKRecordKey '%{public}s' not used to update local store due to pending local change", key)
                continue
            }
            setValue(ckRecord[key], for: key)
        }
    }
}
