import Foundation
import UIKit
import ReadingList_Foundation

class BookTableViewCell: UITableViewCell {
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var authorsLabel: UILabel!

    @IBOutlet private weak var readTimeLabel: UILabel!
    @IBOutlet private weak var readingProgress: UIProgressView!
    @IBOutlet private weak var readingProgressLabel: UILabel!
    @IBOutlet private weak var coverImage: UIImageView!
    @IBOutlet private weak var coverPlaceholder: UIView!
    private var coverImageRequest: URLSessionDataTask?

    func resetUI() {
        titleLabel.text = nil
        authorsLabel.text = nil
        readTimeLabel.text = nil
        coverImage.image = nil
        coverImage.isHidden = true
        coverPlaceholder.isHidden = false
        readingProgress.isHidden = true
        readingProgressLabel.text = nil
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        titleLabel.font = .systemFont(ofSize: titleLabel.font.pointSize, weight: .medium)
        resetUI()
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        // Cancel any pending cover data request task
        coverImageRequest?.cancel()
        coverImageRequest = nil

        resetUI()
    }

    func requiresUpdate(_ book: Book, includeReadDates: Bool = true) -> Bool {
        // TODO: We are not checking for image differences
        return titleLabel.text != book.title || authorsLabel.text != book.authors.fullNames
            || (coverImage.image == nil && book.coverImage != nil) || ((coverImage.image == nil) != (book.coverImage == nil))
    }

    func configureFrom(_ book: Book, includeReadDates: Bool = true) {
        titleLabel.text = book.titleAndSubtitle
        authorsLabel.text = book.authors.fullNames
        if let coverData = book.coverImage, let bookCoverImage = UIImage(data: coverData) {
            coverImage.image = bookCoverImage
            coverImage.isHidden = false
            coverPlaceholder.isHidden = true
        } else {
            coverImage.isHidden = true
            coverPlaceholder.isHidden = false
        }

        if includeReadDates {
            switch book.readState {
            case .reading: readTimeLabel.text = book.startedReading!.toPrettyString()
            case .finished: readTimeLabel.text = book.finishedReading!.toPrettyString()
            default: readTimeLabel.text = nil
            }

            // Configure the reading progress display
            if let currentPercentage = book.currentPercentage {
                configureReadingProgress(text: "\(currentPercentage)%", progress: Float(currentPercentage) / 100)
            }
        }

        #if DEBUG
            if Debug.showSortNumber {
                titleLabel.text = "(\(book.sort)) \(book.title)"
            }
        #endif
    }

    private func configureReadingProgress(text: String?, progress: Float) {
        readingProgressLabel.text = text
        readingProgress.isHidden = false
        readingProgress.progress = progress
    }

    func configureFrom(_ searchResult: GoogleBooksApi.SearchResult) {
        titleLabel.text = searchResult.titleAndSubtitle
        authorsLabel.text = searchResult.authorList

        if let coverURL = searchResult.thumbnailImage {
            coverImageRequest = URLSession.shared.startedDataTask(with: coverURL) { [weak self] data, _, _ in
                guard let cell = self, let data = data else { return }
                DispatchQueue.main.async {
                    // Cancellations appear to be reported as errors. Ideally we would detect non-cancellation
                    // errors (e.g. 404), and show the placeholder in those cases. For now, just make the image blank.
                    if let bookCoverImage = UIImage(data: data) {
                        cell.coverImage.image = bookCoverImage
                        cell.coverImage.isHidden = false
                        cell.coverPlaceholder.isHidden = true
                    }
                }
            }
        }
    }
}
