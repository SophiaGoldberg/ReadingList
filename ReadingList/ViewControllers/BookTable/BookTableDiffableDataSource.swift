import ReadingList_Foundation
import UIKit
import CoreData

/// The common functions exposed by all BookTable data sources
protocol BookTableDataSourceCommon: UITableViewEmptyDetectingDataSource, NSFetchedResultsControllerDelegate {
    var sortManager: SortManager<Book> { get }
    var searchController: UISearchController { get }

    /// Replaces the set of results controllers which are in use in this data source.
    func replaceControllers(_ controllers: [NSFetchedResultsController<Book>])

    /// Updates the data held by the data source and applies changes to the table which it drives.
    func updateData(animate: Bool)

    /// Returns the current number of sections in the table.
    func sectionCount() -> Int

    /// Returns the number of rows in the specified section.
    func rowCount(in section: Int) -> Int

    /// Returns the `BookReadState` corrresponding to the specified section.
    func readState(forSection section: Int) -> BookReadState

    /// Returns the `Book` corresponding to a given `IndexPath`.
    func object(at indexPath: IndexPath) -> Book

    /// Returns the `IndexPath` at which a given book is located, if found.
    func indexPath(for book: Book) -> IndexPath?

    /// Perform a fetch on all contained results controllers.
    func performFetch() throws
}

extension BookTableDataSourceCommon {
    /// Returns the read state associated with a `BookReadState` section name, which are the string representations of the backing raw integers.
    /// E.g., provided the string "1", would return `BookReadState.reading`. If the provided string is not valid, will throw an error.
    func readState(forSectionName sectionName: String) -> BookReadState {
        guard let sectionNameInt = Int16(sectionName), let readState = BookReadState(rawValue: sectionNameInt) else {
            preconditionFailure("Unexpected section name \"\(sectionName)\"")
        }
        return readState
    }

    /// Returns whether the row at the specified `IndexPath` can be moved. This will return true only if: there is no active search currently in operation; the sort setting of
    /// the `BookReadState` corresponding to `indexPath` is set to `BookSort.custom`; there is more than one row in the section.
    func canMoveRow(at indexPath: IndexPath) -> Bool {
        // Disable reorderng when searching, or when the sort order is not custom
        guard !searchController.hasActiveSearchTerms else { return false }
        let readState = self.readState(forSection: indexPath.section)
        guard BookSort.byReadState[readState] == .custom else { return false }

        // We can reorder the books if there are more than one
        return rowCount(in: indexPath.section) > 1
    }

    /// Adjusts the sort indexes to faciliate a move of a book from the `sourceIndexPath` to the `destinationIndexPath`, and performs a fetch of all results controllers.
    func moveRow(at sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        // We should only have movement within a section
        guard sourceIndexPath.section == destinationIndexPath.section else { return }
        let readState = self.readState(forSection: sourceIndexPath.section)
        guard BookSort.byReadState[readState] == .custom else { return }

        sortManager.move(objectAt: sourceIndexPath, to: destinationIndexPath)
        PersistentStoreManager.container.viewContext.saveAndLogIfErrored()
        try! performFetch()
    }
}

/// A non-diffable BookTable data source. Uses the legacy APIs `numberOfSections(in:)` and `tableView(_:numberOfRowsInSection:)`.
@available(iOS, obsoleted: 13.0)
final class BookTableLegacyDataSource: LegacyEmptyDetectingTableDataSource, BookTableDataSourceCommon {
    private var compoundResultsController: CompoundFetchedResultsController<Book>
    private let onContentChanged: () -> Void

    let sortManager: SortManager<Book>
    let searchController: UISearchController

    /**
      - Parameters:
         - onContentChanged: Called once a data model change has completed procesing.
     */
    init(_ tableView: UITableView, controllers: [NSFetchedResultsController<Book>], sortManager: SortManager<Book>, searchController: UISearchController, onContentChanged: @escaping () -> Void) {
        self.compoundResultsController = CompoundFetchedResultsController(controllers: controllers)
        self.sortManager = sortManager
        self.searchController = searchController
        self.onContentChanged = onContentChanged
        super.init(tableView)
        self.compoundResultsController.delegate = self
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeue(BookTableViewCell.self, for: indexPath)
        let book = compoundResultsController.object(at: indexPath)
        cell.configureFrom(book)
        cell.initialise(withTheme: GeneralSettings.theme)
        return cell
    }

    func replaceControllers(_ controllers: [NSFetchedResultsController<Book>]) {
        // Build a new CompoundFetchedResultsController from the provided controllers, setting the delegate to this instance.
        // The previous CompoundFetchedResultsController will be deallocated so no need to clear out its delegate property.
        compoundResultsController = CompoundFetchedResultsController(controllers: controllers)
        compoundResultsController.delegate = self
    }

