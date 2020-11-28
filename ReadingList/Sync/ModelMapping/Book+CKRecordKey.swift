import Foundation
import CoreData
import CloudKit

extension Book {
    /**
     Encapsulates the mapping between Book objects and CKRecord values
     */
    enum CKRecordKey: String, CaseIterable { //swiftlint:disable redundant_string_enum_value
        case title = "title"
        case subtitle = "subtitle"
        case authors = "authors"
        case googleBooksId = "googleBooksId"
        case isbn13 = "isbn13"
        case pageCount = "pageCount"
        case publicationDate = "publicationDate"
        case bookDescription = "bookDescription"
        case coverImage = "coverImage"
        case notes = "notes"
        case currentPage = "currentPage"
        case languageCode = "languageCode"
        case rating = "rating"
        case sort = "sort"
        case readDates = "readDates" //swiftlint:enable redundant_string_enum_value

        static func from(coreDataKey: String) -> CKRecordKey? { //swiftlint:disable:this cyclomatic_complexity
            switch coreDataKey {
            case #keyPath(Book.title): return .title
            case #keyPath(Book.subtitle): return .subtitle
            case #keyPath(Book.authors): return .authors
            case #keyPath(Book.coverImage): return .coverImage
            case #keyPath(Book.googleBooksId): return .googleBooksId
            case Book.Key.isbn13.rawValue: return .isbn13
            case Book.Key.pageCount.rawValue: return .pageCount
            case #keyPath(Book.publicationDate): return .publicationDate
            case #keyPath(Book.bookDescription): return .bookDescription
            case #keyPath(Book.notes): return .notes
            case Book.Key.currentPage.rawValue: return .currentPage
            case Book.Key.languageCode.rawValue: return .languageCode
            case Book.Key.rating.rawValue: return .rating
            case #keyPath(Book.sort): return .sort
            case #keyPath(Book.startedReading): return .readDates
            case #keyPath(Book.finishedReading): return .readDates
            default: return nil
            }
        }
        
        func localPropertyKeys() -> [String] { //swiftlint:disable:this cyclomatic_complexity
            switch self {
            case .title: return [#keyPath(Book.title)]
            case .subtitle: return [#keyPath(Book.subtitle)]
            case .authors: return [#keyPath(Book.authors)]
            case .coverImage: return [#keyPath(Book.coverImage)]
            case .googleBooksId: return [#keyPath(Book.googleBooksId)]
            case .isbn13: return [Book.Key.isbn13.rawValue]
            case .pageCount: return [Book.Key.pageCount.rawValue]
            case .publicationDate: return [#keyPath(Book.publicationDate)]
            case .bookDescription: return [#keyPath(Book.bookDescription)]
            case .notes: return [#keyPath(Book.notes)]
            case .currentPage: return [Book.Key.currentPage.rawValue]
            case .languageCode: return [Book.Key.languageCode.rawValue]
            case .rating: return [Book.Key.rating.rawValue]
            case .sort: return [#keyPath(Book.sort)]
            case .readDates: return [#keyPath(Book.startedReading), #keyPath(Book.finishedReading)]
            }
        }
    }
}

extension CKRecord {
    subscript (_ key: Book.CKRecordKey) -> CKRecordValue? {
        get { return self.object(forKey: key.rawValue) }
        set { self.setObject(newValue, forKey: key.rawValue) }
    }

    func changedBookKeys() -> [Book.CKRecordKey] {
        return changedKeys().compactMap { Book.CKRecordKey(rawValue: $0) }
    }

    func presentBookKeys() -> [Book.CKRecordKey] {
        return allKeys().compactMap { Book.CKRecordKey(rawValue: $0) }
    }
}
