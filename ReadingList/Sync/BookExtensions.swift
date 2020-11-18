import CloudKit
import CoreData
import os.log
import ReadingList_Foundation

extension Book: CKRecordRepresentable {
    static let ckRecordType = "Book"

    func newRecordID(in zoneID: CKRecordZone.ID) -> CKRecord.ID {
        let recordName: String
        if let googleBooksId = googleBooksId {
            recordName = "gbid:\(googleBooksId)"
        } else if let manualBookId = manualBookId {
            recordName = "mid:\(manualBookId)"
        } else {
            fatalError("No google book or manual book ID")
        }
        return CKRecord.ID(recordName: recordName, zoneID: zoneID)
    }

    static func candidateBookForRemoteIdentifier(_ recordID: CKRecord.ID) -> NSPredicate {
        if recordID.recordName.starts(with: "gbid:") {
            return NSPredicate(format: "%K == %@", #keyPath(Book.googleBooksId), String(recordID.recordName.dropFirst(5)))
        }
        if recordID.recordName.starts(with: "mid:") {
            return NSPredicate(format: "%K == %@", #keyPath(Book.manualBookId), String(recordID.recordName.dropFirst(4)))
        }
        os_log("Unexpected format of remote record ID: %{public}s", type: .error, recordID.recordName)
        return NSPredicate(boolean: false)
    }

    func getValue(for ckRecordKey: CKRecordKey) -> CKRecordValue? { //swiftlint:disable:this cyclomatic_complexity
        switch ckRecordKey {
        case .title: return title as NSString
        case .subtitle: return subtitle as NSString?
        case .googleBooksId: return googleBooksId as NSString?
        case .isbn13: return isbn13 as NSNumber?
        case .pageCount: return pageCount as NSNumber?
        case .publicationDate: return publicationDate as NSDate?
        case .bookDescription: return bookDescription as NSString?
        case .notes: return notes as NSString?
        case .currentPage: return currentPage as NSNumber?
        case .languageCode: return language?.rawValue as NSString?
        case .rating: return rating as NSNumber?
        case .sort: return sort as NSNumber?
        case .readDates:
            switch readState {
            case .toRead: return nil
            case .reading: return [startedReading! as NSDate] as NSArray
            case .finished: return [startedReading! as NSDate, finishedReading! as NSDate] as NSArray
            }
        case .authors:
            do {
                return try NSKeyedArchiver.archivedData(withRootObject: authors, requiringSecureCoding: true) as NSData
            } catch {
                os_log(.error, "Error decoding author data")
                return nil
            }
        case .coverImage:
            guard let coverImage = coverImage else { return nil }
            let imageFilePath = URL.temporary()
            FileManager.default.createFile(atPath: imageFilePath.path, contents: coverImage, attributes: nil)
            return CKAsset(fileURL: imageFilePath)
        }
    }

    func setValue(_ value: CKRecordValue?, for ckRecordKey: CKRecordKey) { //swiftlint:disable:this cyclomatic_complexity
        switch ckRecordKey {
        case .title: title = value as! String
        case .subtitle: subtitle = value as? String
        case .googleBooksId: googleBooksId = value as? String
        case .isbn13: isbn13 = value as? Int64
        case .pageCount: pageCount = value as? Int32
        case .publicationDate: publicationDate = value as? Date
        case .bookDescription: bookDescription = value as? String
        case .notes: notes = value as? String
        case .currentPage: setProgress(.page(value as? Int32))
        case .languageCode:
            if let languageString = value as? String {
                language = LanguageIso639_1(rawValue: languageString)
            }
        case .rating: rating = value as? Int16
        case .sort: sort = value as! Int32
        case .readDates:
            if let datesArray = value as? [Date] {
                if datesArray.count == 1 {
                    setReading(started: datesArray[0])
                } else if datesArray.count == 2 {
                    setFinished(started: datesArray[0], finished: datesArray[1])
                }
            } else {
                setToRead()
            }
        case .authors:
            do {
                authors = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [Author.self, NSArray.self], from: value as! Data) as! [Author]
            } catch {
                os_log(.error, "Error decoding author data")
                authors = []
            }
        case .coverImage:
            guard let imageAsset = value as? CKAsset,
                  let assetUrl = imageAsset.fileURL,
                  FileManager.default.fileExists(atPath: assetUrl.path) else {
                coverImage = nil
                return
            }
            coverImage = FileManager.default.contents(atPath: assetUrl.path)
        }
    }

    /**
     Returns a CKRecord with every CKRecordKey set to the CKValue corresponding to the value in this book.
     */
    func recordForInsert(into zone: CKRecordZone.ID) -> CKRecord {
        let ckRecord = CKRecord(recordType: Book.ckRecordType, recordID: newRecordID(in: zone))
        for key in Book.CKRecordKey.allCases {
            if let valueForKey = getValue(for: key) {
                ckRecord[key] = valueForKey
            }
        }
        return ckRecord
    }

    func recordForUpdate(changedCoreDataKeys: [String]) -> CKRecord? {
        guard let ckRecord = getSystemFieldsRecord() else {
            return nil
            // TODO: Ought we error here?
            //fatalError("No stored CKRecord to use for differential update")
        }
        let changeCkRecordKeys = changedCoreDataKeys.compactMap(CKRecordKey.from(coreDataKey:)).distinct()
        if changeCkRecordKeys.isEmpty { return nil }
        for changedKey in changeCkRecordKeys {
            ckRecord[changedKey] = getValue(for: changedKey)
        }
        return ckRecord
    }

    /**
     Updates values in this book with those from the provided CKRecord. Values in this books which have a pending
     change are not updated.
    */
    func update(from ckRecord: CKRecord, excluding excludedKeys: [CKRecordKey]?) {
        if let existingCKRecordSystemFields = getSystemFieldsRecord(), existingCKRecordSystemFields.recordChangeTag == ckRecord.recordChangeTag {
            os_log("CKRecord %{public}s has same change tag as local book; skipping update", type: .debug, ckRecord.recordID.recordName)
            return
        }

        if remoteIdentifier != ckRecord.recordID.recordName {
            os_log("Updating remoteIdentifier from %{public}s to %{public}s", type: .debug, remoteIdentifier ?? "nil", ckRecord.recordID.recordName)
            remoteIdentifier = ckRecord.recordID.recordName
        }

        setSystemFields(ckRecord)

        // This book may have local changes which we don't want to overwrite with the values on the server.
        for key in CKRecordKey.allCases {
            if let excludedKeys = excludedKeys, excludedKeys.contains(key) {
                os_log(.info, log: .syncDownstream, "CKRecordKey '%{public}s' not used to update local store due to pending local change", key.rawValue)
                continue
            }
            setValue(ckRecord[key], for: key)
        }
    }

    static func withRemoteIdentifier(_ id: String) -> NSPredicate {
        return NSPredicate(format: "%K == %@", #keyPath(Book.remoteIdentifier), id)
    }

    static func withRemoteIdentifiers(_ ids: [String]) -> NSPredicate {
        return NSPredicate(format: "%K in %@", #keyPath(Book.remoteIdentifier), ids)
    }
}
