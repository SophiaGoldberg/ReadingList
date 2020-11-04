import Foundation
import ReadingList_Foundation
import PersistedPropertyWrapper

@objc public enum BookSort: Int16, CaseIterable, CustomStringConvertible, Codable {
    // The order of this enum determines the order that the settings are shown in menus, via the allCases property
    case custom = 1
    case listCustom = 6
    case startDate = 2
    case finishDate = 3
    case title = 4
    case subtitle = 7
    case author = 5
    case progress = 8
    case rating = 9

    @Persisted(encodedDataKey: "bookSortOrdersByReadState", defaultValue: [.toRead: .custom, .reading: .startDate, .finished: .finishDate])
    static var byReadState: [BookReadState: BookSort]

    public var description: String {
        switch self {
        case .custom, .listCustom: return "Custom"
        case .startDate: return "Start Date"
        case .finishDate: return "Finish Date"
        case .title: return "Title"
        case .author: return "Author"
        case .subtitle: return "Subtitle"
        case .progress: return "Progress"
        case .rating: return "Rating"
        }
    }

    public var supportsListSorting: Bool {
        return listItemSortDescriptors != nil
    }

    func supports(_ state: BookReadState) -> Bool {
        switch self {
        case .custom, .title, .subtitle, .author: return true
        case .listCustom, .rating: return false
        case .startDate: return state == .reading || state == .finished
        case .finishDate: return state == .finished
        case .progress: return state == .reading
        }
    }

    var listItemSortDescriptors: [NSSortDescriptor]? {
        switch self {
        case .custom, .progress:
            return nil
        case .listCustom:
            return [NSSortDescriptor(\ListItem.sort)]
        default:
            return bookSortKeyPaths?.map { $0.withKeyPathPrefix(#keyPath(ListItem.book)).toNSSortDescriptor() }
        }
    }

    var bookSortDescriptors: [NSSortDescriptor]? {
        return bookSortKeyPaths?.map { $0.toNSSortDescriptor() }
    }

    private struct SortKeyPath {
        init(_ keyPath: String, ascending: Bool = true) {
            self.keyPath = keyPath
            self.ascending = ascending
        }

        let keyPath: String
        let ascending: Bool

        func toNSSortDescriptor() -> NSSortDescriptor {
            return NSSortDescriptor(key: keyPath, ascending: ascending)
        }

        func withKeyPathPrefix(_ prefix: String) -> SortKeyPath {
            return SortKeyPath("\(prefix).\(self.keyPath)", ascending: self.ascending)
        }
    }

    private var bookSortKeyPaths: [SortKeyPath]? {
        switch self {
        case .title: return [SortKeyPath(#keyPath(Book.title)), SortKeyPath(#keyPath(Book.subtitle))]
        case .subtitle: return [SortKeyPath(#keyPath(Book.hasSubtitle), ascending: false), SortKeyPath(#keyPath(Book.subtitle)), SortKeyPath(#keyPath(Book.title))]
        case .author: return [SortKeyPath(#keyPath(Book.authorSort)),
                              SortKeyPath(#keyPath(Book.title))]
        case .startDate: return [SortKeyPath(#keyPath(Book.startedReading), ascending: false),
                                 SortKeyPath(#keyPath(Book.title))]
        case .finishDate: return [SortKeyPath(#keyPath(Book.finishedReading), ascending: false),
                                  SortKeyPath(#keyPath(Book.startedReading), ascending: false),
                                  SortKeyPath(#keyPath(Book.title))]
        case .custom: return [SortKeyPath(#keyPath(Book.sort)),
                              SortKeyPath(#keyPath(Book.googleBooksId)),
                              SortKeyPath(#keyPath(Book.manualBookId))]
        case .progress: return [SortKeyPath(Book.Key.currentPercentage.rawValue)]
        case .rating: return [SortKeyPath(Book.Key.rating.rawValue, ascending: false)]
        case .listCustom: return nil
        }
    }
}
