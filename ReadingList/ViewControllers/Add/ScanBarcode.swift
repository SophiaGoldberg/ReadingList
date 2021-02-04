import UIKit
import AVFoundation
import SVProgressHUD
import ReadingList_Foundation
import CoreData
import os.log

final class ScanBarcode: UIViewController {

    // Communicate with the session and other session objects on this queue.
    private let sessionQueue = DispatchQueue(label: "session queue")
    let session = AVCaptureSession()

    var metadataOutput: AVCaptureMetadataOutput?

    var bulkAddedBooks = [Book]()
    var bulkAddLastScannedIsbn: String?

    /**
        Nil when not bulk adding, non-nil otherwise.
     */
    var bulkAddContext: NSManagedObjectContext?

    let feedbackGenerator = UINotificationFeedbackGenerator()

    @IBOutlet private weak var torchButton: UIBarButtonItem!
    @IBOutlet private weak var reviewBooksButton: UIBarButtonItem!
    @IBOutlet private weak var cameraPreviewView: PreviewView!
    @IBOutlet private weak var scanMultipleToggle: TogglableUIBarButtonItem!

    override func viewDidLoad() {
        super.viewDidLoad()
        if let device = AVCaptureDevice.default(for: .video), device.hasTorch { } else {
            torchButton.setHidden(true)
        }

        scanMultipleToggle.onToggle = { self.scanManyPressed($0) }

        feedbackGenerator.prepare()

        // To help with development, debug simulator builds detect taps on the screen and in response bring
        // up a dialog box to enter an ISBN to simulate a barcode scan.
        #if DEBUG && targetEnvironment(simulator)
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onViewTap(_:))))
        #endif

        setupAvSession()
    }

    #if DEBUG && targetEnvironment(simulator)
    @objc func onViewTap(_ recognizer: UILongPressGestureRecognizer) {
        present(TextBoxAlert(title: "ISBN", initialValue: "978", keyboardType: .numberPad) {
            guard let isbn = $0 else { return }
            self.respondToCapturedIsbn(isbn)
        }, animated: true)
    }
    #endif

    private func mayDiscardUnsavedChanges(actionDescription: String, discardAction: @escaping () -> Void) {
        if bulkAddContext == nil || bulkAddedBooks.isEmpty {
            // If not in bulk scan mode, there is no unsaved work
            discardAction()
            return
        }

        let alert = UIAlertController(title: "Unsaved books", message: "You have \(bulkAddedBooks.count) unsaved \("book".pluralising(bulkAddedBooks.count)) which will be discarded if you \(actionDescription). Are you sure?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Discard", style: .destructive) { _ in
            discardAction()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true)
    }

    @IBAction private func cancelWasPressed(_ sender: AnyObject) {
        SVProgressHUD.dismiss()
        mayDiscardUnsavedChanges(actionDescription: "cancel now") {
            self.dismiss(animated: true)
        }
    }

    @IBAction private func scanManyPressed(_ enabled: Bool) {
        if enabled {
            switchScanMode(toBulk: true)
        } else {
            mayDiscardUnsavedChanges(actionDescription: "switch to scanning a single book") {
                self.switchScanMode(toBulk: false)
            }
        }
    }

    private func switchScanMode(toBulk bulk: Bool) {
        if bulk {
            bulkAddContext = PersistentStoreManager.container.viewContext.childContext()
            updateReviewBooksButton()
        } else {
            bulkAddContext = nil
            bulkAddedBooks.removeAll()
            bulkAddLastScannedIsbn = nil
            updateReviewBooksButton()
        }
        scanMultipleToggle.isToggled.toggle()
    }

    @IBAction private func reviewBooksPressed(_ sender: UIBarButtonItem) {
        guard let bulkAddContext = bulkAddContext else { return }
        let reviewBooks = ReviewBulkBooks()
        reviewBooks.books = bulkAddedBooks
        reviewBooks.context = bulkAddContext
        navigationController?.pushViewController(reviewBooks, animated: true)
    }

    func updateReviewBooksButton() {
        if bulkAddContext == nil || bulkAddedBooks.isEmpty {
            reviewBooksButton.title = "Review Books"
            reviewBooksButton.isEnabled = false
        } else {
            reviewBooksButton.title = "Review \(bulkAddedBooks.count) \("Book".pluralising(bulkAddedBooks.count))"
            reviewBooksButton.isEnabled = true
        }
    }

    @IBAction private func torchPressed(_ sender: UIBarButtonItem) {
        switch AVCaptureDevice.toggleTorch() {
        case true:
            sender.image = #imageLiteral(resourceName: "TorchFilled")
        case false:
            sender.image = #imageLiteral(resourceName: "Torch")
        default: break
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cameraPreviewView.layoutIfNeeded()

        // The torch deactivates itself when the view disappears, so ensure that the button reflects the state as it is when this view appears
        torchButton.image = #imageLiteral(resourceName: "Torch")

        sessionQueue.async {
            if !self.session.isRunning {
                self.session.startRunning()
                self.metadataOutput?.setMetadataObjectsDelegate(self, queue: self.sessionQueue)
            }
        }

        navigationController?.setToolbarHidden(false, animated: true)

        // If we are re-visiting this page, we may have deleted some of the objects from the review page;
        // for some reason, isDeleted doesn't return true! But the context becomes nil. Remove those objects.
        bulkAddedBooks.removeAll { $0.managedObjectContext == nil }
        updateReviewBooksButton()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Prevent the default behaviour of allowing a swipe-down to dismiss the modal presentation. This would
        // not give a confirmation alert before discarding a user's unsaved changes. By handling the dismiss event
        // ourselves we can present a confirmation dialog.
        isModalInPresentation = true
        navigationController?.presentationController?.delegate = self
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }

        navigationController?.setToolbarHidden(true, animated: true)
    }

    private func setupAvSession() {
        #if DEBUG
        if CommandLine.arguments.contains("--UITests_Screenshots") {
            // Not sure why, but the view frame seems way to big when running on iPad
            let frameToUse = UIDevice.current.userInterfaceIdiom == .pad ? CGRect(x: 0, y: 0, width: 600, height: 600) : view.frame
            let imageView = UIImageView(frame: frameToUse)
            imageView.image = UIImage(named: "example_barcode.jpg")!
            imageView.contentMode = .scaleAspectFill
            view.addSubview(imageView)
            return
        }
        if let isbnToSimulate = UserDefaults.standard.string(forKey: "barcode-isbn-simulation") {
            DispatchQueue.main.async {
                self.respondToCapturedIsbn(isbnToSimulate)
            }
            return
        }
        // We want to ignore any actual errors, like not having a camera, so return if UITesting
        if CommandLine.arguments.contains("--UITests") { return }
        #endif

        guard let camera = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: camera) else {
            #if !(DEBUG && targetEnvironment(simulator))
            presentCameraPermissionsAlert()
            #endif
            return
        }

        cameraPreviewView.session = session
        cameraPreviewView.videoPreviewLayer.videoGravity = .resizeAspectFill

        // Try to focus the camera if possible
        if camera.isFocusPointOfInterestSupported == true {
            try? camera.lockForConfiguration()
            camera.focusPointOfInterest = cameraPreviewView.center
        }

        setVideoOrientation()

        sessionQueue.async {
            self.metadataOutput = AVCaptureMetadataOutput()

            // Check that we can add the input and output to the session
            guard let metadataOutput = self.metadataOutput, self.session.canAddInput(input) && self.session.canAddOutput(metadataOutput) else {
                DispatchQueue.main.async {
                    self.presentInfoAlert(title: "Error ⚠️", message: "The camera could not be used. Sorry about that.")
                    self.feedbackGenerator.notificationOccurred(.error)
                }
                return
            }

            // Prepare the metadata output and add to the session
            self.session.addInput(input)
            metadataOutput.setMetadataObjectsDelegate(self, queue: self.sessionQueue)
            self.session.addOutput(metadataOutput)

            // This line must be after session outputs are added
            metadataOutput.metadataObjectTypes = [.ean13]

            // Begin the capture session.
            self.session.startRunning()
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        setVideoOrientation()
    }

    private func setVideoOrientation() {
        guard cameraPreviewView.videoPreviewLayer.connection?.isVideoOrientationSupported == true else { return }
        cameraPreviewView.videoPreviewLayer.connection?.videoOrientation = UIDevice.current.orientation.videoOrientation ?? .portrait
    }

    func respondToCapturedIsbn(_ isbn: String) {
        feedbackGenerator.prepare()

        // If we are bulk adding books, ensure that this isn't the most recently scanned book
        if bulkAddContext != nil {
            if isbn == bulkAddLastScannedIsbn {
                // Don't even give a warning: re-scanning the last ISBN can be done very easily
                return
            } else {
                // Remember that we have seen this ISBN
                bulkAddLastScannedIsbn = isbn
            }
        }

        // Since we have a result, stop the metadata capture
        metadataOutput?.setMetadataObjectsDelegate(nil, queue: nil)

        // Check that the book hasn't already been added
        if let existingBook = Book.get(fromContext: PersistentStoreManager.container.viewContext, isbn: isbn) {
            feedbackGenerator.notificationOccurred(.warning)
            handleDuplicateBook(existingBook)
        } else if let existingBulkBook = bulkAddedBooks.first(where: { $0.isbn13?.string == isbn }) {
            feedbackGenerator.notificationOccurred(.warning)
            handleDuplicateBook(existingBulkBook)
        } else {
            feedbackGenerator.notificationOccurred(.success)
            searchForFoundIsbn(isbn: isbn)
        }
    }

    func handleDuplicateBook(_ book: Book) {
        if bulkAddContext != nil {
            SVProgressHUD.showError(withStatus: "Already Added")
            metadataOutput?.setMetadataObjectsDelegate(self, queue: sessionQueue)
            return
        }
        let alert = UIAlertController.duplicateBook(goToExistingBook: {
            self.dismiss(animated: true) {
                guard let tabBarController = AppDelegate.shared.tabBarController else {
                    assertionFailure()
                    return
                }
                tabBarController.simulateBookSelection(book, allowTableObscuring: true)
            }
        }, cancel: {
            self.metadataOutput?.setMetadataObjectsDelegate(self, queue: self.sessionQueue)
        })

        present(alert, animated: true)
    }

    func searchForFoundIsbn(isbn: String) {
        // We're going to be doing a search online, so bring up a spinner
        SVProgressHUD.show(withStatus: "Searching...")

        GoogleBooksApi().fetch(isbn: isbn)
            .always(on: .main) { SVProgressHUD.dismiss() }
            .catch(on: .main) { error in
                self.feedbackGenerator.notificationOccurred(.error)
                switch error {
                case GoogleBooksApi.ResponseError.noResult: self.handleNoExactMatch(forIsbn: isbn)
                default: self.onSearchError(error)
                }
            }
            .then(on: .main, handleFetchSuccess(_:))
    }

    func handleFetchSuccess(_ fetchResult: GoogleBooksApi.FetchResult) {
        if let existingBook = Book.get(fromContext: bulkAddContext ?? PersistentStoreManager.container.viewContext, googleBooksId: fetchResult.id) {
            self.feedbackGenerator.notificationOccurred(.warning)
            self.handleDuplicateBook(existingBook)
            return
        }

        self.feedbackGenerator.notificationOccurred(.success)

        // If there is no duplicate, we can safely proceed. The context we add the book to depends on the
        // mode we are operating in.
        let context = self.bulkAddContext ?? PersistentStoreManager.container.viewContext.childContext()
        let book = Book(context: context)
        book.populate(fromFetchResult: fetchResult)

        if self.bulkAddContext == nil {
            UserEngagement.logEvent(.scanBarcode)

            // If we are just adding one book, we push to the screen to edit the read state of this book
            self.navigationController?.pushViewController(
                EditBookReadState(newUnsavedBook: book, scratchpadContext: context),
                animated: true)
        } else {
            UserEngagement.logEvent(.scanBarcodeBulk)
            SVProgressHUD.showSuccess(withStatus: "Book Added")

            // If we are in Bulk Add mode, set the book to To Read for now then add the book to our array
            book.setToRead()
            book.updateSortIndex()
            self.bulkAddedBooks.append(book)

            // Update the toolbar button and restart the metadata capture
            self.updateReviewBooksButton()
            self.metadataOutput?.setMetadataObjectsDelegate(self, queue: sessionQueue)
        }
    }

    func handleNoExactMatch(forIsbn isbn: String) {
        // We don't want to give the user the option of leaving this screen and entering a new workflow if they
        // are in the middle of a bulk barcode scan operation.
        if bulkAddContext != nil {
            SVProgressHUD.showError(withStatus: "No Match Found")
            self.metadataOutput?.setMetadataObjectsDelegate(self, queue: sessionQueue)
            return
        }
        let alert = UIAlertController(title: "No Exact Match",
                                      message: "We couldn't find an exact match. Would you like to do a more general search instead?",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "No", style: .cancel) { _ in
            self.metadataOutput?.setMetadataObjectsDelegate(self, queue: self.sessionQueue)
        })
        alert.addAction(UIAlertAction(title: "Yes", style: .default) { _ in
            let presentingViewController = self.presentingViewController
            self.dismiss(animated: true) {
                let searchOnlineNav = UIStoryboard.SearchOnline.rootAsFormSheet() as! UINavigationController
                (searchOnlineNav.viewControllers.first as! SearchOnline).initialSearchString = isbn
                presentingViewController!.present(searchOnlineNav, animated: true, completion: nil)
            }
        })
        present(alert, animated: true, completion: nil)
    }

    func onSearchError(_ error: Error) {
        let message: String
        switch (error as NSError).code {
        case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
            message = "There seems to be no internet connection."
        default:
            message = "Something went wrong when searching online. Maybe try again?"
        }
        presentInfoAlert(title: "Error ⚠️", message: message)
    }

    func presentInfoAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.dismiss(animated: true, completion: nil)
        })
        present(alert, animated: true, completion: nil)
    }

    func presentCameraPermissionsAlert() {
        let alert = UIAlertController(title: "Permission Required", message: "You'll need to change your settings to allow Reading List to use your device's camera.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let appSettings = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(appSettings) {
                UIApplication.shared.open(appSettings, options: [:])
                self.dismiss(animated: false)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            self.dismiss(animated: true)
        })
        feedbackGenerator.notificationOccurred(.error)
        present(alert, animated: true, completion: nil)
    }
}

extension ScanBarcode: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let avMetadata = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
            let isbn = ISBN13(avMetadata.stringValue) else { return }

        DispatchQueue.main.async {
            self.respondToCapturedIsbn(isbn.string)
        }
    }
}

extension ScanBarcode: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        // If the user swipes down, we either dismiss or present a confirmation dialog
        mayDiscardUnsavedChanges(actionDescription: "cancel now") {
            self.dismiss(animated: true)
        }
    }
}

class BarcodeScanPreviewOverlay: UIView {
    override func awakeFromNib() {
        super.awakeFromNib()

        layer.borderColor = UIColor.red.cgColor
        layer.borderWidth = 1.0
    }
}
