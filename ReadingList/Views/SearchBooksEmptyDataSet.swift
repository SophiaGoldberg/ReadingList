import Foundation
import UIKit

class SearchBooksEmptyDataset: UIView {

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var descriptionLabel: UILabel!
    @IBOutlet private weak var poweredByGoogle: UIImageView!
    @IBOutlet private weak var topConstraint: NSLayoutConstraint!

    enum EmptySetReason {
        case noSearch
        case noResults
        case error
    }

    func setEmptyDatasetReason(_ reason: EmptySetReason) {
        self.reason = reason
        titleLabel.text = title
        descriptionLabel.text = descriptionString
    }

    func setTopDistance(_ distance: CGFloat) {
        topConstraint.constant = distance
        self.layoutIfNeeded()
    }

    private var reason = EmptySetReason.noSearch

    private var title: String {
        switch reason {
        case .noSearch:
            return "🔍 Search Books"
        case .noResults:
            return "😞 No Results"
        case .error:
            return "⚠️ Error!"
        }
    }

    private var descriptionString: String {
        switch reason {
        case .noSearch:
            return "Search books by title, author, ISBN - or a mixture!"
        case .noResults:
            return "There were no Google Books search results. Try changing your search text."
        case .error:
            return "Something went wrong! It might be your Internet connection..."
        }
    }
}
