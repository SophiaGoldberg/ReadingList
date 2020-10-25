import ReadingList_Foundation
import UIKit

final class OrganizeEmptyDataSetManager: UITableViewSearchableEmptyStateManager {
    init(tableView: UITableView, navigationBar: UINavigationBar?, navigationItem: UINavigationItem, searchController: UISearchController) {
        super.init(tableView, navigationBar: navigationBar, navigationItem: navigationItem, searchController: searchController)
    }

    final override func titleForNonSearchEmptyState() -> String {
         return NSLocalizedString("OrganizeEmptyHeader", comment: "")
    }

    final override func textForSearchEmptyState() -> NSAttributedString {
        return NSMutableAttributedString("Try changing your search, or add a new list by tapping the ", font: emptyStateDescriptionFont)
                .appending("+", font: emptyStateDescriptionBoldFont)
                .appending(" button.", font: emptyStateDescriptionFont)
    }

    final override func textForNonSearchEmptyState() -> NSAttributedString {
        return NSMutableAttributedString(NSLocalizedString("OrganizeInstruction", comment: ""), font: emptyStateDescriptionFont)
            .appending("\n\nTo create a new list, tap the ", font: emptyStateDescriptionFont)
            .appending("+", font: emptyStateDescriptionBoldFont)
            .appending(" button above, or tap ", font: emptyStateDescriptionFont)
            .appending("Manage Lists", font: emptyStateDescriptionBoldFont)
            .appending(" when viewing a book.", font: emptyStateDescriptionFont)
    }
}
