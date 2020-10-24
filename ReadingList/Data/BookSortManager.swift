import Foundation
import CoreData

class BookSortIndexManager {
    private let context: NSManagedObjectContext
    private let addToTop: Bool
    private var sort: Int32

    init(context: NSManagedObjectContext, readState: BookReadState, sortUpwards: Bool, exclude: Book? = nil) {
        self.context = context
        self.addToTop = sortUpwards

        if addToTop, let minSort = Book.minSort(with: readState, from: context, excluding: exclude) {
            sort = minSort - 1
        } else if !addToTop, let maxSort = Book.maxSort(with: readState, from: context, excluding: exclude) {
            sort = maxSort + 1
        } else {
            sort = 0
        }
    }

    /**
     Determines the sort direction from the value of the addBooksToTopOfCustom UserDefaults setting
    */
    convenience init(context: NSManagedObjectContext, readState: BookReadState, exclude: Book? = nil) {
        self.init(context: context, readState: readState, sortUpwards: GeneralSettings.addBooksToTopOfCustom, exclude: exclude)
    }

    func getAndIncrementSort() -> Int32 {
        let currentSort = sort
        if addToTop {
            sort -= 1
        } else {
            sort += 1
        }
        return currentSort
    }
}
