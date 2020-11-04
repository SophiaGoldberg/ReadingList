import UIKit

/**
 Handles changing UI state of a UITableView in response to a change in whether the table is "empty" or not.
 */
open class UITableViewEmptyStateManager: UITableViewEmptyDetectingDataSourceDelegate {
    let tableView: UITableView
    private let emptyStateView = EmptyStateView()
    public var isShowingEmptyState = false

    public init(_ tableView: UITableView) {
        self.tableView = tableView
    }

    public func tableDidBecomeEmpty() {
        showEmptyDataSet()
        emptyStateDidChange()
    }

    public func tableDidBecomeNonEmpty() {
        hideEmptyDataSet()
        emptyStateDidChange()
    }

    public final func showEmptyDataSet() {
        tableView.isScrollEnabled = false
        reloadEmptyStateView()
        tableView.backgroundView = emptyStateView
        isShowingEmptyState = true
    }

    public final func hideEmptyDataSet() {
        tableView.backgroundView = nil
        tableView.isScrollEnabled = true
        isShowingEmptyState = false
    }

    public final func reloadEmptyStateView() {
        emptyStateView.title.attributedText = titleForEmptyState()
        emptyStateView.text.attributedText = textForEmptyState()
        emptyStateView.position = positionForEmptyState()
    }

    open func titleForEmptyState() -> NSAttributedString {
        return NSAttributedString(string: "Empty State")
    }

    open func textForEmptyState() -> NSAttributedString {
        return NSAttributedString(string: "To customise the text displayed, override titleForEmptyState() and textForEmptyState().")
    }

    open func positionForEmptyState() -> EmptyStatePosition {
        return .center
    }

    open func emptyStateDidChange() { }
}
