import Foundation
import UIKit

public class NoCancelButtonSearchController: UISearchController {
    let noCancelButtonSearchBar = NoCancelButtonSearchBar()
    public override var searchBar: UISearchBar { return noCancelButtonSearchBar }
}

class NoCancelButtonSearchBar: UISearchBar {
    override func setShowsCancelButton(_ showsCancelButton: Bool, animated: Bool) {
        // do nothing
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        super.setShowsCancelButton(false, animated: false)
    }
}
