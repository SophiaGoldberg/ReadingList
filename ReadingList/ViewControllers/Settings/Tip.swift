import SwiftUI
import SwiftyStoreKit
import StoreKit

enum PurchaseState {
    case none
    case pending
    case completed
}

enum TipProduct: String, CaseIterable {
    case small = "smalltip"
    case medium = "mediumtip"
    case large = "largetip"
    case verylarge = "verylargetip"
    case giant = "gianttip"
}

struct Tip: View {
    @State var purchaseState = PurchaseState.none

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            HStack {
                Spacer()
                TipViewContent(purchaseState: $purchaseState)
                    .padding(20)
                    .frame(maxWidth: 600)
                Spacer()
            }
        }
        .navigationBarTitle("Tip")
    }
}

struct TipViewContent: View {
    @Binding var purchaseState: PurchaseState

    var thanksForSupporting: some View {
        Text("Thank you for supporting Reading List!\n❤️")
            .font(.system(.title))
            .fontWeight(.semibold)
            .lineLimit(nil)
    }

    var blurbFromDeveloper: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hi there 👋")
                .font(.title)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
            Text("""
                I'm Andrew, the developer of Reading List. I hope you're enjoying the app!

                Reading List is developed and supported by a single developer. If you value \
                using this app and are feeling generous, you can contribute towards its \
                development if you are able to. If not, that's fine too!

                Thanks for reading,
                Andrew
                """
            ).font(.callout)

            TipPurchasesSection(purchaseState: $purchaseState)
                .frame(maxWidth: .infinity)

            if BuildInfo.thisBuild.type != .appStore {
                Text("""
                    Note: because you are testing a beta version of this app, you won't be charged \
                    for any tips. If you would like to tip, you will need to install the App Store build.
                    """
                ).font(.caption)
                .multilineTextAlignment(.center)
            }
        }
    }

    var body: some View {
        if purchaseState == .completed {
            thanksForSupporting
        } else {
            blurbFromDeveloper
        }
    }
}

struct TipPurchasesSection: View {
    @State var productLoadState = ProductLoadState.loading
    @Binding var purchaseState: PurchaseState

    enum ProductLoadState {
        case loading
        case notAvailable
        case loaded(Set<SKProduct>)
    }

    var body: some View {
        Group {
            switch productLoadState {
            case .notAvailable:
                Text("Could not load tips")
                    .font(.callout)
            case .loading:
                ProgressSpinnerView(isAnimating: .constant(true), style: .medium)
            case .loaded(let products):
                TipPurchases(products, purchaseState: $purchaseState)
            }
        }.onAppear {
            SwiftyStoreKit.retrieveProductsInfo(Set(TipProduct.allCases.map(\.rawValue))) { results in
                guard results.retrievedProducts.count == TipProduct.allCases.count else {
                    productLoadState = .notAvailable
                    return
                }
                productLoadState = .loaded(results.retrievedProducts)
            }
        }
    }
}

struct TipPurchases: View {
    init(_ products: Set<SKProduct>, purchaseState: Binding<PurchaseState>) {
        self.products = products
        self.productsById = products.reduce([:]) { dictionary, product in
            guard let tipProduct = TipProduct(rawValue: product.productIdentifier) else { return dictionary }
            var dictionary = dictionary
            dictionary[tipProduct] = product
            return dictionary
        }
        self._purchaseState = purchaseState
    }

    let products: Set<SKProduct>
    let productsById: [TipProduct: SKProduct]
    @Binding var purchaseState: PurchaseState

    func productView(_ id: TipProduct) -> TipButtonView {
        TipButtonView(productsById[id]!) { purchaseState = $0 }
    }

    private let buttonSpacing: CGFloat = 24

    var body: some View {
        if purchaseState == .pending {
            ProgressSpinnerView(isAnimating: .constant(true), style: .medium)
        } else {
            VStack(alignment: .center, spacing: buttonSpacing) {
                HStack(alignment: .center, spacing: buttonSpacing) {
                    productView(.small)
                    productView(.medium)
                    productView(.large)
                }
                HStack(alignment: .center, spacing: buttonSpacing) {
                    productView(.verylarge)
                    productView(.giant)
                }
            }
        }
    }
}

struct TipButtonView: View {
    let product: SKProduct
    let didPurchase: (PurchaseState) -> Void
    let price: String
    @State var showingFailedPurchaseAlert = false

    init(_ product: SKProduct, didPurchase: @escaping (PurchaseState) -> Void) {
        self.product = product
        let priceFormatter = NumberFormatter()
        priceFormatter.formatterBehavior = .behavior10_4
        priceFormatter.numberStyle = .currency
        priceFormatter.locale = product.priceLocale
        self.price = priceFormatter.string(from: product.price)!
        self.didPurchase = didPurchase
    }

    var body: some View {
        Button(action: {
            // Make the purchase when tapped
            purchase()
        }, label: {
            Text(price)
                .fontWeight(.semibold)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color(.systemBlue))
                .cornerRadius(18)
                .foregroundColor(.white)
        }).alert(isPresented: $showingFailedPurchaseAlert) {
            Alert(
                title: Text("Tip Failed"),
                message: Text("Something went wrong - thanks for trying though!"),
                dismissButton: .default(Text("OK")) {
                    showingFailedPurchaseAlert = false
                }
            )
                }
    }

    func purchase() {
        didPurchase(.pending)
        SwiftyStoreKit.purchaseProduct(product) { result in
            switch result {
            case .success:
                LightweightDataStore.hasEverTipped = true
                didPurchase(.completed)
            case .error(let error):
                didPurchase(.none)
                guard error.code != .paymentCancelled else { return }
                showingFailedPurchaseAlert = true
            }
        }
    }
}

struct Tip_Previews: PreviewProvider {
    static var previews: some View {
        Tip()
    }
}
