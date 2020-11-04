import Foundation
import CoreData
import UIKit
import os.log

public protocol Sortable {
    var sortIndex: Int32 { get set }
}

public class SortManager<ItemType: Sortable> {

    let tableView: UITableView
    let getObject: (IndexPath) -> ItemType

    public init(_ tableView: UITableView, getObject: @escaping ((IndexPath) -> ItemType)) {
        self.tableView = tableView
        self.getObject = getObject
    }

    /**
     Any delegate of the results controller should be removed before calling this function, and restored afterwards.
    */
    public func move(objectAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard sourceIndexPath.section == destinationIndexPath.section else { preconditionFailure() }
        guard sourceIndexPath != destinationIndexPath else { return }

        // Get the range of objects that the move affects
        let topRowIndex = sourceIndexPath.row < destinationIndexPath.row ? sourceIndexPath : destinationIndexPath
        let bottomRowIndex = sourceIndexPath.row < destinationIndexPath.row ? destinationIndexPath : sourceIndexPath
        let downwardMovement = sourceIndexPath.row < destinationIndexPath.row
        var objectsInMovementRange = (topRowIndex.row...bottomRowIndex.row).map {
            getObject(IndexPath(row: $0, section: sourceIndexPath.section))
        }

        // We may need the top index later, so capture it now.
        let initialFirstIndex = objectsInMovementRange.first!.sortIndex

        // Move the objects array to reflect the desired order
        if downwardMovement {
            let first = objectsInMovementRange.removeFirst()
            objectsInMovementRange.append(first)
        } else {
            let last = objectsInMovementRange.removeLast()
            objectsInMovementRange.insert(last, at: 0)
        }

        // Get the desired sort index for the top row in the movement range. This will be the basis of our new sort values.
        // The desired sort index should be the sort of the item immediately above the specified cell, plus 1, or - if the
        // cell is at the top - the value of the current minimum sort.
        let topRowSort = topRowIndex.row == 0 ? initialFirstIndex : getObject(topRowIndex.previous()).sortIndex + 1

        // Update the sort indices for all books in the range, increasing the sort by 1 for each cell.
        var sort = topRowSort
        for var item in objectsInMovementRange {
            item.sortIndex = sort
            sort += 1
        }
        os_log("Adjusted the sort indices of %d items (%d - %d)", type: .debug, objectsInMovementRange.count, topRowSort, sort - 1)

        // The following operation does not strictly follow from this reorder operation: we want to ensure that
        // we don't have overlapping sort indices. This shoudn't happen in normal usage of the app - but distinct
        // values are not enforced in the data model. Overlap might occur due to difficult-to-avoid timing issues
        // in iCloud sync. We take advantage of this time to clean up any mess that may be present.
        cleanupClashingSortIndices(from: bottomRowIndex.next(), withSort: sort)
    }

    private func cleanupClashingSortIndices(from topIndexPath: IndexPath, withSort topSort: Int32) {
        var cleanupIndex = topIndexPath
        while cleanupIndex.row < tableView.numberOfRows(inSection: cleanupIndex.section) {
            var cleanupItem = getObject(cleanupIndex)
            let cleanupSort = Int32(cleanupIndex.row - topIndexPath.row) + topSort

            // No need to proceed if the sort index is large enough
            if cleanupItem.sortIndex >= cleanupSort { break }

            os_log("Sort cleanup: adjusting sort index of item at index %d from %d to %d.", type: .debug, cleanupIndex.row, cleanupItem.sortIndex, cleanupSort)

            cleanupItem.sortIndex = cleanupSort
            cleanupIndex = cleanupIndex.next()
        }
    }
}