    func performFetch() throws {
        try compoundResultsController.performFetch()
    }

    func indexPath(for book: Book) -> IndexPath? {
        return compoundResultsController.indexPath(forObject: book)
    }

    func readState(forSection section: Int) -> BookReadState {
        // Get the name of this section from the CompoundFetchedResultsController, and then map that string to a BookReadState.
        guard let sectionInfo = compoundResultsController.sections else { preconditionFailure() }
        return readState(forSectionName: sectionInfo[section].name)
    }

    func rowCount(in section: Int) -> Int {
        guard let sectionInfo = compoundResultsController.sections else { preconditionFailure() }
        return sectionInfo[section].numberOfObjects
    }

    func sectionCount() -> Int {
        guard let sectionInfo = compoundResultsController.sections else { preconditionFailure() }
        return sectionInfo.count
    }

    func updateData(animate: Bool) {
        // In this legacy data source, we cannot (easily) differentially update the table view. Instead, we just reload the whole
        // table, without animation, ignoring the `animate` parameter.
        tableView.reloadData()
    }

    func object(at indexPath: IndexPath) -> Book {
        return compoundResultsController.object(at: indexPath)
    }

    // Implement the overrides of the class's section and row counting functions to delegate to the functions which are required
    // for protocol conformance.
    override func sectionCount(in tableView: UITableView) -> Int {
        return sectionCount()
    }

    override func rowCount(in tableView: UITableView, forSection section: Int) -> Int {
        return rowCount(in: section)
    }

    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return canMoveRow(at: indexPath)
    }

    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        compoundResultsController.delegate = nil
        moveRow(at: sourceIndexPath, to: destinationIndexPath)
        compoundResultsController.delegate = self
    }

    // MARK: NSFetchedResultsControllerDelegate implementation

    func controllerWillChangeContent(_: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }

    func controllerDidChangeContent(_: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
        onContentChanged()
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        tableView.controller(controller, didChange: anObject, at: indexPath, for: type, newIndexPath: newIndexPath)
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        tableView.controller(controller, didChange: sectionInfo, atSectionIndex: sectionIndex, for: type)
    }
}

/// A diffable BookTable data source. Uses `NSDiffableDataSourceSnapshot` generation.
@available(iOS 13.0, *)
final class BookTableDiffableDataSource: EmptyDetectingTableDiffableDataSource<BookReadState, NSManagedObjectID>, BookTableDataSourceCommon {
    let sortManager: SortManager<Book>
    let searchController: UISearchController
    private let onContentChanged: () -> Void

    /// The ordered array of fetched results controllers which are used to fetch data for the table.
    private var controllers: [NSFetchedResultsController<Book>]

    /// The array of objects which observe changes detected by a fetched results controller, and produce equivalent diffable data source snapshots.
    private var snapshotGenerators = [ResultsControllerSnapshotGenerator<BookTableDiffableDataSource>]()

    /// Contains cached data source snapshots, keyed by the `ObjectIdentifier` of the corresponding fetched results controller.
    /// We use this dictionary since we have multiple fetched resuls controllers, which we want to combine together into a single aggregated
    /// snapshot which will be used by this data source. Thus, we keep a cached snapshot per controller, which we update when the controller
    /// detects changes. When any changes occur, we aggregate all the cached snapshots into one and apply that result.
    private var cachedSnapshotsByControllerIdentifier = [ObjectIdentifier: NSDiffableDataSourceSnapshot<BookReadState, NSManagedObjectID>]()

    init(_ tableView: UITableView, controllers: [NSFetchedResultsController<Book>], sortManager: SortManager<Book>, searchController: UISearchController, onContentChanged: @escaping () -> Void) {
        self.controllers = controllers
        self.sortManager = sortManager
        self.searchController = searchController
        self.onContentChanged = onContentChanged

        super.init(tableView: tableView) { _, indexPath, itemId in
            let cell = tableView.dequeue(BookTableViewCell.self, for: indexPath)
            let book = PersistentStoreManager.container.viewContext.object(with: itemId) as! Book
            cell.configureFrom(book)
            return cell
        }

        configureControllers()
    }

    func replaceControllers(_ controllers: [NSFetchedResultsController<Book>]) {
        self.controllers = controllers
        configureControllers()
    }

