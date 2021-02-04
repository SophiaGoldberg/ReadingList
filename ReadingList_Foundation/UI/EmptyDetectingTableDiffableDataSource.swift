import Foundation
import CoreData
import UIKit
import os.log

public protocol UITableViewEmptyDetectingDataSource: UITableViewDataSource {
    var emptyDetectionDelegate: UITableViewEmptyDetectingDataSourceDelegate? { get set }
}

public protocol UITableViewEmptyDetectingDataSourceDelegate: class {
    func tableDidBecomeEmpty()
    func tableDidBecomeNonEmpty()
}

//swiftlint:disable:next generic_type_name
open class EmptyDetectingTableDiffableDataSource<SectionIdentifierType, ItemIdentifierType>: UITableViewDiffableDataSource<SectionIdentifierType, ItemIdentifierType>, UITableViewEmptyDetectingDataSource where SectionIdentifierType: Hashable, ItemIdentifierType: Hashable {
    public weak var emptyDetectionDelegate: UITableViewEmptyDetectingDataSourceDelegate?
    var isEmpty = false

    public override init(tableView: UITableView, cellProvider: @escaping UITableViewDiffableDataSource<SectionIdentifierType, ItemIdentifierType>.CellProvider) {
        super.init(tableView: tableView, cellProvider: cellProvider)
    }

    override public func apply(_ snapshot: NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType>, animatingDifferences: Bool = true, completion: (() -> Void)? = nil) {
        if snapshot.numberOfItems == 0 {
            if !isEmpty {
                emptyDetectionDelegate?.tableDidBecomeEmpty()
                isEmpty = true
            }
        } else if isEmpty {
            emptyDetectionDelegate?.tableDidBecomeNonEmpty()
            isEmpty = false
        }
        super.apply(snapshot, animatingDifferences: animatingDifferences, completion: completion)
    }
}
