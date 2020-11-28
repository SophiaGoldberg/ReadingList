import CloudKit
import CoreData
import os.log
import ReadingList_Foundation

extension Book: CKRecordRepresentable {
    static let allCKRecordKeys = CKRecordKey.allCases.map(\.rawValue)
    static let ckRecordType = "Book"

    @NSManaged var ckRecordEncodedSystemFields: Data?

    func newRecordName() -> String {
        if let googleBooksId = googleBooksId {
            return "gbid:\(googleBooksId)"
        } else if let manualBookId = manualBookId {
            return "mid:\(manualBookId)"
        } else {
            fatalError("No google book or manual book ID")
        }
    }
    
    func localPropertyKeys(forCkRecordKey ckRecordKey: String) -> [String] {
        return CKRecordKey(rawValue: ckRecordKey)?.localPropertyKeys() ?? []
    }
    
    func ckRecordKey(forLocalPropertyKey localPropertyKey: String) -> String? {
        return CKRecordKey.from(coreDataKey: localPropertyKey)?.rawValue
    }
    
    static func matchCandidateItemForRemoteRecord(_ record: CKRecord) -> NSPredicate {
        let recordName = record.recordID.recordName
        if recordName.starts(with: "gbid:") {
            return NSPredicate(format: "%K == %@", #keyPath(Book.googleBooksId), String(recordName.dropFirst(5)))
        }
        if recordName.starts(with: "mid:") {
            return NSPredicate(format: "%K == %@", #keyPath(Book.manualBookId), String(recordName.dropFirst(4)))
        }
        os_log("Unexpected format of remote record ID: %{public}s", log: .syncCoordinator, type: .error, recordName)
        return NSPredicate(boolean: false)
    }

    func getValue(for ckRecordKey: String) -> CKRecordValue? { //swiftlint:disable:this cyclomatic_complexity
        guard let key = CKRecordKey(rawValue: ckRecordKey) else { return nil }
        switch key {
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

    func setValue(_ value: CKRecordValue?, for ckRecordKey: String) { //swiftlint:disable:this cyclomatic_complexity
        guard let key = CKRecordKey(rawValue: ckRecordKey) else { return }
        switch key {
        case .title:
            if let newTitle = value as? String {
                title = newTitle
            }
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
        case .sort:
            if let newSort = value as? Int32 {
                sort = newSort
            }
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
                if let data = value as? Data,
                   let unarchivedData = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [Author.self, NSArray.self], from: data),
                   let authorsFromData = unarchivedData as? [Author] {
                    authors = authorsFromData
                }
            } catch {
                os_log(.error, log: .syncCoordinator, "Error decoding author data: %{public}s", error.localizedDescription)
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

    static func withRemoteIdentifier(_ id: String) -> NSPredicate {
        return NSPredicate(format: "%K == %@", #keyPath(Book.remoteIdentifier), id)
    }

    static func withRemoteIdentifiers(_ ids: [String]) -> NSPredicate {
        return NSPredicate(format: "%K in %@", #keyPath(Book.remoteIdentifier), ids)
    }
}
