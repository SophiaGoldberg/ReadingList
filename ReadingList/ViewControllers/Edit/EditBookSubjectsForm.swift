import Foundation
import UIKit
import Eureka

final class EditBookSubjectsForm: FormViewController {

    convenience init(book: Book, sender: _ButtonRowOf<String>) {
        self.init()
        self.book = book
        self.sendingRow = sender
    }

    weak var sendingRow: _ButtonRowOf<String>!

    // This form is only presented by a metadata form, so does not need to maintain
    // a strong reference to the book's object context
    var book: Book!

    override func viewDidLoad() {
        super.viewDidLoad()

        form +++ MultivaluedSection(multivaluedOptions: [.Insert, .Delete], header: "Subjects", footer: "Add subjects to categorise this book") {
            $0.addButtonProvider = { _ in
                ButtonRow {
                    $0.title = "Add New Subject"
                    $0.cellUpdate { cell, _ in
                        cell.textLabel?.textAlignment = .left
                    }
                }
            }
            $0.multivaluedRowToInsertAt = { _ in
                TextRow {
                    $0.placeholder = "Subject"
                    $0.cell.textField.autocapitalizationType = .words
                }
            }
            for subject in book.subjects.sorted(by: { $0.name < $1.name }) {
                $0 <<< TextRow {
                    $0.value = subject.name
                    $0.cell.textField.autocapitalizationType = .words
                }
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        let subjectNames = form.rows.compactMap { ($0 as? TextRow)?.value?.trimming().nilIfWhitespace() }
        if book.subjects.map({ $0.name }) != subjectNames {
            book.subjects = Set(subjectNames.map { Subject.getOrCreate(inContext: book.managedObjectContext!, withName: $0) })
        }
        sendingRow.reload()
    }
}
