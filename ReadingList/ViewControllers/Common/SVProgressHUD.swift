import Foundation
import SVProgressHUD

extension SVProgressHUD {

    static func setDefaults() {
        // Prepare the progress display style. Switched to dark in 1.4 due to a bug in the display of light style
        SVProgressHUD.setDefaultStyle(.dark)
        SVProgressHUD.setDefaultAnimationType(.native)
        SVProgressHUD.setDefaultMaskType(.clear)
        SVProgressHUD.setMinimumDismissTimeInterval(1.5)
        SVProgressHUD.setHapticsEnabled(true)
    }
}
