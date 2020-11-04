import Foundation
import UIKit
import CoreData
import Cosmos
import ReadingList_Foundation

final class BookDetails: UIViewController, UIScrollViewDelegate { //swiftlint:disable:this type_body_length
    @IBOutlet private weak var cover: UIImageView!
    @IBOutlet private weak var changeReadStateButton: StartFinishButton!

    @IBOutlet private var titles: [UILabel]!

    @IBOutlet private var titleAuthorHeadings: [UILabel]!
    @IBOutlet private weak var bookDescription: ExpandableLabel!

    @IBOutlet private var tableValues: [UILabel]!
    @IBOutlet private var tableSubHeadings: [UILabel]!

    @IBOutlet private weak var googleBooks: UILabel!
    @IBOutlet private weak var amazon: UILabel!

    @IBOutlet private var separatorLines: [UIView]!
    @IBOutlet private weak var listsStack: UIStackView!
    @IBOutlet private weak var listDetailsView: UIView!
    @IBOutlet private weak var noLists: UILabel!
    @IBOutlet private weak var noNotes: UILabel!
    @IBOutlet private weak var bookNotes: ExpandableLabel!
    @IBOutlet private weak var ratingView: CosmosView!

    var didShowNavigationItemTitle = false

    /// Instantiates the BookDetails view controller from its storyboard
    static func instantiate(withBook book: Book) -> BookDetails {
        guard let viewController = UIStoryboard.BookDetails.instantiateViewController(withIdentifier: "BookDetails") as? BookDetails else { preconditionFailure() }
        viewController.book = book
        return viewController
    }

    func setViewEnabled(_ enabled: Bool) {
        // Show or hide the whole view and nav bar buttons. Exit early if nothing to do.
        if view.isHidden != !enabled {
            view.isHidden = !enabled
        }
        navigationItem.rightBarButtonItems?.forEach { $0.setHidden(!enabled) }
    }

    var book: Book? {
        didSet { setupViewFromBook() }
    }

