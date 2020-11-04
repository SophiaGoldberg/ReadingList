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

@available(iOS 13.0, *) //swiftlint:disable:next generic_type_name
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

/// A UITableViewController that monitors calls to the numberOfSections and numberOfRows function calls, to determine when a
/// table has become empty, and switches out a background view accordingly.
open class LegacyEmptyDetectingTableDataSource: NSObject, UITableViewEmptyDetectingDataSource {
    public weak var emptyDetectionDelegate: UITableViewEmptyDetectingDataSourceDelegate?
    public let tableView: UITableView

    public private(set) var isEmpty = false
    private var hasPerformedInitialLoad = false
    private var cachedNumberOfSections = 0
    private let emptyStateView = EmptyStateView()

    public init(_ tableView: UITableView) {
        self.tableView = tableView
        super.init()
        self.tableView.dataSource = self
    }

    open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        fatalError("tableView:cellForRowAt: must be overriden")
    }

    final public func numberOfSections(in tableView: UITableView) -> Int {
        cachedNumberOfSections = sectionCount(in: tableView)
        if cachedNumberOfSections == 0 {
            if !isEmpty {
                os_log("Table switched from being non-empty to having 0 sections", type: .info)
                emptyDetectionDelegate?.tableDidBecomeEmpty()
                isEmpty = true
            }
        } else if isEmpty {
            os_log("Table switched from being empty to having %d sections", type: .info, cachedNumberOfSections)
            emptyDetectionDelegate?.tableDidBecomeNonEmpty()
            isEmpty = false
        }

        return cachedNumberOfSections
    }

    final public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // We want to treat a 1-section, 0-row table as empty.
        let rowCount = self.rowCount(in: tableView, forSection: section)
        if !isEmpty {
            if cachedNumberOfSections == 1 && section == 0 && rowCount == 0 {
                os_log("Table switched from being non-empty to having 1 section with 0 rows", type: .info)
                emptyDetectionDelegate?.tableDidBecomeEmpty()
                isEmpty = true
            }
        } else {
            os_log("Table switched from being empty to having %d sections (section %d had %d rows)", type: .info, cachedNumberOfSections, section, rowCount)
            if cachedNumberOfSections != 1 || section != 0 || rowCount != 0 {
                emptyDetectionDelegate?.tableDidBecomeNonEmpty()
                isEmpty = false
            }
        }
        return rowCount
    }

    open func sectionCount(in tableView: UITableView) -> Int {
        fatalError("sectionCount(in:) is not overridden")
    }

    open func rowCount(in tableView: UITableView, forSection section: Int) -> Int {
        fatalError("rowCount(in:forSection:) is not overridden")
    }
}
