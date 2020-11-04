import Foundation
import UIKit
import CoreData

final class RemoveFromExistingLists: UITableViewController {
    var book: Book!
    private var resultsController: NSFetchedResultsController<List>!

    override func viewDidLoad() {
        super.viewDidLoad()

        let fetchRequest = NSManagedObject.fetchRequest(List.self, batch: 40)
        fetchRequest.predicate = NSPredicate(format: "%@ IN \(#keyPath(List.items)).\(#keyPath(ListItem.book))", book)
        fetchRequest.sortDescriptors = [NSSortDescriptor(\List.sort), NSSortDescriptor(\List.name)]
        resultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: PersistentStoreManager.container.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        resultsController.delegate = self
        try! resultsController.performFetch()

        setEditing(true, animated: false)
        monitorThemeSetting()
    }

    @IBAction private func doneTapped(_ sender: Any) {
        navigationController?.dismiss(animated: true)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return resultsController.sections!.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return resultsController.sections![section].numberOfObjects
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ExistingListCell", for: indexPath)
        if #available(iOS 13.0, *) { } else {
            cell.defaultInitialise(withTheme: GeneralSettings.theme)
        }

        let list = resultsController.object(at: indexPath)
        cell.textLabel!.text = list.name
        cell.detailTextLabel!.text = "\(list.items.count) book\(list.items.count == 1 ? "" : "s")"
        return cell
    }

    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        return [UITableViewRowAction(style: .destructive, title: "Remove", color: .red) { _, indexPath in
            let list = self.resultsController.object(at: indexPath)
            list.removeBook(self.book)
            list.managedObjectContext!.saveAndLogIfErrored()
            UserEngagement.logEvent(.removeBookFromList)
        }]
    }
}

extension RemoveFromExistingLists: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.controllerDidChangeContent(controller)
        if controller.sections![0].numberOfObjects == 0 {
            navigationController?.popViewController(animated: true)
        }
    }

    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.controllerWillChangeContent(controller)
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        tableView.controller(controller, didChange: anObject, at: indexPath, for: type, newIndexPath: newIndexPath)
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        tableView.controller(controller, didChange: sectionInfo, atSectionIndex: sectionIndex, for: type)
    }
}
