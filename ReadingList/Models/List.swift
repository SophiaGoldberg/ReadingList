import Foundation
import CoreData
import PersistedPropertyWrapper
import ReadingList_Foundation

@objc(List)
class List: NSManagedObject {
    @NSManaged var name: String
    @NSManaged var order: BookSort
    @NSManaged var sort: Int32
    @NSManaged private(set) var custom: Bool

    /** The item which hold a book-index pair for each book in this list */
    @NSManaged private(set) var items: Set<ListItem>

    /** The ordered array of books within this list. If just a count is required, use items.count instead. */
    var books: [Book] {
        items.sorted(byAscending: \.sort).map(\.book)
    }

    convenience init(context: NSManagedObjectContext, name: String) {
        self.init(context: context)
        self.name = name
        if let maxSort = List.maxSort(fromContext: context) {
            self.sort = maxSort + 1
        }
    }

    func removeBook(_ book: Book) {
        for item in items where item.book == book {
            item.delete()
        }
    }

    func removeBooks(_ books: Set<Book>) {
        for item in items where books.contains(item.book) {
            item.delete()
        }
    }

    func addBooks(_ books: [Book]) {
        guard let context = managedObjectContext else {
            preconditionFailure("Attempted to add books to a List which was not in a context")
        }

        // Grab the largest current sort value (if we have any books) to use in our next ListItem sort index
        var index: Int32
        if !items.isEmpty, let maxSort = context.getMaximum(sortValueKeyPath: \ListItem.sort) {
            index = maxSort + 1
        } else {
            index = 0
        }

        // Create some ordered ListItems mapping to the provided books. Create a set of all the existing books so we can
        // efficiently check whether any of the books are already in this list, and skip them if so.
        let existingBooks = Set(self.books)
        for book in books {
            guard !existingBooks.contains(book) else { continue }
            _ = ListItem(context: context, book: book, list: self, sort: index)
            index += 1
        }
    }

    class func names(fromContext context: NSManagedObjectContext) -> [String] {
        let fetchRequest = NSManagedObject.fetchRequest(List.self)
        fetchRequest.sortDescriptors = [NSSortDescriptor(\List.sort), NSSortDescriptor(\List.name)]
        fetchRequest.returnsObjectsAsFaults = false
        return (try! context.fetch(fetchRequest)).map { $0.name }
    }

    class func maxSort(fromContext context: NSManagedObjectContext) -> Int32? {
        return context.getMaximum(sortValueKeyPath: \List.sort)
    }

    class func getOrCreate(inContext context: NSManagedObjectContext, withName name: String) -> List {
        let listFetchRequest = NSManagedObject.fetchRequest(List.self, limit: 1)
        listFetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(Subject.name), name)
        listFetchRequest.returnsObjectsAsFaults = false
        if let existingList = (try! context.fetch(listFetchRequest)).first {
            return existingList
        }
        return List(context: context, name: name)
    }
}

enum ListSortOrder: Int, CustomStringConvertible, CaseIterable {
    case custom = 0
    case alphabetical = 1

    @Persisted("listSortOrder", defaultValue: .custom)
    static var selectedSort: ListSortOrder

    var description: String {
        switch self {
        case .custom: return "Custom"
        case .alphabetical: return "Alphabetical"
        }
    }
}
