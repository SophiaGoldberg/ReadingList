import Foundation
import Eureka
import ImageRow
import UIKit
import CoreData
import SVProgressHUD
import ReadingList_Foundation

final class EditBookMetadata: FormViewController {

    private var editBookContext: NSManagedObjectContext!
    private var book: Book!
    private var isAddingNewBook: Bool!
    var isInNavigationFlow = false
    let googleBooksApi = GoogleBooksApi()

    private var shouldPrepopulateLastLanguageSelection: Bool {
        // We want to prepopulate the last selected language only if we are adding a new manual book: we don't want to
        // automatically alter the metadata of a Google Search result, or set the language of a book being edited which
        // happens to not have a language set.
        return GeneralSettings.prepopulateLastLanguageSelection && isAddingNewBook && book.googleBooksId == nil
    }

    convenience init(bookToEditID: NSManagedObjectID) {
        self.init()
        self.isAddingNewBook = false
        self.editBookContext = PersistentStoreManager.container.viewContext.childContext()
        self.book = (editBookContext.object(with: bookToEditID) as! Book)
    }

    convenience init(bookToCreateReadState: BookReadState) {
        self.init()
        self.editBookContext = PersistentStoreManager.container.viewContext.childContext()
        self.book = Book(context: editBookContext)
        self.book.manualBookId = UUID().uuidString
        self.book.setDefaultReadDates(for: bookToCreateReadState)
        self.isAddingNewBook = true
    }

    convenience init(bookToCreate: Book, scratchpadContext: NSManagedObjectContext) {
        self.init()
        self.isAddingNewBook = true
        self.editBookContext = scratchpadContext
        self.book = bookToCreate
        // If we are editing the metadata of a book we have already created in a temporary context, we must be
        // within a navigation flow. Remember this, so we don't set the left bar button to be a Cancel button
        self.isInNavigationFlow = true
    }