    func setupViewFromBook() { //swiftlint:disable:this cyclomatic_complexity
        // Hide the whole view and nav bar buttons if there's no book
        guard let book = book else { setViewEnabled(false); return }
        setViewEnabled(true)

        cover.image = UIImage(optionalData: book.coverImage) ?? #imageLiteral(resourceName: "CoverPlaceholder")
        titleAuthorHeadings[0].text = book.titleAndSubtitle
        titleAuthorHeadings[1].text = book.authors.fullNames
        (navigationItem.titleView as! UINavigationBarLabel).setTitle(book.title)

        switch book.readState {
        case .toRead:
            changeReadStateButton.setState(.start)
        case .reading:
            // It is not "invalid" to have a book with a started date in the future; but it is invalid
            // to have a finish date before the start date. Therefore, hide the finish button if
            // this would be the case.
            changeReadStateButton.setState(book.startedReading! < Date() ? .finish : .none)
        case .finished:
            changeReadStateButton.setState(.none)
        }

        bookDescription.text = book.bookDescription
        bookDescription.isHidden = book.bookDescription == nil
        bookDescription.nextSibling!.isHidden = book.bookDescription == nil

        func setTextOrHideLine(_ label: UILabel, _ string: String?) {
            // The detail labels are within a view, within a horizonal-stack
            // If a property is nil, we should hide the enclosing horizontal stack
            label.text = string
            label.superview!.superview!.isHidden = string == nil
        }

        // Read state is always present
        tableValues[0].text = book.readState.longDescription
        setTextOrHideLine(tableValues[1], book.startedReading?.toPrettyString(short: false))
        setTextOrHideLine(tableValues[2], book.finishedReading?.toPrettyString(short: false))

        let readTimeText: String?
        if book.readState == .toRead {
            readTimeText = nil
        } else {
            let dayCount = NSCalendar.current.dateComponents([.day], from: book.startedReading!.startOfDay(), to: (book.finishedReading ?? Date()).startOfDay()).day ?? 0
            if dayCount <= 0 && book.readState == .finished {
                readTimeText = "Within a day"
            } else if dayCount == 1 {
                readTimeText =  "1 day"
            } else {
                readTimeText = "\(dayCount) days"
            }
        }
        setTextOrHideLine(tableValues[3], readTimeText)

        let pageNumberText: String?
        switch book.progressAuthority {
        case .page:
            if let page = book.currentPage {
                if let percentage = book.currentPercentage {
                    pageNumberText = "Page \(page) (\(percentage)%)"
                } else {
                    pageNumberText = "Page \(page)"
                }
            } else {
                pageNumberText = nil
            }
        case .percentage:
            if let percent = book.currentPercentage {
                if let page = book.currentPage {
                    pageNumberText = "\(percent)% (page \(page))"
                } else {
                    pageNumberText = "\(percent)%"
                }
            } else {
                pageNumberText = nil
            }
        }
        setTextOrHideLine(tableValues[4], pageNumberText)

        ratingView.superview!.superview!.superview!.isHidden = book.rating == nil
        if let rating = book.rating {
            ratingView.rating = Double(rating) / 2
        } else {
            ratingView.rating = 0
        }

        bookNotes.isHidden = book.notes == nil
        bookNotes.text = book.notes
        noNotes.isHidden = book.notes != nil || book.rating != nil

        setTextOrHideLine(tableValues[5], book.isbn13?.string)
        setTextOrHideLine(tableValues[6], book.pageCount?.string)
        setTextOrHideLine(tableValues[7], book.publicationDate?.toPrettyString(short: false))
        setTextOrHideLine(tableValues[8], book.subjects.map { $0.name }.sorted().joined(separator: ", ").nilIfWhitespace())
        setTextOrHideLine(tableValues[9], book.language?.description)
        setTextOrHideLine(tableValues[10], book.publisher)

        // Show or hide the links, depending on whether we have valid URLs. If both links are hidden, the enclosing stack should be too.
        googleBooks.isHidden = book.googleBooksId == nil
        amazon.isHidden = book.amazonAffiliateLink == nil
        amazon.superview!.superview!.isHidden = googleBooks.isHidden && amazon.isHidden

        // Remove all the existing list labels, then add a label per list. Copy the list properties from another similar label, that's easier
        listsStack.removeAllSubviews()
        for list in book.lists {
            listsStack.addArrangedSubview(UILabel(font: tableValues[0].font, color: tableValues[0].textColor, text: list.name))
        }

        // There is a placeholder view for the case of no lists. Lists are stored in 3 nested stack views
        noLists.isHidden = !book.lists.isEmpty
        listsStack.superview!.superview!.superview!.isHidden = book.lists.isEmpty
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialise the view so that by default a blank page is shown.
        // This is required for starting the app in split-screen mode, where this view is
        // shown without any books being selected.
        setViewEnabled(false)

        // Listen for taps on the Google and Amazon labels, which should act like buttons and open the relevant webpage
        amazon.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(amazonButtonPressed)))
        googleBooks.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(googleBooksButtonPressed)))

        // A custom title view is required for animation
        let titleLabel = UINavigationBarLabel()
        titleLabel.isHidden = true
        navigationItem.titleView = titleLabel

        // On large devices, scale up the title and author labels
        if splitViewController?.isSplit == true && traitCollection.horizontalSizeClass == .regular && traitCollection.verticalSizeClass == .regular {
            titleAuthorHeadings.forEach { $0.scaleFontBy(1.3) }
        }

        bookDescription.font = UIFont.gillSans(forTextStyle: .subheadline)
        bookNotes.font = UIFont.gillSans(forTextStyle: .subheadline)

        // A setting allows the full book description label to be shown on load
        if GeneralSettings.showExpandedDescription {
            bookDescription.numberOfLines = 0
        }

        // Watch for changes in the managed object context
        NotificationCenter.default.addObserver(self, selector: #selector(saveOccurred(_:)), name: .NSManagedObjectContextObjectsDidChange, object: PersistentStoreManager.container.viewContext)

        monitorThemeSetting()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if GeneralSettings.showExpandedDescription {
            bookDescription.numberOfLines = 0
        } else if traitCollection.horizontalSizeClass == .regular && traitCollection.verticalSizeClass == .regular {
            // In "regular" size classed devices, the description text can be less truncated
            bookDescription.numberOfLines = 8
        }
    }

    @IBAction private func updateReadingLogPressed(_ sender: Any) {
        guard let book = book else { return }
        present(EditBookReadState(existingBookID: book.objectID).inThemedNavController(), animated: true)
    }

    @IBAction private func editBookPressed(_ sender: Any) {
        guard let book = book else { return }
        present(EditBookMetadata(bookToEditID: book.objectID).inThemedNavController(), animated: true)
    }

    @IBAction private func updateNotesPressed(_ sender: Any) {
        guard let book = book else { return }
        present(EditBookNotes(existingBookID: book.objectID).inThemedNavController(), animated: true)
    }

    @objc func saveOccurred(_ notification: NSNotification) {
        guard let book = book, let userInfo = notification.userInfo else { return }

        let deletedObjects = userInfo[NSDeletedObjectsKey] as? NSSet
        guard deletedObjects?.contains(book) != true else {
            // If the book was deleted, set our book to nil and update this page. Pop back to the book table if necessary
            self.book = nil
            splitViewController?.masterNavigationController.popToRootViewController(animated: false)
            return
        }

        // FUTURE: Consider whether it is worth inspecting the changes to see if they affect this book; perhaps we should just always reload?
        let updatedObjects = userInfo[NSUpdatedObjectsKey] as? NSSet
        let refreshedObjects = userInfo[NSRefreshedObjectsKey] as? NSSet
        let createdObjects = userInfo[NSInsertedObjectsKey] as? NSSet
        func setContainsRelatedList(_ set: NSSet?) -> Bool {
            guard let set = set else { return false }
            return set.compactMap { $0 as? List }.contains { $0.books.contains(book) }
        }

        if updatedObjects?.contains(book) == true || refreshedObjects?.contains(book) == true || setContainsRelatedList(deletedObjects) || setContainsRelatedList(updatedObjects) || setContainsRelatedList(refreshedObjects) || setContainsRelatedList(createdObjects) {
            // If the book was updated, update this page.
            setupViewFromBook()
        }
    }

    @IBAction private func changeReadStateButtonWasPressed(_ sender: BorderedButton) {
        let feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.prepare()
        guard let book = book, book.readState == .toRead || book.readState == .reading else {
            assertionFailure("Change read state button pressed when not valid"); return
        }

        if book.readState == .toRead {
            book.setReading(started: Date())
        } else if let started = book.startedReading {
            book.setFinished(started: started, finished: Date())
        }
        book.updateSortIndex()
        book.managedObjectContext!.saveAndLogIfErrored()
        feedbackGenerator.notificationOccurred(.success)

        UserEngagement.logEvent(.transitionReadState)

        // Only request a review if this was a Start tap: there have been a bunch of reviews
        // on the app store which are for books, not for the app!
        if book.readState == .reading {
            UserEngagement.onReviewTrigger()
        }
    }

    @objc func amazonButtonPressed() {
        guard let book = book, let amazonLink = book.amazonAffiliateLink else { return }
        UserEngagement.logEvent(.viewOnAmazon)
        presentThemedSafariViewController(amazonLink)
    }

    @objc func googleBooksButtonPressed() {
        guard let googleBooksId = book?.googleBooksId else { return }
        guard let url = GoogleBooksRequest.webpage(googleBooksId).url else { return }
        presentThemedSafariViewController(url)
    }

    @IBAction private func addToList(_ sender: Any) {
        guard let book = book else { return }
        present(ManageLists.getAppropriateVcForManagingLists([book]) {
            UserEngagement.logEvent(.addBookToList)
            UserEngagement.onReviewTrigger()
        }, animated: true)
    }

    @IBAction private func shareButtonPressed(_ sender: UIBarButtonItem) {
        guard let book = book else { return }

        let activityViewController = UIActivityViewController(activityItems: ["\(book.titleAndSubtitle)\n\(book.authors.fullNames)"], applicationActivities: nil)
        activityViewController.popoverPresentationController?.barButtonItem = sender
        activityViewController.excludedActivityTypes = [.assignToContact, .saveToCameraRoll, .addToReadingList,
                                                        .postToFlickr, .postToVimeo, .openInIBooks, .markupAsPDF]

        present(activityViewController, animated: true, completion: nil)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let titleLabel = titleAuthorHeadings[0]
        let titleMaxYPosition = titleLabel.convert(titleLabel.frame, to: view).maxY
        if didShowNavigationItemTitle != (titleMaxYPosition - scrollView.adjustedContentInset.top < 0) {
            // Changes to the title view are to be animated
            let fadeTextAnimation = CATransition()
            fadeTextAnimation.duration = 0.2
            fadeTextAnimation.type = CATransitionType.fade

            navigationItem.titleView!.layer.add(fadeTextAnimation, forKey: nil)
            (navigationItem.titleView as! UILabel).isHidden = didShowNavigationItemTitle
            didShowNavigationItemTitle = !didShowNavigationItemTitle
        }
    }

    override var previewActionItems: [UIPreviewActionItem] {
        guard let book = book else { return [UIPreviewActionItem]() }

        var previewActions = [UIPreviewActionItem]()
        if book.readState == .toRead {
            previewActions.append(UIPreviewAction(title: "Start", style: .default) { _, _ in
                book.setReading(started: Date())
                book.updateSortIndex()
                book.managedObjectContext!.saveAndLogIfErrored()
                UserEngagement.logEvent(.transitionReadState)
            })
        } else if book.readState == .reading, let started = book.startedReading {
            previewActions.append(UIPreviewAction(title: "Finish", style: .default) { _, _ in
                book.setFinished(started: started, finished: Date())
                book.updateSortIndex()
                book.managedObjectContext!.saveAndLogIfErrored()
                UserEngagement.logEvent(.transitionReadState)
            })
        }
        previewActions.append(UIPreviewAction(title: "Delete", style: .destructive) { _, _ in
            book.deleteAndSave()
            UserEngagement.logEvent(.deleteBook)
        })
        return previewActions
    }
}

