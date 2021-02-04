import UIKit

extension UIViewController {
    func inNavigationController(modalPresentationStyle: UIModalPresentationStyle = .formSheet) -> UINavigationController {
        let nav = UINavigationController(rootViewController: self)
        nav.modalPresentationStyle = modalPresentationStyle
        return nav
    }
}
