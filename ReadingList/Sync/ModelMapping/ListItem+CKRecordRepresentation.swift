import CloudKit
import CoreData
import os.log
import ReadingList_Foundation

extension ListItem: CKRecordRepresentable {
    static let ckRecordType = "ListItem"
    static let allCKRecordKeys = ListItemCKRecordKey.allCases.map(\.rawValue)
    @NSManaged var ckRecordEncodedSystemFields: Data?
    @NSManaged var remoteIdentifier: String?

    static func matchCandidateItemForRemoteRecord(_ record: CKRecord) -> NSPredicate {
        guard record.recordType == ckRecordType else {
            os_log("Attempted to match a CKRecord of type %{public}s to a ListItem", log: .syncCoordinator, type: .fault, record.recordType)
            return NSPredicate(boolean: false)
        }
        guard let bookReference = record[.book] as? CKRecord.Reference else {
            os_log("No book reference on a ListItem", log: .syncCoordinator, type: .error)
            return NSPredicate(boolean: false)
        }
        guard let listReference = record[.list] as? CKRecord.Reference else {
            os_log("No list reference on a ListItem", log: .syncCoordinator, type: .error)
            return NSPredicate(boolean: false)
        }
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "\(#keyPath(ListItem.book)).\(SyncConstants.remoteIdentifierKeyPath) == %@", bookReference.recordID.recordName),
            NSPredicate(format: "\(#keyPath(ListItem.list)).\(SyncConstants.remoteIdentifierKeyPath) == %@", listReference.recordID.recordName)
        ])
    }

    func getValue(for key: String) -> CKRecordValueProtocol? { //swiftlint:disable:this cyclomatic_complexity
        guard let ckRecordKey = ListItemCKRecordKey(rawValue: key) else { return nil }
        switch ckRecordKey {
        case .sort: return Int(sort)!
        case .book:
            guard let bookIdentifier = book.remoteIdentifier else { return nil }
            return CKRecord.Reference(recordID: CKRecord.ID(recordName: bookIdentifier, zoneID: SyncConstants.zoneID), action: .deleteSelf)
        case .list:
            guard let listIdentifier = list.remoteIdentifier else { return nil }
            return CKRecord.Reference(recordID: CKRecord.ID(recordName: listIdentifier, zoneID: SyncConstants.zoneID), action: .deleteSelf)
        }
    }

    func setValue(_ value: CKRecordValueProtocol?, for ckRecordKey: String) {
        guard let key = ListItemCKRecordKey(rawValue: ckRecordKey) else { return }
        switch key {
        case .sort:
            if let sortNumber = value as? NSNumber, let sortInt32 = Int32(exactly: sortNumber) {
                sort = sortInt32
            }
        case .book:
            guard let reference = value as? CKRecord.Reference else { return }
            let request = Book.fetchRequest()
            request.fetchLimit = 1
            request.predicate = NSPredicate(format: "%K == %@", SyncConstants.remoteIdentifierKeyPath, reference.recordID.recordName)
            guard let matchingBook = try! managedObjectContext!.fetch(request).first else { return }
            setValue(matchingBook, forKey: #keyPath(ListItem.book))
        case .list:
            guard let reference = value as? CKRecord.Reference else { return }
            let request = List.fetchRequest()
            request.fetchLimit = 1
            request.predicate = NSPredicate(format: "%K == %@", SyncConstants.remoteIdentifierKeyPath, reference.recordID.recordName)
            guard let matchingList = try! managedObjectContext!.fetch(request).first else { return }
            setValue(matchingList, forKey: #keyPath(ListItem.list))
        }
    }

    func newRecordName() -> String {
        UUID().uuidString
    }

    func localPropertyKeys(forCkRecordKey ckRecordKey: String) -> [String] {
        guard let ckKey = ListItemCKRecordKey(rawValue: ckRecordKey) else { return [] }
        return ckKey.localKeys()
    }

    func ckRecordKey(forLocalPropertyKey localPropertyKey: String) -> String? {
        return ListItemCKRecordKey.from(coreDataKey: localPropertyKey)?.rawValue
    }
}

extension CKRecord {
    subscript (_ key: ListItemCKRecordKey) -> CKRecordValue? {
        get { return self.object(forKey: key.rawValue) }
        set { self.setObject(newValue, forKey: key.rawValue) }
    }
}

enum ListItemCKRecordKey: String, CaseIterable { //swiftlint:disable redundant_string_enum_value
    case book = "book"
    case list = "list"
    case sort = "sort" //swiftlint:enable redundant_string_enum_value

    static func from(coreDataKey: String) -> ListItemCKRecordKey? { //swiftlint:disable:this cyclomatic_complexity
        switch coreDataKey {
        case #keyPath(ListItem.sort): return .sort
        case #keyPath(ListItem.book): return .book
        case #keyPath(ListItem.list): return .list
        default: return nil
        }
    }

    func localKeys() -> [String] {
        switch self {
        case .sort: return [#keyPath(ListItem.sort)]
        case .book: return [#keyPath(ListItem.book)]
        case .list: return [#keyPath(ListItem.list)]
        }
    }
}
