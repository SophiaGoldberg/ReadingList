import Foundation
import UIKit

struct ProprietaryURLActionHandler {
    var window: UIWindow

    init(window: UIWindow) {
        self.window = window
    }

    func handle(_ action: ProprietaryURLAction) -> Bool {
        switch action {
        case .viewBook(let id):
            UserEngagement.logEvent(.openBookFromUrl)
            if let book = getBookFromIdentifier(id) {
                showBook(book)
                return true
            } else {
                return false
            }
        case .editBookReadLog(let id):
            UserEngagement.logEvent(.openEditReadLogFromUrl)
            if let book = getBookFromIdentifier(id) {
                showReadLog(for: book)
                return true
            } else {
                return false
            }
        case .addBookSearchOnline:
            UserEngagement.logEvent(.openSearchOnlineFromUrl)
            searchOnline()
            return true
        case .addBookScanBarcode:
            UserEngagement.logEvent(.openScanBarcodeFromUrl)
            scanBarcode()
            return true
        case .addBookManually:
            UserEngagement.logEvent(.openAddManuallyFromUrl)
            addManually()
            return true
        }
    }

    func getBookFromIdentifier(_ identifier: BookIdentifier) -> Book? {
        switch identifier {
        case .googleBooksId(let googleBooksId):
            return Book.get(fromContext: PersistentStoreManager.container.viewContext, googleBooksId: googleBooksId)
        case .isbn(let isbn):
            return Book.get(fromContext: PersistentStoreManager.container.viewContext, isbn: isbn)
        case .manualId(let manualId):
            return Book.get(fromContext: PersistentStoreManager.container.viewContext, manualBookId: manualId)
        }
    }

    func showBook(_ book: Book) {
        guard let tabBarController = window.rootViewController as? TabBarController else {
            assertionFailure()
            return
        }
        tabBarController.simulateBookSelection(book, allowTableObscuring: true)
    }

    func showReadLog(for book: Book) {
        guard let tabBarController = window.rootViewController as? TabBarController,
              let selectedViewController = tabBarController.selectedSplitViewController else {
            assertionFailure()
            return
        }
        selectedViewController.present(
            EditBookReadState(existingBookID: book.objectID).inNavigationController(),
            animated: false
        )
    }

    func searchOnline() {
        guard let tabBarController = window.rootViewController as? TabBarController else {
            assertionFailure()
            return
        }
        QuickAction.searchOnline.perform(from: tabBarController)
    }

    func scanBarcode() {
        guard let tabBarController = window.rootViewController as? TabBarController else {
            assertionFailure()
            return
        }
        QuickAction.scanBarcode.perform(from: tabBarController)
    }

    func addManually() {
        guard let tabBarController = window.rootViewController as? TabBarController else {
            assertionFailure()
            return
        }
        tabBarController.selectedTab = .toRead

        // Dismiss any modal views before presenting
        let navController = tabBarController.selectedSplitViewController!.masterNavigationController
        navController.dismissAndPopToRoot()

        let viewController = EditBookMetadata(bookToCreateReadState: .toRead).inNavigationController()
        navController.viewControllers.first!.present(viewController, animated: true, completion: nil)
    }
}
