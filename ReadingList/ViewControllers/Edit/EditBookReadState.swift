import Foundation
import Eureka
import UIKit
import CoreData

final class EditBookReadState: FormViewController {

    private var editContext: NSManagedObjectContext!
    private var book: Book!
    private var newBook = false

    private let readStateKey = "readState"
    private let startedReadingKey = "startedReading"
    private let finishedReadingKey = "finishedReading"
    private let progressTypeKey = "progressType"
    private let progressPageKey = "progressPage"
    private let progressPercentageKey = "progressPercentage"

    convenience init(existingBookID: NSManagedObjectID) {
        self.init()
        editContext = PersistentStoreManager.container.viewContext.childContext()
        book = (editContext.object(with: existingBookID) as! Book)
    }

    convenience init(newUnsavedBook: Book, scratchpadContext: NSManagedObjectContext) {
        self.init()
        newBook = true
        book = newUnsavedBook
        editContext = scratchpadContext
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureNavigationItem()

        // Watch the book object for changes and validate the form
        NotificationCenter.default.addObserver(self, selector: #selector(validateBook), name: .NSManagedObjectContextObjectsDidChange, object: editContext)

        let now = Date()

        form +++ Section(header: "Reading Log", footer: "")
            <<< SegmentedRow<BookReadState>(readStateKey) {
                $0.options = [.toRead, .reading, .finished]
                $0.value = book.readState
                $0.onChange { [unowned self] _ in
                    self.updateBookFromForm()
                }
            }
            <<< DateInlineRow(startedReadingKey) {
                $0.title = "Started"
                $0.value = book.startedReading ?? now
                $0.onChange { [unowned self] _ in
                    self.updateBookFromForm()
                }
                $0.hidden = Condition.function([readStateKey]) { [unowned self] form in
                    (form.rowBy(tag: self.readStateKey) as! SegmentedRow<BookReadState>).value == .toRead
                }
            }
            <<< DateInlineRow(finishedReadingKey) {
                $0.title = "Finished"
                $0.value = book.finishedReading ?? now
                $0.onChange { [unowned self] _ in
                    self.updateBookFromForm()
                }
                $0.hidden = Condition.function([readStateKey]) { [unowned self] form in
                    (form.rowBy(tag: self.readStateKey) as! SegmentedRow<BookReadState>).value != .finished
                }
            }
            +++ Section(header: "Progress", footer: "") {
                $0.hidden = Condition.function([readStateKey]) { [unowned self] form in
                    (form.rowBy(tag: self.readStateKey) as! SegmentedRow<BookReadState>).value != .reading
                }
            }
            <<< SegmentedRow<ProgressType>(progressTypeKey) {
                $0.title = "Type  "
                $0.options = [.page, .percentage]
                $0.value = book.currentPage == nil && book.currentPercentage == nil ? GeneralSettings.defaultProgressType : book.progressAuthority
                $0.onChange { [unowned self] row in
                    guard let type = row.value else { return }
                    self.updateProgressFromForm(type)
                }
            }
            <<< Int32Row(progressPageKey) {
                $0.title = "Current Page Number"
                $0.value = self.book.currentPage
                $0.hidden = Condition.function([progressTypeKey]) { [unowned self] form in
                    (form.rowBy(tag: self.progressTypeKey) as! SegmentedRow<ProgressType>).value != .page
                }
                $0.onChange { [unowned self] row in
                    self.book.setProgress(.page(row.value))
                }
            }
            <<< Int32Row(progressPercentageKey) {
                $0.title = "Current Percentage"
                $0.value = self.book.currentPercentage
                $0.hidden = Condition.function([progressTypeKey]) { [unowned self] form in
                    (form.rowBy(tag: self.progressTypeKey) as! SegmentedRow<ProgressType>).value != .percentage
                }
                $0.onChange { [unowned self] row in
                    self.book.setProgress(.percentage(row.value))
                }
                $0.displayValueFor = {
                    guard let value = $0 else { return nil }
                    return "\(value)%"
                }
            }

        monitorThemeSetting()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Prevent the default behaviour of allowing a swipe-down to dismiss the modal presentation. This would
        // not give a confirmation alert before discarding a user's unsaved changes. By handling the dismiss event
        // ourselves we can present a confirmation dialog.
        if #available(iOS 13.0, *) {
            isModalInPresentation = true
            navigationController?.presentationController?.delegate = self
        }

        // If we are editing a book (not adding one), pre-select the current page field
        if self.book.readState == .reading && self.book.changedValues().isEmpty {
            guard
                let progressRow = [progressPageKey, progressPercentageKey].map({
                    self.form.rowBy(tag: $0) as! Int32Row
                }).first(where: { !$0.isHidden }),
                let textField = progressRow.cell.textField
            else {
                assertionFailure("Neither percentage nor page visible")
                return
            }

            textField.becomeFirstResponder()
            textField.selectedTextRange = textField.textRange(
                from: textField.beginningOfDocument,
                to: textField.endOfDocument
            )
        }
    }

