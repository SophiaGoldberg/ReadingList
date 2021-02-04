import Foundation
import UIKit
import CoreData
import ReadingList_Foundation

final class ListBookTable: UITableViewController {

    var list: List!
    private var cachedListNames: [String]!
    private var ignoreNotifications = false

    private var searchController: UISearchController!
    private var dataSource: ListBookDataSource!
    private var emptyStateManager: ListBookTableEmptyDataSetManager!

    private var listNameField: UITextField? {
        get { return navigationItem.titleView as? UITextField }
        set { navigationItem.titleView = newValue }
    }

    private var listNameFieldDefaultText: String {
        return "\(list.name)⌄"
    }

    private var defaultPredicate: NSPredicate {
        return NSPredicate.and([
            NSPredicate(format: "%@ = %K", list, #keyPath(ListItem.list)),
            // Filter out any orphaned ListItem objects
            NSPredicate(format: "%K != nil", #keyPath(ListItem.book))
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(BookTableViewCell.self)
        tableView.register(BookTableHeader.self)

        // Cache the list names so we know which names are disallowed when editing this list's name
        cachedListNames = List.names(fromContext: PersistentStoreManager.container.viewContext)
        navigationItem.title = list.name
        navigationItem.rightBarButtonItem = editButtonItem

        searchController = UISearchController(filterPlaceholderText: "Filter List")
        searchController.searchResultsUpdater = self
        searchController.delegate = self
        navigationItem.searchController = searchController

        dataSource = ListBookDiffableDataSource(tableView, list: list, controller: buildResultsControllerAndFetch(), searchController: searchController, onContentChanged: reloadHeaders)

        // Configure the empty state manager to detect when the table becomes empty
        emptyStateManager = ListBookTableEmptyDataSetManager(tableView: tableView, navigationBar: navigationController?.navigationBar, navigationItem: navigationItem, searchController: searchController, list: list)
        dataSource.emptyDetectionDelegate = emptyStateManager
        dataSource.updateData(animate: false)

        NotificationCenter.default.addObserver(self, selector: #selector(objectContextChanged(_:)),
                                               name: .NSManagedObjectContextObjectsDidChange,
                                               object: PersistentStoreManager.container.viewContext)
    }

    private func buildResultsControllerAndFetch() -> NSFetchedResultsController<ListItem> {
        let fetchRequest = NSManagedObject.fetchRequest(ListItem.self, batch: 50)
        fetchRequest.predicate = defaultPredicate
        fetchRequest.sortDescriptors = list.order.listItemSortDescriptors
        fetchRequest.relationshipKeyPathsForPrefetching = [#keyPath(ListItem.book)]

        // Use a constant property as the sectionNameKeyPath - this will ensure that there are no sections when there are no
        // results, and thus cause the section headers to be removed when the results count goes to 0.
        let controller = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                    managedObjectContext: PersistentStoreManager.container.viewContext,
                                                    sectionNameKeyPath: #keyPath(Book.constantEmptyString), cacheName: nil)
        try! controller.performFetch()
        return controller
    }

    private func listTextField(for navigationBar: UINavigationBar) -> UITextField {
        let textField = UITextField(frame: navigationBar.frame.inset(by: UIEdgeInsets(top: 0, left: 115, bottom: 0, right: 115)))
        textField.text = listNameFieldDefaultText
        textField.textAlignment = .center
        textField.font = UIFont.systemFont(ofSize: 17.0, weight: .semibold)
        textField.enablesReturnKeyAutomatically = true
        textField.returnKeyType = .done
        textField.delegate = self
        textField.addTarget(self, action: #selector(self.configureNavigationItem), for: .editingChanged)
        return textField
    }

    private func canUpdateListName(to name: String) -> Bool {
        guard !name.isEmptyOrWhitespace else { return false }
        return name == list.name || !cachedListNames.contains(name)
    }

    @discardableResult private func tryUpdateListName(to name: String) -> Bool {
        if canUpdateListName(to: name) {
            UserEngagement.logEvent(.renameList)
            list.name = name
            list.managedObjectContext!.saveAndLogIfErrored()
            return true
        } else {
            return false
        }
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)

        // If we go from editing to not editing, and we are (/were) editing the title text field, then
        // save the update (if we can), and stop editing it.
        if !editing, let listNameField = listNameField, listNameField.isEditing {
            if let proposedName = listNameField.text, list.name != proposedName {
                tryUpdateListName(to: proposedName)
            }
            listNameField.endEditing(true)
        }
        configureNavigationItem()
        reloadHeaders()
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section == 0 && tableView.numberOfRows(inSection: 0) > 0 else { return nil }
        let header = tableView.dequeue(BookTableHeader.self)
        header.presenter = self
        header.onSortChanged = { [weak self] in
            self?.sortOrderChanged()
        }
        configureHeader(header, at: section)
        return header
    }

    @objc private func configureNavigationItem() {
        guard let editDoneButton = navigationItem.rightBarButtonItem else { assertionFailure(); return }
        editDoneButton.isEnabled = {
            if let listNameField = listNameField {
                if !listNameField.isEditing { return true }
                if let newName = listNameField.text, canUpdateListName(to: newName) { return true }
                return false
            }
            return true
        }()
        searchController.searchBar.isEnabled = !isEditing
        if isEditing {
            if listNameField == nil {
                guard let navigationBar = navigationController?.navigationBar else {
                    assertionFailure("Unexpected missing navigation bar")
                    return
                }
                listNameField = listTextField(for: navigationBar)
                navigationItem.title = nil
            }
        } else {
            if let textField = listNameField {
                textField.removeFromSuperview()
                listNameField = nil
            }
            navigationItem.title = list.name
        }
    }

    private func sortOrderChanged() {
        if searchController.isActive {
            // We don't allow sort order change while the search controller is active; if it does, stop the search.
            assertionFailure()
            searchController.isActive = false
        }
        // Results controller delegates don't seem to play nicely with changing sort descriptors. So instead, we rebuild the whole
        // result controller.
        self.dataSource.controller = buildResultsControllerAndFetch()
        dataSource.updateData(animate: true)

        // Put the top row at the "middle", so that the top row is not right up at the top of the table
        //is this needed? tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .middle, animated: false)
        UserEngagement.logEvent(.changeListSortOrder)
    }

    @objc private func objectContextChanged(_ notification: Notification) {
        guard !ignoreNotifications else { return }
        guard let userInfo = notification.userInfo else { return }

        if let deletedObjects = userInfo[NSDeletedObjectsKey] as? NSSet, deletedObjects.contains(list!) {
            // If the list was deleted, pop back. This can't happen through any normal means at the moment.
            navigationController?.popViewController(animated: false)
            return
        }

        // Repopulate the list names cache
        cachedListNames = List.names(fromContext: PersistentStoreManager.container.viewContext)
    }

    private func ignoringSaveNotifications(_ block: () -> Void) {
        ignoreNotifications = true
        block()
        ignoreNotifications = false
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        performSegue(withIdentifier: "showDetail", sender: indexPath)
    }

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        return !tableView.isEditing
    }

    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        return [UITableViewRowAction(style: .destructive, title: "Remove") { _, indexPath in
            self.dataSource.controller.object(at: indexPath).deleteAndSave()
            UserEngagement.logEvent(.removeBookFromList)
        }]
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let detailsViewController = (segue.destination as? UINavigationController)?.topViewController as? BookDetailsHostingController {
            guard let senderIndex = sender as? IndexPath else { preconditionFailure() }
            let book = dataSource.getBook(at: senderIndex)
            detailsViewController.setBook(book)
        }
    }
}

extension ListBookTable: UISearchControllerDelegate {
    func didDismissSearchController(_ searchController: UISearchController) {
        // If we caused all data to be deleted while searching, the empty state view might now need to be a "no books" view
        // rather than a "no results" view.
        emptyStateManager.reloadEmptyStateView()
    }
}

extension ListBookTable: UISearchResultsUpdating {
    private func getSearchPredicate() -> NSPredicate? {
        guard let searchTerms = searchController.searchBar.text else { return nil }
        if searchTerms.isEmptyOrWhitespace || searchTerms.trimming().count < 2 {
            return nil
        } else {
            return NSPredicate.wordsWithinFields(searchTerms, fieldNames: #keyPath(ListItem.book.title), #keyPath(ListItem.book.authorSort), "ANY \(#keyPath(ListItem.book.subjects)).name")
        }
    }

    func updateSearchResults(for searchController: UISearchController) {
        let searchPredicate = getSearchPredicate()
        if let searchPredicate = searchPredicate {
            dataSource.controller.fetchRequest.predicate = NSPredicate.and([defaultPredicate, searchPredicate])
        } else {
            dataSource.controller.fetchRequest.predicate = defaultPredicate
        }
        try! dataSource.controller.performFetch()

        dataSource.updateData(animate: true)
    }
}

extension ListBookTable: HeaderConfigurable {
    func configureHeader(_ header: UITableViewHeaderFooterView, at index: Int) {
        guard let header = header as? BookTableHeader else { preconditionFailure() }
        let numberOfRows = dataSource.controller.sections![0].numberOfObjects
        header.configure(list: list, bookCount: numberOfRows, enableSort: !isEditing && !searchController.isActive)
    }
}

extension ListBookTable: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        textField.text = list.name
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.text = listNameFieldDefaultText
        // If we renamed the list, refresh the empty data set - if present
        if list.items.isEmpty {
            tableView.reloadData()
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let newText = textField.text, tryUpdateListName(to: newText) else { return false }
        textField.resignFirstResponder()
        return true
    }
}
