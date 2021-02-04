import Foundation
import UIKit
import Eureka

final class AddAuthorForm: FormViewController {

    weak var presentingRow: AuthorRow!

    convenience init(_ row: AuthorRow) {
        self.init()
        self.presentingRow = row
    }

    let lastNameRow = "lastName"
    let firstNamesRow = "firstNames"

    override func viewDidLoad() {
        super.viewDidLoad()

        form +++ Section(header: "Author Name", footer: "")
            <<< TextRow(firstNamesRow) {
                $0.placeholder = "First Name(s)"
                $0.cell.textField.autocapitalizationType = .words
            }
            <<< TextRow(lastNameRow) {
                $0.placeholder = "Last Name"
                $0.cell.textField.autocapitalizationType = .words
            }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        // The removal of the presenting row should be at the point of disappear, since viewWillDisappear
        // is called when a right-swipe is started - the user could reverse and bring this view back
        let lastName = (form.rowBy(tag: lastNameRow) as! _TextRow).value
        if lastName?.isEmptyOrWhitespace != false {
            guard let index = presentingRow.indexPath?.row else { return }
            presentingRow.section!.remove(at: index)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if let lastName = (form.rowBy(tag: lastNameRow) as! _TextRow).value, !lastName.isEmptyOrWhitespace {
            presentingRow.lastName = lastName
            presentingRow.firstNames = (form.rowBy(tag: firstNamesRow) as! _TextRow).value
            presentingRow.reload()
            (presentingRow.section as! AuthorSection).rebuildAuthors()
        }
    }
}
