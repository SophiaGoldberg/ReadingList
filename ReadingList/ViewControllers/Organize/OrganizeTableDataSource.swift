import Foundation
import ReadingList_Foundation
import UIKit
import CoreData

protocol OrganizeTableViewDataSourceCommon: UITableViewEmptyDetectingDataSource, NSFetchedResultsControllerDelegate {
    var sortManager: SortManager<List> { get }
    var resultsController: NSFetchedResultsController<List> { get }

    func updateData(animate: Bool)
}

extension OrganizeTableViewDataSourceCommon {
    func canMoveRow(at indexPath: IndexPath) -> Bool {
        guard ListSortOrder.selectedSort == .custom else { return false }
        return resultsController.sections![0].numberOfObjects > 1
    }

    func moveRow(at sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard ListSortOrder.selectedSort == .custom else {
            assertionFailure()
            return
        }

        // We need to disable the change detection while we handle the move (since the cells are already in the right location,
        // because of the move, and we don't want to attempt to re-animate the move). Grab a reference to the results controller
        // delegate object to hold locally while the delegate is set to nil for the duration of the operation.
        let delegateReference = resultsController.delegate
        resultsController.delegate = nil

        sortManager.move(objectAt: sourceIndexPath, to: destinationIndexPath)
        try! resultsController.performFetch()
        PersistentStoreManager.container.viewContext.saveAndLogIfErrored()

        // Delay slightly so that the UI update doesn't interfere with the animation of the row reorder completing.
        // This is quite ugly code, but leads to a less ugly UI.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [unowned self] in
            self.updateData(animate: false)
        }

        resultsController.delegate = delegateReference
    }
}

@available(iOS 13.0, *)
final class OrganizeTableViewDataSource: EmptyDetectingTableDiffableDataSource<String, NSManagedObjectID>, OrganizeTableViewDataSourceCommon {
    let sortManager: SortManager<List>
    let resultsController: NSFetchedResultsController<List>
    var changeMediator: ResultsControllerSnapshotGenerator<OrganizeTableViewDataSource>!

    init(tableView: UITableView, resultsController: NSFetchedResultsController<List>) {
        self.resultsController = resultsController
        self.sortManager = SortManager(tableView) {
            resultsController.object(at: $0)
        }

        super.init(tableView: tableView) { _, indexPath, _ in
            let cell = tableView.dequeueReusableCell(withIdentifier: "ListCell", for: indexPath)
            cell.configure(from: resultsController.object(at: indexPath))
            return cell
        }
        changeMediator = ResultsControllerSnapshotGenerator { [unowned self] in
            self.snapshot()
        }
        changeMediator.delegate = self

        resultsController.delegate = changeMediator.controllerDelegate
    }

    func updateData(animate: Bool) {
        apply(resultsController.snapshot(), animatingDifferences: animate)
    }

    final override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return canMoveRow(at: indexPath)
    }

    final override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        moveRow(at: sourceIndexPath, to: destinationIndexPath)
    }

    final override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
}

@available(iOS 13.0, *)
extension OrganizeTableViewDataSource: ResultsControllerSnapshotGeneratorDelegate {
    typealias SectionType = String

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeProducingSnapshot snapshot: NSDiffableDataSourceSnapshot<String, NSManagedObjectID>, withChangedObjects changedObjects: [NSManagedObjectID]) {
        apply(snapshot, animatingDifferences: true)
    }
}

@available(iOS, obsoleted: 13.0)
final class OrganizeTableViewDataSourceLegacy: LegacyEmptyDetectingTableDataSource, OrganizeTableViewDataSourceCommon {
    let sortManager: SortManager<List>
    let resultsController: NSFetchedResultsController<List>

    init(_ tableView: UITableView, resultsController: NSFetchedResultsController<List>) {
        self.resultsController = resultsController
        self.sortManager = SortManager(tableView) {
            resultsController.object(at: $0)
        }
        super.init(tableView)

        self.resultsController.delegate = self
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ListCell", for: indexPath)
        cell.configure(from: resultsController.object(at: indexPath))
        return cell
    }

    final override func sectionCount(in tableView: UITableView) -> Int {
        return resultsController.sections!.count
    }

    final override func rowCount(in tableView: UITableView, forSection section: Int) -> Int {
        return resultsController.sections![section].numberOfObjects
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return canMoveRow(at: indexPath)
    }

    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        moveRow(at: sourceIndexPath, to: destinationIndexPath)
    }

    func updateData(animate: Bool) {
        // Brute force approach for pre-iOS 13
        tableView.reloadData()
    }
}

@available(iOS, obsoleted: 13.0)
extension OrganizeTableViewDataSourceLegacy: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }

    func controllerDidChangeContent(_: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        tableView.controller(controller, didChange: anObject, at: indexPath, for: type, newIndexPath: newIndexPath)
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        tableView.controller(controller, didChange: sectionInfo, atSectionIndex: sectionIndex, for: type)
    }
}
