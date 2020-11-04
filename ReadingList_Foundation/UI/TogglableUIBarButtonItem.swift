import UIKit

public class TogglableUIBarButtonItem: UIBarButtonItem {
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        button.layer.cornerRadius = 10
        if let title = title {
            button.setTitle(" \(title) ", for: .normal)
        }
        button.addTarget(self, action: #selector(buttonPressed(_:)), for: .touchUpInside)
        customView = button
        configureButton()
    }

    /// Callback function, passed what the new state of the toggle would be after the tap.
    public var onToggle: ((Bool) -> Void)?
    public var isToggled = false {
        didSet {
            configureButton()
        }
    }

    private let button = UIButton()

    private func configureButton() {
        if isToggled {
            button.backgroundColor = tintColor
            button.setTitleColor(.white, for: .normal)
        } else {
            button.backgroundColor = .clear
            button.setTitleColor(tintColor, for: .normal)
        }
    }

    @objc private func buttonPressed(_ sender: UIButton) {
        onToggle?(!isToggled)
    }
}
