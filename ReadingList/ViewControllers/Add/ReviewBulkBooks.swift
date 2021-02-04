import Foundation
import CoreData
import UIKit

final class ReviewBulkBooks: UITableViewController {

    var books = [Book]()
    var context: NSManagedObjectContext!

    override func viewDidLoad() {
        super.viewDidLoad()
        assert(!books.isEmpty, "ReviewBulkBooks loaded without any assigned books")
        tableView.register(BookTableViewCell.self)

        navigationItem.title = "Review \(books.count) \("Book".pluralising(books.count))"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Save", style: .done, target: self, action: #selector(save))
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        assert(section == 0)
        return books.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeue(BookTableViewCell.self, for: indexPath)
        cell.configureFrom(books[indexPath.row])
        cell.selectionStyle = .none
        return cell
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        return UISwipeActionsConfiguration(actions: [
            UIContextualAction(style: .destructive, title: "Delete") { _, _, _ in
                self.books.remove(at: indexPath.row).delete()
                self.tableView.deleteRows(at: [indexPath], with: .automatic)
                if self.books.isEmpty {
                    self.navigationController?.popViewController(animated: true)
                }
            }
        ])
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 92
    }

    @objc func save() {
        context.saveAndLogIfErrored()
        dismiss(animated: true)
    }
}
