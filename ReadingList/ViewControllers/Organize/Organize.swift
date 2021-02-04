import Foundation
import UIKit
import CoreData
import ReadingList_Foundation

extension List: Sortable {
    public var sortIndex: Int32 {
        get { return sort }
        set(newValue) { sort = newValue }
    }
}

extension UITableViewCell {
    func configure(from list: List) {
        textLabel!.text = list.name
        detailTextLabel!.text = "\(list.items.count) book\(list.items.count == 1 ? "" : "s")"
    }
}

final class Organize: UITableViewController {

    var searchController: UISearchController!
    var dataSource: OrganizeTableViewDataSourceCommon!
    var emptyDataSetManager: OrganizeEmptyDataSetManager!

    override func viewDidLoad() {
        super.viewDidLoad()
        clearsSelectionOnViewWillAppear = true

        tableView.register(BookTableHeader.self)

        searchController = UISearchController(filterPlaceholderText: "Your Lists")
        searchController.searchResultsUpdater = self
        searchController.delegate = self
        navigationItem.searchController = searchController

        dataSource = OrganizeTableViewDataSource(tableView: tableView, resultsController: buildResultsController())
        emptyDataSetManager = OrganizeEmptyDataSetManager(tableView: tableView, navigationBar: navigationController?.navigationBar, navigationItem: navigationItem, searchController: searchController) { [weak self] _ in
            self?.configureNavigationBarButtons()
        }
        dataSource.emptyDetectionDelegate = emptyDataSetManager

        // Perform the initial data source load, and then configure the navigation bar buttons, which depend on the empty state of the table
        try! dataSource.resultsController.performFetch()
        dataSource.updateData(animate: false)
        configureNavigationBarButtons()
    }

    private func configureNavigationBarButtons() {
        navigationItem.leftBarButtonItem = emptyDataSetManager.isShowingEmptyState ? nil : self.editButtonItem
    }

