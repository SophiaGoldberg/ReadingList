import Foundation
import UIKit
import Eureka

extension UIAlertController {
    static func duplicateBook(goToExistingBook: @escaping () -> Void, cancel: @escaping () -> Void) -> UIAlertController {

        let alert = UIAlertController(title: "Book Already Added", message: "A book with the same ISBN or Google Books ID has already been added to your reading list.", preferredStyle: .alert)

        // "Go To Existing Book" option - dismiss the provided ViewController (if there is one), and then simulate the book selection
        alert.addAction(UIAlertAction(title: "Go To Existing Book", style: .default) { _ in
            goToExistingBook()
        })

        // "Cancel" should just envoke the callback
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            cancel()
        })

        return alert
    }
}

enum Orderable {
    case book(BookReadState)
    case list(List)

    func supports(_ sort: BookSort) -> Bool {
        switch self {
        case let .book(readState):
            return sort.supports(readState)
        case .list:
            return sort.supportsListSorting
        }
    }

    func getSort() -> BookSort {
        switch self {
        case let .book(readState):
            return BookSort.byReadState[readState]!
        case let .list(list):
            return list.order
        }
    }

    func setSort(_ order: BookSort) {
        switch self {
        case let .book(readState):
            BookSort.byReadState[readState] = order
        case let .list(list):
            list.order = order
            list.managedObjectContext!.saveAndLogIfErrored()
        }
    }
}
