import Foundation
import UIKit

/// A generalisation of the purposes of UIMenu and UIAlertController in response to button taps.
/// We typically want to show a UIMenu when a button tap requires a further choice, but this is only available on iOS 14.
/// On 13 and below, we use a UIAlertController presented as an action sheet. To avoid having to duplicate the text labels and
/// handler functions, we define one AlertOrMenu entity which can build both an action sheet and also a menu.
public struct AlertOrMenu {
    let title: String?
    let items: [Item]

    public init(title: String?, items: [Item]) {
        self.title = title
        self.items = items
    }

    public struct Item {
        let title: String
        let image: UIImage?
        let destructive: Bool
        let handler: (() -> Void)?
        let childAlertOrMenu: AlertOrMenu?
        let presentSecondaryAlert: ((UIAlertController) -> Void)?

        public init(title: String, image: UIImage? = nil, destructive: Bool = false, handler: @escaping () -> Void) {
            self.title = title
            self.image = image
            self.destructive = destructive
            self.handler = handler
            self.childAlertOrMenu = nil
            self.presentSecondaryAlert = nil
        }

        public init(title: String, image: UIImage? = nil, destructive: Bool = false, childAlertOrMenu: AlertOrMenu, presentSecondartAlert: @escaping (UIAlertController) -> Void) {
            self.title = title
            self.image = image
            self.destructive = destructive
            self.handler = nil
            self.childAlertOrMenu = childAlertOrMenu
            self.presentSecondaryAlert = presentSecondartAlert
        }

        func alertAction() -> UIAlertAction {
            UIAlertAction(title: title, style: destructive ? .destructive : .default) { _ in
                if let childAlert = childAlertOrMenu, let presentSecondaryAlert = presentSecondaryAlert {
                    presentSecondaryAlert(childAlert.actionSheet())
                } else if let handler = handler {
                    handler()
                } else {
                    preconditionFailure("Neither a child alert nor a handler was provided")
                }
            }
        }

        @available(iOS 14.0, *)
        func menuElement() -> UIMenuElement {
            if let childMenu = childAlertOrMenu {
                return UIMenu(title: title, image: image, options: destructive ? .destructive : [], children: childMenu.menu().children)
            } else if let handler = handler {
                return UIAction(title: title, image: image, attributes: destructive ? .destructive : []) { _ in
                    handler()
                }
            } else {
                preconditionFailure("Neither a child menu nor a handler was provided")
            }
        }
    }

    public func actionSheet() -> UIAlertController {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        alert.addActions(items.map { $0.alertAction() })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        return alert
    }

    @available(iOS 14.0, *)
    public func menu() -> UIMenu {
        return UIMenu(title: title ?? "", children: items.map { $0.menuElement() })
    }
}
