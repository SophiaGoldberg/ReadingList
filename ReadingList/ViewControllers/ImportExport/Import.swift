import Foundation
import ReadingList_Foundation
import PersistedPropertyWrapper
import UIKit
import SVProgressHUD

final class Import: UITableViewController {
    @IBOutlet private weak var downloadMetadataSwitch: UISwitch!
    @IBOutlet private weak var downloadMetadataLabel: UILabel!
    @IBOutlet private weak var downloadCoversSwitch: UISwitch!
    @IBOutlet private weak var downloadCoversLabel: UILabel!
    @IBOutlet private weak var overwriteExistingSwitch: UISwitch!
    @IBOutlet private weak var importFormatDescription: UILabel!
    @IBOutlet private  weak var selectCsvFileCellLabel: UILabel!
    private let selectFileCellIndex = IndexPath(row: 0, section: 3)

    /** We modify settings when switching to Goodreads, so we should be able to undo the changes if the user then switches back. */
    var importSettingsPreGoodreads: BookCSVImportSettings?

    @Persisted("importFormat", defaultValue: .readingList)
    private var importFormat: CSVImportFormat {
        didSet {
            if importFormat == .goodreads {
                importSettingsPreGoodreads = importSettings
                importSettings.downloadMetadata = false
                importSettings.downloadCoverImages = false
            } else if let previousSettngs = importSettingsPreGoodreads {
                importSettings.downloadMetadata = previousSettngs.downloadMetadata
                importSettings.downloadCoverImages = previousSettngs.downloadCoverImages
            }

            refreshUI()
        }
    }

    @Persisted(encodedDataKey: "importSettings", defaultValue: .init())
    var importSettings: BookCSVImportSettings

    /** Set to a file URL to have the file selection cell be an Import button, which will start importing from this file. */
    var preProvidedImportFile: URL? {
        didSet {
            if isViewLoaded {
                refreshUI()
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Import From CSV"
        refreshUI()
    }

    private func refreshUI() {
        importFormatDescription.text = importFormat.description
        overwriteExistingSwitch.isOn = importSettings.overwriteExistingBooks

        // Cover and metadata download isn't supported when importing from Goodreads; ensure the UI reflects this by disabling the settings.
        downloadMetadataSwitch.isOn = importSettings.downloadMetadata
        downloadMetadataSwitch.isEnabled = importFormat != .goodreads
        downloadMetadataLabel.isEnabled = importFormat != .goodreads
        downloadCoversSwitch.isOn = importSettings.downloadCoverImages
        downloadCoversSwitch.isEnabled = importFormat != .goodreads
        downloadCoversLabel.isEnabled = importFormat != .goodreads

        // If a CSV file has been pre-provided, then our UI is a little different, in that the
        // "Select CSV File" button is now an "Import" button.
        if preProvidedImportFile != nil {
            selectCsvFileCellLabel.text = "Import"
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath == IndexPath(row: 0, section: 0) {
            let alert = UIAlertController(title: "Select Import Format", message: nil, preferredStyle: .actionSheet)
            alert.addActions(CSVImportFormat.allCases.map { format in
                UIAlertAction(title: format.description, style: .default) { _ in
                    if self.importFormat != format {
                        UserEngagement.logEvent(.changeCsvImportFormat)
                    }
                    self.importFormat = format
                }
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.popoverPresentationController?.setSourceCell(atIndexPath: indexPath, inTable: tableView)
            present(alert, animated: true)
        } else if indexPath == IndexPath(row: 1, section: 0) {
            switch importFormat {
            case .readingList:
                performSegue(withIdentifier: "showFormatDetails", sender: self)
            case .goodreads:
                performSegue(withIdentifier: "showGoodreadsInfo", sender: self)
            }
        } else if indexPath == selectFileCellIndex {
            if let importFile = preProvidedImportFile {
                confirmImport(fromFile: importFile)
            } else {
                presentDocumentPicker(presentingIndexPath: indexPath)
            }
        } else {
            return
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }

    @IBAction private func downloadMetadataChanged(_ sender: UISwitch) {
        UserEngagement.logEvent(.changeCsvImportSettings)
        importSettings.downloadMetadata = sender.isOn
    }

    @IBAction private func downloadCoversChanged(_ sender: UISwitch) {
        UserEngagement.logEvent(.changeCsvImportSettings)
        importSettings.downloadCoverImages = sender.isOn
    }

    @IBAction private func overwriteExistingBooksChanged(_ sender: UISwitch) {
        UserEngagement.logEvent(.changeCsvImportSettings)
        importSettings.overwriteExistingBooks = sender.isOn
    }

    func presentDocumentPicker(presentingIndexPath: IndexPath) {
        let documentPicker = UIDocumentPickerViewController(documentTypes: ["public.comma-separated-values-text"], in: .import)
        documentPicker.delegate = self
        documentPicker.popoverPresentationController?.setSourceCell(atIndexPath: presentingIndexPath, inTable: tableView, arrowDirections: .up)
        present(documentPicker, animated: true)
    }

    func confirmImport(fromFile url: URL) {
        var message = "Are you sure you want to import books from this file?"
        if importSettings.overwriteExistingBooks {
            message += " This will overwrite any existing books which have a matching ISBN"
            switch importFormat {
            case .readingList:
                message += " or Google Books ID"
            case .goodreads:
                // So, we do use Goodreads ID (in the manual ID slot), but we're not very explicit or clear about it.
                // Let's indicate that we do this, but without opening the can of worms about
                // having to explain what the "ID" is.
                message += " or ID"
            }
            message += "."
        }
        let alert = UIAlertController(title: "Confirm \(importFormat.description) Import", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Import", style: .default) { _ in
            SVProgressHUD.show(withStatus: "Importing")
            UserEngagement.logEvent(self.importFormat == .readingList ? .csvImport : .csvGoodReadsImport)

            let csvImporter = BookCSVImporter(format: self.importFormat, settings: self.importSettings)
            csvImporter.startImport(fromFileAt: url) { result in
                switch result {
                case .failure(let error):
                    SVProgressHUD.dismiss()
                    self.presentCsvErrorAlert(error)
                case .success(let importResults):
                    var statusMessagePieces = ["\(importResults.success.itemCount(singular: "book")) imported"]
                    if importResults.duplicate != 0 { statusMessagePieces.append("\(importResults.duplicate.itemCount(singular: "row")) ignored due pre-existing data") }
                    if importResults.error != 0 { statusMessagePieces.append("\(importResults.error.itemCount(singular: "row")) ignored due to invalid data") }
                    SVProgressHUD.showInfo(withStatus: statusMessagePieces.joined(separator: ". "))
                }
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true)
    }

    func presentCsvErrorAlert(_ error: CSVImportError) {
        let alert = UIAlertController(title: error.title, message: """
            The provided CSV file was \(error.reason). Please ensure that the provided file meets the
            requirements of the \(importFormat) CSV format.
            """, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
        self.present(alert, animated: true)
    }
}

extension CSVImportError {
    var title: String {
        switch self {
        case .invalidCsv: return "Invalid CSV File"
        case .missingHeaders: return "Missing CSV Columns"
        }
    }

    var reason: String {
        switch self {
        case .invalidCsv: return "not valid"
        case .missingHeaders: return "missing required columns"
        }
    }
}

extension Import: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        confirmImport(fromFile: url)
    }
}
