import ReadingList_Foundation
import UIKit

final class ListBookTableEmptyDataSetManager: UITableViewSearchableEmptyStateManager {

    private let list: List

    init(tableView: UITableView, navigationBar: UINavigationBar?, navigationItem: UINavigationItem, searchController: UISearchController, list: List) {
        self.list = list
        super.init(tableView, navigationBar: navigationBar, navigationItem: navigationItem, searchController: searchController)
    }

    override func titleForNonSearchEmptyState() -> String {
        return "✨ Empty List"
    }

    override func textForSearchEmptyState() -> NSAttributedString {
        return NSAttributedString(
            "Try changing your search, or add another book to this list.",
            font: emptyStateDescriptionFont)
    }

    override func textForNonSearchEmptyState() -> NSAttributedString {
        return NSMutableAttributedString(
            "The list \"\(list.name)\" is currently empty.  To add a book to it, find a book and tap ",
            font: emptyStateDescriptionFont)
            .appending("Manage Lists", font: emptyStateDescriptionBoldFont)
            .appending(".", font: emptyStateDescriptionFont)
    }
}
