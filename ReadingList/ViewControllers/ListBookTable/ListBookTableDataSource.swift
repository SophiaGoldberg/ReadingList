import Foundation
import CoreData
import UIKit
import ReadingList_Foundation

protocol ListBookDataSource: class, UITableViewEmptyDetectingDataSource {
    func updateData(animate: Bool)
    var controller: NSFetchedResultsController<ListItem> { get set }
    var list: List { get }
    var searchController: UISearchController { get }
    var sortManager: SortManager<ListItem> { get }
}

extension ListItem: Sortable {
    var sortIndex: Int32 {
        get { sort }
        set { sort = newValue }
    }
}

extension ListBookDataSource {
    func getBook(at indexPath: IndexPath) -> Book {
        return controller.object(at: indexPath).book
    }

    func canMoveRow() -> Bool {
        guard list.order == .listCustom else { return false }
        guard !searchController.hasActiveSearchTerms else { return false }
        return list.items.count > 1
    }

    func moveRow(at sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard list.order == .listCustom else { return }
        guard !searchController.hasActiveSearchTerms else { return }
        guard sourceIndexPath != destinationIndexPath else { return }

        // Disable change notification updates
        let controllerDelegate = controller.delegate
        controller.delegate = nil

        sortManager.move(objectAt: sourceIndexPath, to: destinationIndexPath)
        list.managedObjectContext!.saveAndLogIfErrored()
        try! controller.performFetch()

        // Reneable change notification updates.
        controller.delegate = controllerDelegate
        UserEngagement.logEvent(.reorderList)

        // Delay slightly so that the UI update doesn't interfere with the animation of the row reorder completing.
        // This is quite ugly code, but leads to a less ugly UI.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [unowned self] in
            self.updateData(animate: false)
        }
    }
}

final class ListBookDiffableDataSource: EmptyDetectingTableDiffableDataSource<String, NSManagedObjectID>, ResultsControllerSnapshotGeneratorDelegate, ListBookDataSource {

    typealias SectionType = String
    var controller: NSFetchedResultsController<ListItem> {
        get { wrappedController.wrappedValue }
        set {
            // Remove the old controller's delegate (just in case we have a memory leak and it isn't deallocated)
            // and assign the new value's delegate.
            wrappedController.wrappedValue.delegate = nil
            wrappedController.wrappedValue = newValue
            newValue.delegate = self.changeMediator.controllerDelegate
        }
    }
    private let wrappedController: Wrapped<NSFetchedResultsController<ListItem>>
    var changeMediator: ResultsControllerSnapshotGenerator<ListBookDiffableDataSource>!
    let list: List
    let searchController: UISearchController
    let onContentChanged: () -> Void
    let sortManager: SortManager<ListItem>

    init(_ tableView: UITableView, list: List, controller: NSFetchedResultsController<ListItem>, searchController: UISearchController, onContentChanged: @escaping () -> Void) {
        self.searchController = searchController
        self.list = list
        self.onContentChanged = onContentChanged

        // This wrapping business gets around the inabiliy to refer to self in the closure passed to super.init.
        // We need to refer to the data provider which self will have at the time the closure is run. To achieve this,
        // create a simple wrapping object: this reference stays the same, but _its_ reference can change later on.
        let wrappedController = Wrapped(controller)
        self.wrappedController = wrappedController

        self.sortManager = SortManager<ListItem>(tableView) {
            wrappedController.wrappedValue.object(at: $0)
        }
        super.init(tableView: tableView) { _, indexPath, _ in
            let cell = tableView.dequeue(BookTableViewCell.self, for: indexPath)
            let book = wrappedController.wrappedValue.object(at: indexPath).book
            cell.configureFrom(book, includeReadDates: false)
            return cell
        }

        self.changeMediator = ResultsControllerSnapshotGenerator<ListBookDiffableDataSource> { [unowned self] in
            self.snapshot()
        }
        self.changeMediator.delegate = self
        self.controller.delegate = self.changeMediator.controllerDelegate
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return canMoveRow()
    }

    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        moveRow(at: sourceIndexPath, to: destinationIndexPath)
    }

    func updateData(animate: Bool) {
        apply(controller.snapshot(), animatingDifferences: animate)
        onContentChanged()
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeProducingSnapshot snapshot: NSDiffableDataSourceSnapshot<String, NSManagedObjectID>, withChangedObjects changedObjects: [NSManagedObjectID]) {
        apply(snapshot, animatingDifferences: true)
        onContentChanged()
    }
}