    private func buildResultsController() -> NSFetchedResultsController<List> {
        let fetchRequest = NSManagedObject.fetchRequest(List.self, batch: 25)
        fetchRequest.sortDescriptors = sortDescriptors()
        fetchRequest.relationshipKeyPathsForPrefetching = [#keyPath(List.items)]

        // Use a constant property as the sectionNameKeyPath - this will ensure that there are no sections when there are no
        // results, and thus cause the section headers to be removed when the results count goes to 0.
        return NSFetchedResultsController<List>(fetchRequest: fetchRequest, managedObjectContext: PersistentStoreManager.container.viewContext,
                                                sectionNameKeyPath: #keyPath(List.constantEmptyString), cacheName: nil)
    }

    private func sortDescriptors() -> [NSSortDescriptor] {
        var sortDescriptors = [NSSortDescriptor(\List.name)]
        switch ListSortOrder.selectedSort {
        case .custom:
            sortDescriptors.insert(NSSortDescriptor(\List.sort), at: 0)
        case .alphabetical:
            break
        }
        return sortDescriptors
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        searchController.searchBar.isEnabled = !editing
        reloadHeaders()
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard !emptyDataSetManager.isShowingEmptyState else { return .leastNonzeroMagnitude }
        return BookTableHeader.height
    }

    func regenerateHeaderSortButtonMenuOrAlert(_ header: BookTableHeader) {
        let selectedSort = ListSortOrder.selectedSort
        header.presenter = self
        header.alertOrMenu = AlertOrMenu(title: "Choose Order", items: ListSortOrder.allCases.map { sort in
            AlertOrMenu.Item(title: sort == selectedSort ? "\(sort.description) ✓" : sort.description) { [weak self] in
                guard let `self` = self else { return }
                guard ListSortOrder.selectedSort != sort else { return }
                ListSortOrder.selectedSort = sort
                self.dataSource.resultsController.fetchRequest.sortDescriptors = self.sortDescriptors()
                try! self.dataSource.resultsController.performFetch()
                self.dataSource.updateData(animate: true)

                // Regenerate the header menu so that the menu's ticks appear in the correct place next time
                self.regenerateHeaderSortButtonMenuOrAlert(header)
            }
        })
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard !emptyDataSetManager.isShowingEmptyState else { return nil }
        let header = tableView.dequeue(BookTableHeader.self)
        configureHeader(header, at: section)
        regenerateHeaderSortButtonMenuOrAlert(header)
        return header
    }

    private func renameList(_ list: List, completion: ((Bool) -> Void)? = nil) {
        let existingListNames = List.names(fromContext: PersistentStoreManager.container.viewContext)
        let renameListAlert = TextBoxAlert(title: "Rename List", message: "Choose a new name for this list", initialValue: list.name, placeholder: "New list name", textValidator: { listName in
                guard let listName = listName, !listName.isEmptyOrWhitespace else { return false }
                return listName == list.name || !existingListNames.contains(listName)
            }, onCancel: {
                completion?(false)
            }, onOK: {
                guard let listName = $0 else { return }
                UserEngagement.logEvent(.renameList)
                list.managedObjectContext!.performAndSave {
                    list.name = listName
                }
                completion?(true)
            }
        )

        self.present(renameListAlert, animated: true)
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        return UISwipeActionsConfiguration(performFirstActionWithFullSwipe: false, actions: [
            UIContextualAction(style: .destructive, title: "Delete") { _, _, callback in
                self.deleteList(forRowAt: indexPath) { didDelete in
                    callback(didDelete)
                }
            },
            UIContextualAction(style: .normal, title: "Rename") { _, _, callback in
                self.setEditing(false, animated: true)
                let list = self.dataSource.resultsController.object(at: indexPath)
                self.renameList(list) { didRename in
                    callback(didRename)
                }
            }
        ])
    }

    @IBAction private func addWasTapped(_ sender: UIBarButtonItem) {
        present(ManageLists.newListAlertController([]) { list in
            guard let indexPath = self.dataSource.resultsController.indexPath(forObject: list) else {
                assertionFailure()
                return
            }
            self.tableView.scrollToRow(at: indexPath, at: .top, animated: true)
        }, animated: true)
    }

    func deleteList(forRowAt indexPath: IndexPath, didDelete: ((Bool) -> Void)? = nil) {
        let confirmDelete = UIAlertController(title: "Confirm delete", message: nil, preferredStyle: .actionSheet)

        confirmDelete.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            self.dataSource.resultsController.object(at: indexPath).deleteAndSave()
            UserEngagement.logEvent(.deleteList)
            self.setEditing(false, animated: true)
            didDelete?(true)
        })
        confirmDelete.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            didDelete?(false)
        })

        confirmDelete.popoverPresentationController?.setSourceCell(atIndexPath: indexPath, inTable: tableView)
        present(confirmDelete, animated: true, completion: nil)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let listBookTable = segue.destination as? ListBookTable {
            let list: List
            if let index = sender as? IndexPath {
                list = dataSource.resultsController.object(at: index)
            } else if let cell = sender as? UITableViewCell, let index = tableView.indexPath(for: cell) {
                list = dataSource.resultsController.object(at: index)
            } else { preconditionFailure() }

            listBookTable.list = list
        }
    }

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        // No segue in edit mode
        return !tableView.isEditing
    }

    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        // the PreviewProvider doesn't seem to work when instantiating the ListBookTable - all the cells become really
        // big, and that persists when you open from the preview.
        return UIContextMenuConfiguration(identifier: indexPath as NSIndexPath, previewProvider: nil) { _ in
            UIMenu(title: "", children: [
                UIAction(title: "Rename", image: UIImage(systemName: "pencil")) { _ in
                    let list = self.dataSource.resultsController.object(at: indexPath)
                    self.renameList(list)
                },
                UIAction(title: "Delete", image: UIImage(systemName: "trash.fill"), attributes: .destructive) { _ in
                    self.deleteList(forRowAt: indexPath)
                }
            ])
        }
    }

    override func tableView(_ tableView: UITableView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        guard let indexPath = configuration.identifier as? IndexPath else { return }
        animator.addAnimations {
            self.performSegue(withIdentifier: "selectList", sender: indexPath)
        }
    }
}

extension Organize: HeaderConfigurable {
    func configureHeader(_ header: UITableViewHeaderFooterView, at index: Int) {
        guard let header = header as? BookTableHeader else { preconditionFailure() }
        header.configure(labelText: "Your Lists", badgeNumber: nil, enableSort: !isEditing && !searchController.isActive)
    }
}

extension Organize: UISearchControllerDelegate {
    func didDismissSearchController(_ searchController: UISearchController) {
        reloadHeaders()
        // If we caused all data to be deleted while searching, the empty state view might now need to be a "no lists" view
        // rather than a "no results" view.
        emptyDataSetManager.reloadEmptyStateView()
    }

    func willPresentSearchController(_ searchController: UISearchController) {
        // The search controller is not yet active, so queue up a reload of the headers once this presentation is has started
        DispatchQueue.main.async {
            self.reloadHeaders()
        }
    }
}

extension Organize: UISearchResultsUpdating {
    func predicate(forSearchText searchText: String?) -> NSPredicate {
        if let searchText = searchText, !searchText.isEmptyOrWhitespace && searchText.trimming().count >= 2 {
            return NSPredicate(fieldName: #keyPath(List.name), containsSubstring: searchText)
        }
        return NSPredicate(boolean: true) // If we cannot filter with the search text, we should return all results
    }

    func updateSearchResults(for searchController: UISearchController) {
        let searchTextPredicate = self.predicate(forSearchText: searchController.searchBar.text)

        if dataSource.resultsController.fetchRequest.predicate != searchTextPredicate {
            dataSource.resultsController.fetchRequest.predicate = searchTextPredicate
            try! dataSource.resultsController.performFetch()
        }
        dataSource.updateData(animate: true)
    }
}
