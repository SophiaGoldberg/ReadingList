import UIKit
import CoreData

/**
 A delegate protocol that describes the functions that will be called by the associated `ResultsControllerSnapshotGenerator` when the fetch results have changed
 and those changes have been mapped onto a new `NSDiffableDataSourceSnapshot`.
 */
@available(iOS 13.0, *)
public protocol ResultsControllerSnapshotGeneratorDelegate: class {
    associatedtype SectionType: Hashable
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeProducingSnapshot snapshot: NSDiffableDataSourceSnapshot<SectionType, NSManagedObjectID>, withChangedObjects changedObjects: [NSManagedObjectID])
}

/**
 Processes fetch result changes observed by a `NSFetchedResultsController`, and translates those changes into new `NSDiffableDataSourceSnapshot` objects.
 */
@available(iOS 13.0, *)
public final class ResultsControllerSnapshotGenerator<Delegate>: ResultsControllerDelegateForwarderReceiver where Delegate: ResultsControllerSnapshotGeneratorDelegate {

    public typealias Section = Delegate.SectionType

    /**
     The object which should be assignes as a `NSFetchedResultsController`'s `delegate` in order to process its change events.
     */
    public var controllerDelegate: NSFetchedResultsControllerDelegate { resultsContollerDelegateFowarder }

    /**
     The receiver of the mediated mapped object change notifications.
     */
    public weak var delegate: Delegate?

    private let getCurrentSnapshot: () -> NSDiffableDataSourceSnapshot<Section, NSManagedObjectID>
    private let mapSection: (String) -> Section
    private let resultsContollerDelegateFowarder: ResultsControllerDelegateForwarder

    public init(mapSection: ((String) -> Section)? = nil, getCurrentSnapshot: @escaping () -> NSDiffableDataSourceSnapshot<Section, NSManagedObjectID>) {
        self.getCurrentSnapshot = getCurrentSnapshot
        if let mapSection = mapSection {
            self.mapSection = mapSection
        } else if Section.self == String.self {
            self.mapSection = { $0 as! Section }
        } else {
            preconditionFailure()
        }

        // The delegate forwarder forwards the NSFectedResultsControllerDelegate events to this object. This class cannot be a
        // NSFetchedResultsControllerDelegate itself as it has generic parameters.
        self.resultsContollerDelegateFowarder = ResultsControllerDelegateForwarder()
        self.resultsContollerDelegateFowarder.forwardTo = self
    }

    // We cannot keep track of the changes in a DiffableDataSourceSnapshot unfortunately, as the changes may come in in an order
    // which we do not support. For example, it may notify us of new inserts at large indices before inserts at smaller indices.
    // Hence, accumulate all the changes here; when they are all loaded, we will build a new snapshot.
    private var changeProcessingSnapshot: NSDiffableDataSourceSnapshot<Section, NSManagedObjectID>!
    private var oldSectionNames = [String]()
    private var sectionChanges = [CollectionDifference<Section>.Change]()
    private var itemChangesBySection = [Section: [CollectionDifference<NSManagedObjectID>.Change]]()
    private var updatedObjects = Set<NSManagedObjectID>()

    private func addItemChange(_ change: CollectionDifference<NSManagedObjectID>.Change, to section: Section) {
        if let array = itemChangesBySection[section] {
            itemChangesBySection[section] = array + [change]
        } else {
            itemChangesBySection[section] = [change]
        }
    }

    // MARK: FetchedResultsControllerDelegateForwarderReceiver implementation

    public func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // grab a new snapshot, ready to modfiy
        changeProcessingSnapshot = getCurrentSnapshot()

        // Also grab the section names as they are at this point - we may have to refer to old index paths during change processing,
        // and we need a way to get the section name from the section index at that point.
        oldSectionNames = controller.sections!.map(\.name)
        itemChangesBySection = [:]
        sectionChanges = []
        updatedObjects = Set<NSManagedObjectID>()
    }

    public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        guard let itemID = (anObject as? NSManagedObject)?.objectID else { preconditionFailure() }
        assert(!itemID.isTemporaryID, "An object with temporary ID was reported as changed")

        switch type {
        case .insert:
            guard let newIndex = newIndexPath else { preconditionFailure() }
            let section = mapSection(controller.sections![newIndex.section].name)
            // It may seem unnecessary to include newly inserted items in the set of updated objects, and indeed it usually is.
            // However, there is one use case where we need this: if object is one of several which are powering one table view.
            // In that case, although the object may appear competely new to this snapshot, it could have just been deleted from
            // a neighbouring snapshot. In that case, the table view will only move the cell, and not update its value. We need
            // to report that this is an updated object so that consumers can manually call reloadItems for this object.
            updatedObjects.insert(itemID)
            addItemChange(.insert(offset: newIndex.row, element: itemID, associatedWith: nil), to: section)
        case .move:
            guard let oldIndex = indexPath, let newIndex = newIndexPath else { preconditionFailure() }
            let isSameSection = oldIndex.section != newIndex.section

            let oldSection = mapSection(oldSectionNames[oldIndex.section])
            let newSection = isSameSection ? oldSection : mapSection(controller.sections![newIndex.section].name)

            updatedObjects.insert(itemID)
            addItemChange(.insert(offset: newIndex.row, element: itemID, associatedWith: isSameSection ? oldIndex.row : nil), to: newSection)
            addItemChange(.remove(offset: oldIndex.row, element: itemID, associatedWith: isSameSection ? newIndex.row : nil), to: oldSection)
        case .update:
            updatedObjects.insert(itemID)
        case .delete:
            guard let oldIndex = indexPath else { preconditionFailure() }
            let oldSection = mapSection(oldSectionNames[oldIndex.section])
            addItemChange(.remove(offset: oldIndex.row, element: itemID, associatedWith: nil), to: oldSection)
        @unknown default:
            assertionFailure("Unhandled \(NSFetchedResultsChangeType.self) \(type)")
        }
    }

    public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        let section = mapSection(sectionInfo.name)
        switch type {
        case .insert:
            sectionChanges.append(.insert(offset: sectionIndex, element: section, associatedWith: nil))
        case .delete:
            sectionChanges.append(.remove(offset: sectionIndex, element: section, associatedWith: nil))
        default:
            preconditionFailure()
        }
    }

    public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // First handle the section changes
        guard let sectionChangeCollection = CollectionDifference(sectionChanges) else {
            preconditionFailure("Unable to create a collection difference from the changes \(itemChangesBySection)")
        }
        for change in sectionChangeCollection {
            changeProcessingSnapshot.loadSectionChanges(change)
        }

        // Then, for each section which has item changes, handle the item changes
        for (section, rowChanges) in itemChangesBySection {
            guard let rowChangeCollection = CollectionDifference(rowChanges) else { preconditionFailure() }
            for change in rowChangeCollection {
                changeProcessingSnapshot.loadItemChanges(change, inSection: section)
            }
        }

        // Remember to reload the items which have been updated
        let changedItems = Array(updatedObjects)
        changeProcessingSnapshot.reloadItems(changedItems)

        // Now we have finished preparing our modified snapshot, notify the delegate of the new snapshot.
        delegate?.controller(controller, didChangeProducingSnapshot: changeProcessingSnapshot, withChangedObjects: changedItems)
    }
}
