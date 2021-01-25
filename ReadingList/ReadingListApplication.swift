import UIKit

class ReadingListApplication: UIApplication {
    override var preferredContentSizeCategory: UIContentSizeCategory {
        // Allow an override of the content size
        GeneralSettings.textSizeOverride ?? super.preferredContentSizeCategory
    }

    var systemPreferredContentSizeCategory: UIContentSizeCategory {
        // Expose the super class variable, to see the system setting
        super.preferredContentSizeCategory
    }
}

extension UIApplication {
    static let readingListApplication = UIApplication.shared as! ReadingListApplication
}