    private func configureControllers() {
        // Ensure that we discard the snapshot generators so we don't keep unnecessary references to the fetched results controllers.
        // We also can discard any cached snapshots since we will regenerate them now.
        snapshotGenerators.removeAll(keepingCapacity: true)
        cachedSnapshotsByControllerIdentifier.removeAll(keepingCapacity: true)

        for controller in controllers {
            let snapshotGenerator = ResultsControllerSnapshotGenerator<BookTableDiffableDataSource>(mapSection: self.readState(forSectionName:)) { [unowned self] in
                guard let currentSnapshot = self.cachedSnapshotsByControllerIdentifier[ObjectIdentifier(controller)] else { preconditionFailure("No cached snapshot available") }
                return currentSnapshot
            }
            // The controller delegates to the snapshot generator, and the snapshot generator delegates to this object.
            controller.delegate = snapshotGenerator.controllerDelegate
            snapshotGenerator.delegate = self

            snapshotGenerators.append(snapshotGenerator)
        }
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func rowCount(in section: Int) -> Int {
        let snapshot = self.snapshot()
        return snapshot.numberOfItems(inSection: snapshot.sectionIdentifiers[section])
    }

    func sectionCount() -> Int {
        return snapshot().sectionIdentifiers.count
    }

    private func loadSnapshotFromCache() -> NSDiffableDataSourceSnapshot<BookReadState, NSManagedObjectID> {
        var aggregatedSnapshot = NSDiffableDataSourceSnapshot<BookReadState, NSManagedObjectID>()

        // For each controller, find the previously-cached snapshot for that controller, and append it into the aggregated snapshot.
        for controller in controllers {
            guard let cachedSnapshot = cachedSnapshotsByControllerIdentifier[ObjectIdentifier(controller)] else { preconditionFailure() }
            aggregatedSnapshot.append(cachedSnapshot)
        }
        return aggregatedSnapshot
    }

    func updateData(animate: Bool) {
        // First cache snapshots generated from each controller
        for controller in controllers {
            cachedSnapshotsByControllerIdentifier[ObjectIdentifier(controller)] = NSDiffableDataSourceSnapshot(controller, mappingSections: self.readState(forSectionName:))
        }

        // Then load the aggregated snapshot from the cached ones
        let snapshot = loadSnapshotFromCache()
        apply(snapshot, animatingDifferences: animate)
    }

    func object(at indexPath: IndexPath) -> Book {
        // Getting from an index path back to the individual controller is a little involved (in fact, that is what the whole CompoundFetchedResultsController)
        // was for. Instead, since have have a handy function for mapping to the item identifier built in (i.e. the mapping to the object ID), we just map
        // to that ID, and then obtain the corresponding object from the view context. This shouldn't load the object again if the controllers have already
        // loaded the books in the view context already.
        guard let itemId = itemIdentifier(for: indexPath) else { preconditionFailure() }
        return PersistentStoreManager.container.viewContext.object(with: itemId) as! Book
    }

    func readState(forSection section: Int) -> BookReadState {
        return snapshot().sectionIdentifiers[section]
    }

    func performFetch() throws {
        for controller in controllers {
            try controller.performFetch()
        }
    }

    func indexPath(for book: Book) -> IndexPath? {
        return indexPath(for: book.objectID)
    }

    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return canMoveRow(at: indexPath)
    }

    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        // Stop the chain of change detection prior to performing the move, and then reenable it afterwards. We don't want the save
        // corresponding to the move to trigger a further update of the UI, since the move is performed by dragging the rows to their
        // desired place: the UI is already updated.
        snapshotGenerators.forEach { $0.delegate = nil }
        moveRow(at: sourceIndexPath, to: destinationIndexPath)
        snapshotGenerators.forEach { $0.delegate = self }

        // Delay slightly so that the UI update doesn't interfere with the animation of the row reorder completing.
        // This is quite ugly code, but leads to a less ugly UI.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [unowned self] in
            self.updateData(animate: false)
        }
    }
}

@available(iOS 13.0, *)
extension BookTableDiffableDataSource: ResultsControllerSnapshotGeneratorDelegate {
    typealias SectionType = BookReadState

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeProducingSnapshot snapshot: NSDiffableDataSourceSnapshot<BookReadState, NSManagedObjectID>, withChangedObjects changedObjects: [NSManagedObjectID]) {
        // Store the new snapshot in the cache
        cachedSnapshotsByControllerIdentifier[ObjectIdentifier(controller)] = snapshot

        // Then build a new snapshot by merging together all the cached ones. We need to reload the items as indicated,
        // as building a new snapshot loses that information since it is not publicly exposed.
        var snapshot = loadSnapshotFromCache()
        snapshot.reloadValidItems(changedObjects)
        apply(snapshot, animatingDifferences: true)
        self.onContentChanged()
    }
}
