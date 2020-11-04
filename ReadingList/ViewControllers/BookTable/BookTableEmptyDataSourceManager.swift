import ReadingList_Foundation
import UIKit

final class BookTableEmptyDataSourceManager: UITableViewSearchableEmptyStateManager {

    private let mode: Mode
    private let onEmptyStateChange: (Bool) -> Void

    enum Mode {
        case toReadAndReading
        case finished
    }

    static func mode(from readStates: [BookReadState]) -> Mode {
        if readStates.contains(.toRead) {
            return .toReadAndReading
        } else if readStates.contains(.finished) {
            return .finished
        } else { preconditionFailure() }
    }

    init(tableView: UITableView, navigationBar: UINavigationBar?, navigationItem: UINavigationItem, searchController: UISearchController,
         mode: Mode, onEmptyStateChange: @escaping (Bool) -> Void) {
        self.onEmptyStateChange = onEmptyStateChange
        self.mode = mode
        super.init(tableView, navigationBar: navigationBar, navigationItem: navigationItem, searchController: searchController)
    }

    final override func titleForNonSearchEmptyState() -> String {
        switch mode {
        case .toReadAndReading:
            return "📚 To Read"
        case .finished:
            return "🎉 Finished"
        }
    }

    override func textForNonSearchEmptyState() -> NSAttributedString {
        let mutableString: NSMutableAttributedString
        switch mode {
        case .toReadAndReading:
            mutableString = NSMutableAttributedString("Books you add to your ", font: emptyStateDescriptionFont)
                .appending("To Read", font: emptyStateDescriptionBoldFont)
                .appending(" list, or mark as currently ", font: emptyStateDescriptionFont)
                .appending("Reading", font: emptyStateDescriptionBoldFont)
                .appending(" will show up here.", font: emptyStateDescriptionFont)
        case .finished:
            mutableString = NSMutableAttributedString("Books you mark as ", font: emptyStateDescriptionFont)
                .appending("Finished", font: emptyStateDescriptionBoldFont)
                .appending(" will show up here.", font: emptyStateDescriptionFont)
        }

        mutableString.appending("\n\nAdd a book by tapping the ", font: emptyStateDescriptionFont)
            .appending("+", font: emptyStateDescriptionBoldFont)
            .appending(" button above.", font: emptyStateDescriptionFont)

        return mutableString
    }

    override func textForSearchEmptyState() -> NSAttributedString {
        return NSMutableAttributedString(
            "Try changing your search, or add a new book by tapping the ", font: emptyStateDescriptionFont)
        .appending("+", font: emptyStateDescriptionBoldFont)
        .appending(" button.", font: emptyStateDescriptionFont)
    }

    final override func emptyStateDidChange() {
        super.emptyStateDidChange()
        self.onEmptyStateChange(isShowingEmptyState)
    }
}
