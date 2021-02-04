import Foundation
import Eureka
import UIKit

@discardableResult
public func <<< (left: Section, right: [BaseRow]) -> Section {
    left.append(contentsOf: right)
    return left
}

extension FormViewController {
    func initialiseInsetGroupedTable() {
        // Should be called prior to calling super.viewDidLoad() (which would normally initialise one,
        // but won't in this case when it sees that tableView is not nil). This allows us to get the inset
        // grouped style.
        tableView = UITableView(frame: view.bounds, style: .insetGrouped)
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.cellLayoutMarginsFollowReadableWidth = false
    }
}
