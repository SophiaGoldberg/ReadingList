import Foundation
import SafariServices
import UIKit

class ImportFromReadingList: UIViewController {
    @IBAction private func doneTapped(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
}

class ImportFromGoodreads: ImportFromReadingList {
    let goodreadsHelpPage = URL(string: "https://help.goodreads.com/s/article/How-do-I-import-or-export-my-books-1553870934590")!

    @IBAction private func moreInfoTapped(_ sender: Any) {
        present(SFSafariViewController(url: goodreadsHelpPage), animated: true)
    }
}
