import Foundation
import UIKit
import ReadingList_Foundation

class BookTableHeader: UITableViewHeaderFooterView {

    var orderable: Orderable?
    weak var presenter: UITableViewController?
    var onSortChanged: (() -> Void)?
    var alertOrMenu: AlertOrMenu! {
        didSet {
            if #available(iOS 14.0, *) {
                sortButton.showsMenuAsPrimaryAction = true
                // Rebuild the menu each time alertOrMenu is reassigned
                sortButton.menu = alertOrMenu.menu()
            }
        }
    }

    static let height: CGFloat = 50
    @IBOutlet private weak var label: UILabel!
    @IBOutlet private weak var sortButton: UIButton!

    override func awakeFromNib() {
        super.awakeFromNib()
        if #available(iOS 13.0, *) {
            sortButton.setImage(UIImage(systemName: "arrow.up.arrow.down.circle"), for: .normal)
        }
    }

    @IBAction private func sortButtonTapped(_ sender: UIButton) {
        if #available(iOS 14.0, *) {
            assert(sender.showsMenuAsPrimaryAction)
            return
        }

        let alert = alertOrMenu.actionSheet()
        alert.popoverPresentationController?.setButton(sortButton)
        presenter?.present(alert, animated: true, completion: nil)
    }

    func configure(labelText: String, enableSort: Bool) {
        label.text = labelText
        sortButton.isEnabled = enableSort
        if #available(iOS 13.0, *) { } else {
            initialise(withTheme: GeneralSettings.theme)
        }
    }

    private func buildBookSortAlertOrMenu() -> AlertOrMenu {
        guard let orderable = orderable else { preconditionFailure() }
        let selectedSort = orderable.getSort()
        return AlertOrMenu(title: "Choose Order", items: BookSort.allCases.filter { orderable.supports($0) }.map { sort in
            AlertOrMenu.Item(title: sort == selectedSort ? "\(sort.description) ✓" : sort.description) { [weak self] in
                if selectedSort == sort { return }
                orderable.setSort(sort)
                guard let `self` = self else { return }
                // Rebuild the menu, so the tick is in the right place next time
                if #available(iOS 14.0, *) {
                    self.alertOrMenu = self.buildBookSortAlertOrMenu()
                }
                self.onSortChanged?()
            }
        })
    }

    func configure(readState: BookReadState, bookCount: Int, enableSort: Bool) {
        configure(labelText: "\(readState.description.uppercased()) (\(bookCount))", enableSort: enableSort)
        orderable = .book(readState)
        alertOrMenu = buildBookSortAlertOrMenu()
    }

    func configure(list: List, bookCount: Int, enableSort: Bool) {
        configure(labelText: "\(bookCount) BOOK\(bookCount == 1 ? "" : "S")", enableSort: enableSort)
        orderable = .list(list)
        alertOrMenu = buildBookSortAlertOrMenu()
    }

    private func initialise(withTheme theme: Theme) {
        if #available(iOS 13.0, *) { } else {
            label.textColor = theme.subtitleTextColor
            sortButton.tintColor = theme.subtitleTextColor
        }
    }
}
