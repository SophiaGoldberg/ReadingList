import Foundation
import UIKit

class ImportFormatDetails: UITableViewController {
    private let csvColumns = BookCSVColumn.allCases
    private let csvColumnsSectionIndex = 1

    @IBAction private func doneTapped(_ sender: UIBarButtonItem) {
        self.presentingViewController?.dismiss(animated: true)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 0
        case csvColumnsSectionIndex:
            return csvColumns.count
        default:
            assertionFailure()
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard section == 0 else { return nil }
        return """
        To import books into Reading List, provide a CSV file with the following column headers. For \
        information about the format of a particular column, tap the info icon. All columns are optional \
        except the Title and Authors.
        """
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "basicCell", for: indexPath)
        if indexPath.section == csvColumnsSectionIndex {
            let csvColumn = csvColumns[indexPath.row]
            cell.textLabel?.text = csvColumn.header
            if csvColumn.helpText != nil {
                let button = UIButton(type: .infoLight)
                button.tag = indexPath.row
                button.addTarget(self, action: #selector(infoButtonTapped(sender:)), for: .touchUpInside)
                cell.accessoryView = button
            } else {
                cell.accessoryView = nil
            }
        }
        return cell
    }

    @objc func infoButtonTapped(sender: UIButton) {
        let indexPath = IndexPath(row: sender.tag, section: csvColumnsSectionIndex)

        guard let helpText = csvColumns[indexPath.row].helpText else { return }
        let columnDetailsViewController = LabelPopoverViewController(helpText)

        let preferredWidth = min(view.frame.width - 60, 500)
        columnDetailsViewController.preferredContentSize = CGSize(width: preferredWidth, height: 150)
        columnDetailsViewController.modalPresentationStyle = .popover

        guard let presentationController = columnDetailsViewController.presentationController else { preconditionFailure() }
        presentationController.delegate = self

        guard let popoverController = columnDetailsViewController.popoverPresentationController else { preconditionFailure() }
        let tableViewCell = tableView.cellForRow(at: indexPath)!
        if let accesssoryView = tableViewCell.accessoryView {
            popoverController.sourceView = accesssoryView
            popoverController.permittedArrowDirections = [.up, .down]
        } else {
            popoverController.setSourceCell(atIndexPath: indexPath, inTable: tableView)
        }

        self.present(columnDetailsViewController, animated: true)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        self.dismiss(animated: false)
    }
}

extension ImportFormatDetails: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
}

private extension BookCSVColumn {
    var helpText: NSAttributedString? {
        let mainFont = UIFont.preferredFont(forTextStyle: .callout)
        let calloutFontDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .callout)
        let highlightFont = UIFont.monospacedSystemFont(ofSize: calloutFontDescriptor.pointSize, weight: .regular)

        switch self {
        case .title:
            return NSAttributedString("Required column.", font: mainFont)
        case .authors:
            return NSMutableAttributedString("Required column.\n\nEach author should be written as ", font: mainFont)
                .appending("Lastname, Firstnames", font: highlightFont)
                .appending(", and if there are multiple authors, they should be separated by a semicolon (", font: mainFont)
                .appending(";", font: highlightFont)
                .appending(").\n\nFor example:\n", font: mainFont)
                .appending("King, Stephen; Straub, Peter", font: highlightFont)
        case .startedReading:
            return NSMutableAttributedString("Should be provided in the form: ", font: mainFont)
                .appending("YYYY-MM-DD", font: highlightFont)
                .appending("""
                    . If a value is provided, then the book will be imported as either Reading or Finished \
                    (depending on whether there is a value for \

                    """, font: mainFont)
                .appending(BookCSVColumn.finishedReading.header, font: highlightFont)
                .appending(". If no value is provided, then the book will be imported as To Read.", font: mainFont)
        case .finishedReading:
            return NSMutableAttributedString("Should be provided in the form: ", font: mainFont)
                .appending("YYYY-MM-DD", font: highlightFont)
                .appending(".\n\nIf a value is provided for both ", font: mainFont)
                .appending(BookCSVColumn.startedReading.header, font: highlightFont)
                .appending(" and ", font: mainFont)
                .appending(BookCSVColumn.finishedReading.header, font: highlightFont)
                .appending("""
                     then the book will be imported as Finished. If no valid is provided, then \
                    the book will be imported as either To Read or Reading, depending on whether \
                    there is a value for \

                    """, font: mainFont)
                .appending(BookCSVColumn.startedReading.header, font: highlightFont)
                .appending(").", font: mainFont)
        case .language:
            return NSAttributedString("An ISO 639.1 two-letter language code.", font: mainFont)
        case .lists:
            return NSMutableAttributedString("""
                If provided, should contain all lists which contain this book in a semicolon separated list, with the book position \
                in the list in brackets after the list name. E.g.:

                """, font: mainFont)
                .appending("Sci-Fi (19); Recommendations (3)", font: highlightFont)
        default: return nil
        }
    }
}
