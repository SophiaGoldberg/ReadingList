import UIKit
import Foundation

final class LabelPopoverViewController: UIViewController {
    var labelText: NSAttributedString!

    private var label: UILabel!
    private let labelPadding: CGFloat = 20

    convenience init(_ labelText: NSAttributedString) {
        self.init()
        preferredContentSize = CGSize(width: 300, height: 150)
        modalPresentationStyle = .popover
        self.labelText = labelText
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.translatesAutoresizingMaskIntoConstraints = false

        label = UILabel()
        label.attributedText = labelText
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false

        self.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: labelPadding),
            label.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -labelPadding),
            label.topAnchor.constraint(equalTo: self.view.topAnchor, constant: labelPadding)
            // leave bottom anchor constraint off - the point is we want the label to resize in height according to
            // its content, and then we will resize the main view to be the same size as the label.
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        view.setNeedsLayout()
        view.layoutIfNeeded()
        let labelSize = label.intrinsicContentSize
        preferredContentSize = CGSize(width: view.frame.width, height: labelSize.height + 2 * labelPadding)
    }
}