    override func viewDidLoad() { //swiftlint:disable:this cyclomatic_complexity
        super.viewDidLoad()

        configureNavigationItem()

        // Watch the book object for changes and validate the form
        NotificationCenter.default.addObserver(self, selector: #selector(validateBook), name: .NSManagedObjectContextObjectsDidChange, object: editBookContext)

        // Prepopulate last selected language, if appropriate to do so. Do this before the configuration of the form so that the form is accurate
        if shouldPrepopulateLastLanguageSelection {
            book.language = LightweightDataStore.lastSelectedLanguage
        }

        // General approach regarding capturing references to `self`:
        // initialization functions are run once, not stored, so we don't need to capture self weakly.
        // Stored closures, such as onChange, cellUpdate, etc, should capture `self` weakly to avoid a reference cycle
        // causing a memory leak. We use `weak self` references rather than `unowned self` references, in case there are some
        // specific timing issues whereby the closure runs after the view controller is deallocated (though unlikely).

        form +++ Section(header: "Title", footer: "")
            <<< TextRow {
                $0.cell.textField.autocapitalizationType = .words
                $0.placeholder = "Title"
                $0.value = self.book.title
                $0.onChange { [weak self] cell in
                    guard let `self` = self else { return }
                    if let cellValue = cell.value {
                        self.book.title = cellValue
                    } else {
                        self.book.setValue(nil, forKey: #keyPath(Book.title))
                    }
                }
            }

            +++ AuthorSection(book: book, navigationController: navigationController!)

            +++ Section(header: "Additional Information", footer: "Note: if provided, ISBN-13 must be a valid, 13 digit ISBN.")
            <<< TextRow {
                $0.cell.textField.autocapitalizationType = .words
                $0.title = "Subtitle"
                $0.value = book.subtitle
                $0.onChange { [weak self] cell in
                    guard let `self` = self else { return }
                    self.book.subtitle = cell.value
                }
            }
            <<< Int32Row {
                $0.title = "Page Count"
                $0.value = book.pageCount
                $0.onChange { [weak self] cell in
                    guard let `self` = self else { return }
                    guard let pageCount = cell.value, pageCount >= 0 else {
                        self.book.pageCount = nil
                        return
                    }
                    self.book.pageCount = pageCount
                }
            }
            <<< PickerInlineRow<LanguageSelection> {
                $0.title = "Language"
                $0.value = {
                    if let language = self.book.language {
                        return .some(language)
                    } else {
                        return .blank
                    }
                }()
                $0.options = [.blank] + LanguageIso639_1.allCases.map { .some($0) }
                $0.onChange { [weak self] cell in
                    guard let `self` = self else { return }
                    if let selection = cell.value, case let .some(language) = selection {
                        self.book.language = language
                    } else {
                        self.book.language = nil
                    }
                }
            }
            <<< DateInlineRow {
                $0.title = "Publication Date"
                $0.value = book.publicationDate
                $0.onChange { [weak self] cell in
                    guard let `self` = self else { return }
                    self.book.publicationDate = cell.value
                }
            }
            <<< TextRow {
                $0.cell.textField.autocapitalizationType = .words
                $0.title = "Publisher"
                $0.value = book.publisher
                $0.onChange { [weak self] cell in
                    guard let `self` = self else { return }
                    self.book.publisher = cell.value
                }
            }
            <<< ButtonRow {
                $0.title = "Subjects"
                $0.cellStyle = .value1
                $0.cellUpdate { [weak self] cell, _ in
                    guard let `self` = self else { return }
                    cell.textLabel!.textAlignment = .left
                    cell.textLabel!.textColor = .label
                    cell.accessoryType = .disclosureIndicator
                    cell.detailTextLabel?.text = self.book.subjects.map { $0.name }.sorted().joined(separator: ", ")
                }
                $0.onCellSelection { [weak self] _, row in
                    guard let `self` = self else { return }
                    self.navigationController!.pushViewController(EditBookSubjectsForm(book: self.book, sender: row), animated: true)
                }
            }
            <<< ImageRow {
                $0.title = "Cover Image"
                $0.cell.height = { 100 }
                $0.sourceTypes = [.Camera, .PhotoLibrary]
                $0.value = UIImage(optionalData: self.book.coverImage)
                $0.onChange { [weak self] cell in
                    guard let `self` = self else { return }
                    self.book.coverImage = cell.value?.jpegData(compressionQuality: 0.7)
                }
            }
            <<< Int64Row {
                $0.title = "ISBN-13"
                $0.value = book.isbn13
                $0.formatter = nil
                $0.onChange { [weak self] cell in
                    guard let `self` = self else { return }
                    self.book.isbn13 = cell.value
                }
            }

            +++ Section(header: "Description", footer: "")
            <<< TextAreaRow {
                $0.placeholder = "Description"
                $0.value = book.bookDescription
                $0.onChange { [weak self] cell in
                    guard let `self` = self else { return }
                    self.book.bookDescription = cell.value
                }
                $0.cellSetup { [weak self] cell, _ in
                    guard let `self` = self else { return }
                    cell.height = { [weak self] in
                        // Just return some default value if self has been deallocated by the time this block is called
                        guard let `self` = self else { return 100 }
                        return (self.view.frame.height / 3) - 10
                    }
                }
            }

            // Update and delete buttons
            +++ Section()
            <<< ButtonRow {
                $0.title = "Update from Google Books"
                $0.hidden = Condition(booleanLiteral: isAddingNewBook || book.isbn13 == nil)
                $0.onCellSelection { [weak self] cell, row in
                    guard let `self` = self else { return }
                    self.updateFromGooglePressed(cell: cell, row: row)
                }
            }
            <<< ButtonRow {
                $0.title = "Delete"
                $0.cellSetup { cell, _ in
                    cell.tintColor = .systemRed
                }
                $0.onCellSelection { [weak self] cell, _ in
                    guard let `self` = self else { return }
                    self.deletePressed(sender: cell)
                }
                $0.hidden = Condition(booleanLiteral: isAddingNewBook)
            }

        #if DEBUG
        form +++ Section("Debug")
            <<< Int32Row {
                $0.title = "Sort"
                $0.value = book.sort
                $0.onChange { [weak self] cell in
                    guard let `self` = self else { return }
                    self.book.sort = cell.value ?? 0
                }
            }
            <<< LabelRow {
                $0.title = "Core Data ID"
                $0.value = book.objectID.uriRepresentation().absoluteString
            }
            <<< LabelRow {
                $0.title = "Manual Book ID"
                $0.value = book.manualBookId
            }
            <<< TextRow {
                $0.title = "Google Books ID"
                $0.value = book.googleBooksId
                $0.onChange { [weak self] cell in
                    guard let `self` = self else { return }
                    self.book.googleBooksId = cell.value
                }
            }
        #endif

        // Validate on start
        validateBook()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Prevent the default behaviour of allowing a swipe-down to dismiss the modal presentation. This would
        // not give a confirmation alert before discarding a user's unsaved changes. By handling the dismiss event
        // ourselves we can present a confirmation dialog.
        isModalInPresentation = true
        navigationController?.presentationController?.delegate = self
    }

    func configureNavigationItem() {
        if !isInNavigationFlow {
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(userDidCancel))
        }
        if isAddingNewBook {
            navigationItem.title = "Add Book"
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Next", style: .plain, target: self, action: #selector(presentEditReadingState))
        } else {
            navigationItem.title = "Edit Book"
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(donePressed))
        }
    }

