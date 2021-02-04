import Foundation
import UIKit

public enum EmptyStatePosition {
    case top
    case center
}

public class EmptyStateView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    var title: UILabel!
    var text: UILabel!
    var topConstraint: NSLayoutConstraint!
    var centerConstraint: NSLayoutConstraint!

    func setupView() {
        title = UILabel()
        title.text = "Title"
        title.textAlignment = .center
        title.font = .preferredFont(forTextStyle: .title1)
        title.textColor = .label
        title.translatesAutoresizingMaskIntoConstraints = false
        addSubview(title)

        text = UILabel()
        text.text = "Text"
        text.textAlignment = .center
        text.font = .preferredFont(forTextStyle: .body)
        text.textColor = .secondaryLabel
        text.translatesAutoresizingMaskIntoConstraints = false
        text.numberOfLines = 0
        addSubview(text)

        centerConstraint = text.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 0)
        topConstraint = title.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 16)

        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 16),
            title.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
            text.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 16),
            text.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            text.trailingAnchor.constraint(equalTo: title.trailingAnchor),
            centerConstraint
        ])
    }

    var position = EmptyStatePosition.center {
        didSet {
            switch position {
            case .top:
                topConstraint.isActive = true
                centerConstraint.isActive = false
            case .center:
                topConstraint.isActive = false
                centerConstraint.isActive = true
            }
        }
    }
}
