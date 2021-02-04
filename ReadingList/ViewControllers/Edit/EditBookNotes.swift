import Foundation
import UIKit
import Eureka
import CoreData

class EditBookNotes: FormViewController {

    private var book: Book!
    private var editContext = PersistentStoreManager.container.viewContext.childContext()

    convenience init(existingBookID: NSManagedObjectID) {
        self.init()
        self.book = (editContext.object(with: existingBookID) as! Book)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureNavigationItem()

        form +++ Section(header: "Notes", footer: "")
            <<< StarRatingRow {
                $0.value = Double(self.book.rating ?? 0) / 2
                $0.onChange { [weak self] cell in
                    guard let `self` = self else { return }
                    if let rating = cell.value {
                        self.book.rating = Int16(floor(rating * 2))
                    } else {
                        self.book.rating = nil
                    }
                }
            }
            <<< TextAreaRow {
                $0.placeholder = "Add your personal notes here..."
                $0.value = book.notes
                $0.cellSetup { [weak self] cell, _ in
                    guard let `self` = self else { return }
                    cell.height = { [weak self] in
                        // Just return some default value if self has been deallocated by the time this block is called
                        guard let `self` = self else { return 100 }
                        return (self.view.frame.height / 3) - 10
                    }
                }
                $0.onChange { [weak self] cell in
                    guard let `self` = self else { return }
                    self.book.notes = cell.value
                }
            }

        // Prevent the default behaviour of allowing a swipe-down to dismiss the modal presentation. This would
        // not give a confirmation alert before discarding a user's unsaved changes. By handling the dismiss event
        // ourselves we can present a confirmation dialog.
        isModalInPresentation = true
        navigationController?.presentationController?.delegate = self
    }

    func configureNavigationItem() {
        navigationItem.title = "Edit Notes"
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(userDidCancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(donePressed))
    }

    @objc func userDidCancel() {
        // FUTURE: Duplicates code in EditBookMetadata. Consolidate.
        guard book.changedValues().isEmpty else {
            // Confirm exit dialog
            let confirmExit = UIAlertController(title: "Unsaved changes", message: "Are you sure you want to discard your unsaved changes?", preferredStyle: .actionSheet)
            confirmExit.addAction(UIAlertAction(title: "Discard", style: .destructive) { _ in
                self.dismiss(animated: true)
            })
            confirmExit.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            if let popover = confirmExit.popoverPresentationController {
                guard let barButtonItem = navigationItem.leftBarButtonItem ?? navigationItem.rightBarButtonItem else {
                    preconditionFailure("Missing navigation bar button item")
                }
                popover.barButtonItem = barButtonItem
            }
            present(confirmExit, animated: true, completion: nil)
            return
        }

        dismiss(animated: true, completion: nil)
    }

    @objc func donePressed() {
        guard book.isValidForUpdate() else { return }

        view.endEditing(true)
        editContext.saveIfChanged()

        presentingViewController?.dismiss(animated: true) {
            UserEngagement.onReviewTrigger()
        }
    }
}

extension EditBookNotes: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        // If the user swipes down, we either dismiss or present a confirmation dialog
        userDidCancel()
    }
}
