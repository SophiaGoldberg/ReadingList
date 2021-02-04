import Foundation
import UIKit
import os.log

class FullScreenProgress: UIViewController {

    private var restoringLabel: UILabel!
    private var cancelButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        initialiseInterface()
    }

    func onCancel() {
        fatalError("onCancel has not been overridden")
    }

    func labelText() -> String {
        fatalError("labelText has not been overridden")
    }

    func showCancelButton() -> Bool {
        fatalError("showCancelButton has not been overridden")
    }

    func updateView() {
        restoringLabel.text = labelText()
        cancelButton.isHidden = !showCancelButton()
    }

    @objc private func buttonAction(sender: UIButton) {
        onCancel()
    }

    /// Should only be called once, to set up the views.
    private func initialiseInterface() {
        if #available(iOS 13.0, *) {
            view.backgroundColor = .systemBackground
        } else {
            view.backgroundColor = .white
        }
        view.translatesAutoresizingMaskIntoConstraints = false

        // Text label to describe the operation
        let labelColor: UIColor
        if #available(iOS 13.0, *) {
            labelColor = .label
        } else {
            labelColor = .black
        }
        restoringLabel = UILabel(font: .preferredFont(forTextStyle: .body), color: labelColor, text: labelText())
        restoringLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(restoringLabel)

        // Spinner which spins for the whole time this view is visible
        let spinnerStyle: UIActivityIndicatorView.Style
        if #available(iOS 13.0, *) {
            spinnerStyle = .large
        } else {
            spinnerStyle = .gray
        }
        let spinner = UIActivityIndicatorView(style: spinnerStyle)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        view.addSubview(spinner)

        // A cancel button; sometimes hidden
        cancelButton = UIButton(type: .system)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitle("Cancel", for: .normal)
        guard let cancelButtonLabel = cancelButton.titleLabel else { preconditionFailure("Missing titleLabel on cancelButton") }
        cancelButtonLabel.font = .preferredFont(forTextStyle: .body)
        cancelButton.addTarget(self, action: #selector(buttonAction(sender:)), for: .touchUpInside)
        cancelButton.isHidden = !showCancelButton()
        view.addSubview(cancelButton)

        // Configure the layout
        NSLayoutConstraint.activate([
            // Horizontally center the views...
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            restoringLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // Vertically center the label, then position the spinner above and button below with some space
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            restoringLabel.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 18),
            cancelButton.topAnchor.constraint(equalTo: restoringLabel.bottomAnchor, constant: 24)
        ])
    }
}