    func deletePressed(sender deleteCell: UITableViewCell) {
        guard !isAddingNewBook else { return }

        let confirmDeleteAlert = UIAlertController(title: "Confirm deletion", message: nil, preferredStyle: .actionSheet)
        confirmDeleteAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        confirmDeleteAlert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            // Delete the book, log the event, and dismiss this modal view
            self.editBookContext.performAndSave {
                self.book.delete()
            }
            UserEngagement.logEvent(.deleteBook)
            self.dismiss(animated: true)
        })
        confirmDeleteAlert.popoverPresentationController?.setSourceCell(deleteCell, inTableView: tableView)

        self.present(confirmDeleteAlert, animated: true, completion: nil)
    }

    private func confirmUpdateAlert(updateHandler: ((UIAlertAction) -> Void)?) -> UIAlertController {
        let areYouSure = UIAlertController(title: "Confirm Update", message: "Updating from Google Books will overwrite any book metadata changes you have made manually. Are you sure you wish to proceed?", preferredStyle: .alert)
        areYouSure.addAction(UIAlertAction(title: "Update", style: .default, handler: updateHandler))
        areYouSure.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        return areYouSure
    }

    func updateFromGooglePressed(cell: ButtonCellOf<String>, row: _ButtonRowOf<String>) {
        if self.book.googleBooksId != nil {
            present(confirmUpdateAlert(updateHandler: updateBookFromGoogleHandler(_:)), animated: true)
        } else if let isbn = book.isbn13 {
            SVProgressHUD.show(withStatus: "Searching...")
            UserEngagement.logEvent(.searchForExistingBookByIsbn)

            googleBooksApi.fetch(isbn: isbn.string)
                .always(on: .main) {
                    SVProgressHUD.dismiss()
                }
                .catch(on: .main) {
                    switch $0 {
                    case GoogleBooksApi.ResponseError.noResult:
                        SVProgressHUD.showInfo(withStatus: "No results found online")
                    default:
                        SVProgressHUD.showError(withStatus: "An error occurred searching online")
                    }
                }
                .then(on: .main) { [weak self] fetchResult in
                    guard let `self` = self else { return }
                    self.present(self.confirmUpdateAlert { _ in
                        self.updateBookFromGoogle(fetchResult: fetchResult)
                    }, animated: true)
                }
        }
    }

    func updateBookFromGoogleHandler(_: UIAlertAction) {
        guard let googleBooksId = book.googleBooksId else { return }
        SVProgressHUD.show(withStatus: "Downloading...")
        UserEngagement.logEvent(.updateBookFromGoogle)

        googleBooksApi.fetch(googleBooksId: googleBooksId)
            .always(on: .main) {
                SVProgressHUD.dismiss()
            }
            .catch(on: .main) { _ in
                SVProgressHUD.showError(withStatus: "Could not update book details")
            }
            .then(on: .main, updateBookFromGoogle)
    }

    func updateBookFromGoogle(fetchResult: GoogleBooksApi.FetchResult) {
        book.populate(fromFetchResult: fetchResult)
        if book.isValidForUpdate() {
            editBookContext.saveIfChanged()
            dismiss(animated: true) {
                // FUTURE: Would be nice to display whether any changes were made
                SVProgressHUD.showInfo(withStatus: "Book updated")
            }
        } else {
            SVProgressHUD.showError(withStatus: "Could not update book details")
        }
    }

    @objc func validateBook() {
        navigationItem.rightBarButtonItem!.isEnabled = book.isValidForUpdate()
    }

    @objc func userDidCancel() {
        let noConfirmationNeeded: Bool
        if self.isAddingNewBook {
            let trivialChanges = [
                #keyPath(Book.addedWhen),
                #keyPath(Book.manualBookId)
            ]
            noConfirmationNeeded = book.changedValues()
                .filter { !trivialChanges.contains($0.key) }
                .isEmpty
        } else {
            noConfirmationNeeded = book.changedValues().isEmpty
        }

        guard noConfirmationNeeded else {
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

        if book.changedValues().keys.contains(Book.Key.languageCode.rawValue) {
            LightweightDataStore.lastSelectedLanguage = book.language
        }
        editBookContext.saveIfChanged()
        dismiss(animated: true) {
            UserEngagement.onReviewTrigger()
        }
    }

    @objc func presentEditReadingState() {
        guard book.isValidForUpdate() else { return }
        UserEngagement.logEvent(.addManualBook)
        navigationController!.pushViewController(EditBookReadState(newUnsavedBook: book, scratchpadContext: editBookContext), animated: true)
    }
}

