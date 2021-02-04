import Foundation
import UIKit

class DeleteAll: FullScreenProgress {
    override func labelText() -> String {
        return "Deleting..."
    }

    override func showCancelButton() -> Bool {
        return false
    }
}
