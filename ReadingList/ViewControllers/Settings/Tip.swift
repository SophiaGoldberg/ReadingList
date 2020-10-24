import SwiftyStoreKit
import StoreKit

final class Tip: UIViewController, ThemeableViewController {
    let tipProductIds = ["smalltip", "mediumtip", "largetip", "verylargetip", "gianttip"]
    var tipProducts: Set<SKProduct>?

    @IBOutlet private weak var explanationLabel: UILabel!
    @IBOutlet private var tipButtons: [UIButton]!

    override func viewDidLoad() {
        super.viewDidLoad()
        SwiftyStoreKit.retrieveProductsInfo(Set(tipProductIds)) { [weak self] results in
            guard let viewController = self else { return }
            guard results.retrievedProducts.count == viewController.tipProductIds.count else {
                viewController.tipButtons[1].isEnabled = false
                viewController.tipButtons[1].setTitle("Not available", for: .normal)
                return
            }
            viewController.tipProducts = results.retrievedProducts
            viewController.displayTipPrices()
        }

        if BuildInfo.thisBuild.type != .appStore {
            explanationLabel.text = explanationLabel.text! + "\n\nNote: because you are testing a beta version of this app, you won't be able to leave any tips."
        }

        monitorThemeSetting()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        view.setNeedsLayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let scrollView = view.subviews[0] as! UIScrollView
        let contentView = scrollView.subviews[0]

        let top = (scrollView.bounds.height - contentView.bounds.height) / 2
        scrollView.contentInset = UIEdgeInsets(top: top < 0 ? 0 : top, left: 0, bottom: 0, right: 0)
    }

    func displayTipPrices() {
        guard let tipProducts = tipProducts else {
            assertionFailure("TipProducts was unexpectedly nil"); return
        }
        guard let firstProduct = tipProducts.first else {
            assertionFailure("TipProducts was unexpectedly empty"); return
        }

        let priceFormatter = NumberFormatter()
        priceFormatter.formatterBehavior = .behavior10_4
        priceFormatter.numberStyle = .currency
        priceFormatter.locale = firstProduct.priceLocale

        for (index, productId) in tipProductIds.enumerated() {
            guard let product = tipProducts.first(where: { $0.productIdentifier == productId }) else {
                assertionFailure("No product with ID \(productId)"); continue
            }
            guard let priceString = priceFormatter.string(from: product.price) else {
                assertionFailure("Could not format price string \(product.price)"); continue
            }

            let button = tipButtons[index]
            button.isHidden = false
            button.isEnabled = true
            button.setTitle(priceString, for: .normal)
        }
    }

    @IBAction private func tipPressed(_ sender: UIButton) {
        guard let tipProducts = tipProducts else { return }

        let senderIndex = tipButtons.firstIndex(of: sender)!
        let productId = tipProductIds[senderIndex]
        let product = tipProducts.first { $0.productIdentifier == productId }!

        SwiftyStoreKit.purchaseProduct(product) { [weak self] result in
            switch result {
            case .success:
                guard let viewController = self else { return }
                viewController.explanationLabel.text = "Thanks for supporting Reading List! ❤️"
                viewController.tipButtons.forEach { $0.isHidden = true }
                LightweightDataStore.hasEverTipped = true

            case .error(let error):
                guard error.code != .paymentCancelled else { return }

                let alert = UIAlertController(title: "Tip Failed", message: "Something went wrong - thanks for trying though!", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                (UIApplication.shared.delegate as! AppDelegate).window?.rootViewController?.present(alert, animated: true)
            }
        }
    }

    func initialise(withTheme theme: Theme) {
        if #available(iOS 13.0, *) { return }
        view.backgroundColor = theme.viewBackgroundColor
        explanationLabel.textColor = theme.titleTextColor
    }
}
