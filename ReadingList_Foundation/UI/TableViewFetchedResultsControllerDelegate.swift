import Foundation
import UIKit
import CoreData

extension UITableView: NSFetchedResultsControllerDelegate {

    public func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        beginUpdates()
    }

    public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange object: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .update:
            reloadRows(at: [indexPath!], with: .none)
        case .insert:
            insertRows(at: [newIndexPath!], with: .automatic)
        case .move:
            deleteRows(at: [indexPath!], with: .automatic)
            insertRows(at: [newIndexPath!], with: .automatic)
        case .delete:
            deleteRows(at: [indexPath!], with: .automatic)
        @unknown default:
            assertionFailure("Unknown change type \(type)")
        }
    }

    public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            insertSections(IndexSet(integer: sectionIndex), with: .automatic)
        case .delete:
            deleteSections(IndexSet(integer: sectionIndex), with: .automatic)
        default:
            break
        }
    }

    public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        endUpdates()
    }
}