    private func updateBookFromForm() {
        guard let readState = (form.rowBy(tag: readStateKey) as! SegmentedRow<BookReadState>).value else {
            assertionFailure("No read state value")
            return
        }
        switch readState {
        case .toRead:
            book.setToRead()
        case .reading:
            book.setReading(started: (form.rowBy(tag: startedReadingKey) as! DateInlineRow).value ?? Date())
            guard let progressType = (form.rowBy(tag: progressTypeKey) as! SegmentedRow<ProgressType>).value else { return }
            updateProgressFromForm(progressType)
        case .finished:
            book.setFinished(started: (form.rowBy(tag: startedReadingKey) as! DateInlineRow).value ?? Date(),
                             finished: (form.rowBy(tag: finishedReadingKey) as! DateInlineRow).value ?? Date())
        }
    }

    private func updateProgressFromForm(_ progressType: ProgressType) {
        switch progressType {
        case .page:
            let page = (self.form.rowBy(tag: self.progressPageKey) as! Int32Row).value
            self.book.setProgress(.page(page))
        case .percentage:
            let percent = (self.form.rowBy(tag: self.progressPercentageKey) as! Int32Row).value
            self.book.setProgress(.percentage(percent))
        }
    }

    func configureNavigationItem() {
        if navigationItem.leftBarButtonItem == nil && navigationController!.viewControllers.first == self {
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(userDidCancel))
        }
        navigationItem.title = book.title
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(donePressed))
    }

    @objc func validateBook() {
        navigationItem.rightBarButtonItem!.isEnabled = book.isValidForUpdate()
    }

    @objc func userDidCancel() {
        // FUTURE: Duplicates code in EditBookMetadata. Consolidate.
        updateBookFromForm()
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

        if newBook || book.changedValues().keys.contains(#keyPath(Book.readState)) {
            book.updateSortIndex()
        }
        // If we have been adding a new manual book with a language, remember this language.
        // Note: this has a limitation that it does not detect manually selected languages from a book added from an
        // online search (after tapping the detail button), since we are unable to determine whether the language
        // currently set in the book is equal to what was present in the search result. This is acceptable for now.
        if let language = book.language, book.manualBookId != nil && newBook {
            LightweightDataStore.lastSelectedLanguage = language
        }
        editContext.saveIfChanged()

        // FUTURE: Figure out a better way to solve this problem.
        // If the previous view controller was the SearchOnline VC, then we need to deactivate its search controller
        // so that it doesn't end up being leaked. We can't do that on viewWillDissappear, since that would clear the
        // search bar, which is annoying if the user navigates back to that view.
        if let searchOnline = navigationController!.viewControllers.first as? SearchOnline {
            searchOnline.searchController.isActive = false
        }

        presentingViewController?.dismiss(animated: true) {
            if self.newBook {
                guard let tabBarController = AppDelegate.shared.tabBarController else {
                    assertionFailure()
                    return
                }
                tabBarController.simulateBookSelection(self.book, allowTableObscuring: false)
            }
            UserEngagement.onReviewTrigger()
        }
    }
}

extension EditBookReadState: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        // If the user swipes down, we either dismiss or present a confirmation dialog
        userDidCancel()
    }
}
