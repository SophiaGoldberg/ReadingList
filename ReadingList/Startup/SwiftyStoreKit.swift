import Foundation
import SwiftyStoreKit

extension SwiftyStoreKit {
    static func completeTransactions() {
        // Apple recommends to register a transaction observer as soon as the app starts.
        SwiftyStoreKit.completeTransactions(atomically: true) { purchases in
            purchases.filter {
                ($0.transaction.transactionState == .purchased || $0.transaction.transactionState == .restored) && $0.needsFinishTransaction
            }.forEach {
                SwiftyStoreKit.finishTransaction($0.transaction)
            }
        }
    }
}