extension EditBookMetadata: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        // If the user swipes down, we either dismiss or present a confirmation dialog
        userDidCancel()
    }
}

final class AuthorSection: MultivaluedSection {

    // This form is only presented by a metadata form, so does not need to maintain
    // a strong reference to the book's object context
    var book: Book!

    var isInitialising = true
    weak var navigationController: UINavigationController!

    required init(book: Book, navigationController: UINavigationController) {
        super.init(multivaluedOptions: [.Insert, .Delete, .Reorder], header: "Authors", footer: "Note: at least one author is required") {
            for author in book.authors {
                $0 <<< AuthorRow(author: author)
            }
            $0.addButtonProvider = { _ in
                ButtonRow {
                    $0.title = "Add Author"
                    $0.cellUpdate { cell, _ in
                        cell.textLabel!.textAlignment = .left
                    }
                }
            }
        }
        self.navigationController = navigationController
        self.multivaluedRowToInsertAt = { [unowned self] _ in
            let authorRow = AuthorRow()
            self.navigationController.pushViewController(AddAuthorForm(authorRow), animated: true)
            return authorRow
        }
        self.book = book
        isInitialising = false
    }

    required init() {
        super.init(multivaluedOptions: [], header: "", footer: "") { _ in }
    }

    required init(multivaluedOptions: MultivaluedOptions, header: String?, footer: String?, _ initializer: (GenericMultivaluedSection<ButtonRow>) -> Void) {
        super.init(multivaluedOptions: multivaluedOptions, header: header, footer: footer, initializer)
    }

    required init<S>(_ elements: S) where S: Sequence, S.Element == BaseRow {
        super.init(elements)
    }

    func rebuildAuthors() {
        // It's a bit tricky with Eureka to manage an ordered set: the reordering comes through rowsHaveBeenRemoved
        // and rowsHaveBeenAdded, so we can't delete books on removal, since they might need to come back.
        // Instead, we take the brute force approach of deleting all authors and rebuilding the set each time
        // something changes. We can check whether there are any meaningful differences before we embark on this though.
        let newAuthors: [(String, String?)] = self.compactMap {
            guard let authorRow = $0 as? AuthorRow else { return nil }
            guard let lastName = authorRow.lastName else { return nil }
            return (lastName, authorRow.firstNames)
        }
        if book.authors.map({ ($0.lastName, $0.firstNames) }).elementsEqual(newAuthors, by: { $0.0 == $1.0 && $0.1 == $1.1 }) {
            return
        }
        book.authors = newAuthors.map { Author(lastName: $0.0, firstNames: $0.1) }
    }

    override func rowsHaveBeenRemoved(_ rows: [BaseRow], at: IndexSet) {
        super.rowsHaveBeenRemoved(rows, at: at)
        guard !isInitialising else { return }
        rebuildAuthors()
    }

    override func rowsHaveBeenAdded(_ rows: [BaseRow], at: IndexSet) {
        super.rowsHaveBeenAdded(rows, at: at)
        guard !isInitialising else { return }
        rebuildAuthors()
    }
}

final class AuthorRow: _LabelRow, RowType {
    var lastName: String?
    var firstNames: String?

    convenience init(tag: String? = nil, author: Author? = nil) {
        self.init(tag: tag)
        lastName = author?.lastName
        firstNames = author?.firstNames
        reload()
    }

    required init(tag: String?) {
        super.init(tag: tag)
        cellStyle = .value1

        cellUpdate { [unowned self] cell, _ in
            cell.textLabel!.textAlignment = .left
            cell.textLabel!.text = [self.firstNames, self.lastName].compactMap { $0 }.joined(separator: " ")
        }
    }
}