extension BookDetails: ThemeableViewController {
    @available(iOS, obsoleted: 13.0)
    func initialise(withTheme theme: Theme) {
        if #available(iOS 13.0, *) { return }
        view.backgroundColor = theme.viewBackgroundColor
        navigationController?.view.backgroundColor = theme.viewBackgroundColor
        navigationController?.navigationBar.initialise(withTheme: theme)
        (navigationItem.titleView as! UINavigationBarLabel).textColor = theme.titleTextColor
        titleAuthorHeadings[0].textColor = theme.titleTextColor
        titleAuthorHeadings[1].textColor = theme.subtitleTextColor
        changeReadStateButton.initialise(withTheme: theme)

        bookDescription.color = theme.subtitleTextColor
        bookDescription.gradientColor = theme.viewBackgroundColor
        bookDescription.buttonColor = theme.tint
        bookNotes.color = theme.subtitleTextColor
        bookNotes.gradientColor = theme.viewBackgroundColor

        amazon.textColor = theme.tint
        googleBooks.textColor = theme.tint
        titles.forEach { $0.textColor = theme.titleTextColor }
        tableSubHeadings.forEach { $0.textColor = theme.subtitleTextColor }
        tableValues.forEach { $0.textColor = theme.titleTextColor }
        separatorLines.forEach { $0.backgroundColor = theme.cellSeparatorColor }
        listsStack.arrangedSubviews.forEach { ($0 as! UILabel).textColor = theme.titleTextColor }
    }
}

extension Book {
    var amazonAffiliateLink: URL? {
        let authorText = authors.first?.fullName
        let amazonSearch = "https://www.amazon.com/s?url=search-alias%3Dstripbooks&field-author=\(authorText ?? "")&field-title=\(title)"

        // Use https://bestazon.io/#WebService to localize Amazon links
        // US store: readinglistio-20; UK store: readinglistio-21
        let refURL = "https://www.readinglistapp.xyz"
        return URL(string: "http://lnks.io/r.php?Conf_Source=API&refURL=\(refURL.urlEncoding())&destURL=\(amazonSearch.urlEncoding())&Amzn_AfiliateID_GB=readinglistio-21&Amzn_AfiliateID_US=readinglistio-20")
    }
}
