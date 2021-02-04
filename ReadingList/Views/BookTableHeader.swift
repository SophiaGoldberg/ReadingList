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
    @IBOutlet private weak var numberBadgeLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        if let descriptor = label.font.fontDescriptor.withDesign(.rounded) {
            label.font = UIFont(descriptor: descriptor, size: label.font.pointSize)
        }
        numberBadgeLabel.font = .rounded(ofSize: numberBadgeLabel.font.pointSize, weight: .semibold)
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

    func configure(labelText: String, badgeNumber: Int?, enableSort: Bool) {
        label.text = labelText
        sortButton.isEnabled = enableSort
        if let badgeNumber = badgeNumber {
            numberBadgeLabel.superview!.isHidden = false
            numberBadgeLabel.text = "\(badgeNumber)"
        } else {
            numberBadgeLabel.superview!.isHidden = true
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
        configure(labelText: "\(readState.description)", badgeNumber: bookCount, enableSort: enableSort)
        orderable = .book(readState)
        alertOrMenu = buildBookSortAlertOrMenu()
    }

    func configure(list: List, bookCount: Int, enableSort: Bool) {
        configure(labelText: "\(bookCount) book\(bookCount == 1 ? "" : "s")", badgeNumber: nil, enableSort: enableSort)
        orderable = .list(list)
        alertOrMenu = buildBookSortAlertOrMenu()
    }
}
