import Foundation
import UIKit
import CoreData
import ReadingList_Foundation

final class AddToExistingLists: UITableViewController {
    var resultsController: NSFetchedResultsController<List>!
    var onComplete: (() -> Void)?
    var books: Set<Book>!
    @IBOutlet private weak var doneButton: UIBarButtonItem!

    override func viewDidLoad() {
        super.viewDidLoad()
        guard !books.isEmpty else { preconditionFailure() }

        let fetchRequest = NSManagedObject.fetchRequest(List.self, batch: 40)
        fetchRequest.predicate = NSPredicate.or(books.map {
            NSPredicate(format: "SELF IN %@", $0.lists).not()
        })
        switch ListSortOrder.selectedSort {
        case .custom:
            fetchRequest.sortDescriptors = [NSSortDescriptor(\List.sort), NSSortDescriptor(\List.name)]
        case .alphabetical:
            fetchRequest.sortDescriptors = [NSSortDescriptor(\List.name)]
        }
        resultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: PersistentStoreManager.container.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        resultsController.delegate = tableView
        try! resultsController.performFetch()

        setEditing(true, animated: false)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return resultsController.sections![0].numberOfObjects
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ExistingListCell", for: indexPath)
        let list = resultsController.object(at: IndexPath(row: indexPath.row, section: 0))
        cell.textLabel!.text = list.name
        cell.detailTextLabel!.text = "\(list.items.count) book\(list.items.count == 1 ? "" : "s")"

        if books.count > 1 {
            let overlapCount = getBookListOverlap(list)
            if overlapCount > 0 {
                cell.detailTextLabel!.text?.append(" (\(overlapCount) already added)")
            }
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        updateNavigationItem()
    }

    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        updateNavigationItem()
    }

    private func updateNavigationItem() {
        if let selectedRows = tableView.indexPathsForSelectedRows, !selectedRows.isEmpty {
            navigationItem.title = selectedRows.count == 1 ? "Add To List" : "Add To \(selectedRows.count) Lists"
            navigationItem.rightBarButtonItem?.isEnabled = true
        } else {
            navigationItem.title = "Add To List"
            navigationItem.rightBarButtonItem?.isEnabled = false
        }
    }

    @IBAction private func doneButtonTapped(_ sender: UIBarButtonItem) {
        guard let selectedRows = tableView.indexPathsForSelectedRows else { return }
        let lists = selectedRows.map { self.resultsController.object(at: $0) }
        let childContext = PersistentStoreManager.container.viewContext.childContext()
        childContext.performAndSave {
            let booksInChildContext = self.books.map { $0.inContext(childContext) }
            for list in lists {
                list.inContext(childContext).addBooks(booksInChildContext)
            }
        }
        self.navigationController?.dismiss(animated: true, completion: self.onComplete)
        UserEngagement.logEvent(.bulkAddBookToList)
    }

    private func getBookListOverlap(_ list: List) -> Int {
        return books.intersection(list.books).count
    }
}
