import Foundation
import UIKit
import AVFoundation

public extension UINib {
    convenience init<T>(_ class: T.Type) where T: UIView {
        self.init(nibName: String(describing: T.self), bundle: nil)
    }

    static func instantiate<T>(_ class: T.Type) -> T where T: UIView {
        return UINib(T.self).instantiate(withOwner: nil, options: nil)[0] as! T
    }
}

public extension UIView {
    @IBInspectable var maskedCornerRadius: CGFloat {
        get {
            return layer.cornerRadius
        }
        set {
            layer.cornerRadius = newValue
            layer.masksToBounds = newValue > 0
        }
    }

    convenience init(backgroundColor: UIColor) {
        self.init()
        self.backgroundColor = backgroundColor
    }

    var nextSibling: UIView? {
        guard let views = superview?.subviews else { return nil }
        let thisIndex = views.firstIndex(of: self)!
        guard thisIndex + 1 < views.count else { return nil }
        return views[thisIndex + 1]
    }

    var siblings: [UIView] {
        guard let views = superview?.subviews else { return [] }
        return views.filter { $0 != self }
    }

    func removeAllSubviews() {
        for view in subviews {
            view.removeFromSuperview()
        }
    }

    func pin(to other: UIView, multiplier: CGFloat = 1.0, attributes: NSLayoutConstraint.Attribute...) {
        for attribute in attributes {
            NSLayoutConstraint(item: self, attribute: attribute, relatedBy: .equal, toItem: other,
                               attribute: attribute, multiplier: multiplier, constant: 0.0).isActive = true
        }
    }

    func fix(attribute: NSLayoutConstraint.Attribute, to constant: CGFloat) {
        NSLayoutConstraint(item: self, attribute: attribute, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute,
                           multiplier: 1.0, constant: constant).isActive = true

    }
}

public extension UIStoryboard {
    func instantiateRoot(withStyle style: UIModalPresentationStyle? = nil) -> UIViewController {
        let viewController = self.instantiateInitialViewController()!
        if let style = style {
            viewController.modalPresentationStyle = style
        }
        return viewController
    }

    func rootAsFormSheet() -> UIViewController {
        return instantiateRoot(withStyle: .formSheet)
    }
}

public extension UISwipeActionsConfiguration {
    convenience init(performFirstActionWithFullSwipe: Bool, actions: [UIContextualAction]) {
        self.init(actions: actions)
        self.performsFirstActionWithFullSwipe = performFirstActionWithFullSwipe
    }
}

public extension UIContextualAction {
    convenience init(style: UIContextualAction.Style, title: String?, image: UIImage?,
                     backgroundColor: UIColor? = nil, handler: @escaping UIContextualAction.Handler) {
        self.init(style: style, title: title, handler: handler)
        self.image = image
        if let backgroundColor = backgroundColor {
            // Don't set the background color to nil just because it was not provided
            self.backgroundColor = backgroundColor
        }
    }
}

public extension UISearchController {
    convenience init(filterPlaceholderText: String) {
        self.init(searchResultsController: nil)
        obscuresBackgroundDuringPresentation = false
        searchBar.returnKeyType = .done
        searchBar.placeholder = filterPlaceholderText
        searchBar.searchBarStyle = .default
    }

    var hasActiveSearchTerms: Bool {
        return self.isActive && self.searchBar.text?.isEmpty == false
    }
}

public extension UIViewController {
    func inNavigationController(modalPresentationStyle: UIModalPresentationStyle = .formSheet) -> UINavigationController {
        let nav = UINavigationController(rootViewController: self)
        nav.modalPresentationStyle = modalPresentationStyle
        return nav
    }
}

public extension UISplitViewController {

    var masterNavigationController: UINavigationController {
        return viewControllers[0] as! UINavigationController
    }

    var detailNavigationController: UINavigationController? {
        return viewControllers[safe: 1] as? UINavigationController
    }

    var masterNavigationRoot: UIViewController {
        return masterNavigationController.viewControllers.first!
    }

    var detailIsPresented: Bool {
        return isSplit || masterNavigationController.viewControllers.count >= 2
    }

    var isSplit: Bool {
        return viewControllers.count >= 2
    }

    var displayedDetailViewController: UIViewController? {
        // If the master and detail are separate, the detail will be the second item in viewControllers
        if isSplit, let detailNavController = detailNavigationController {
            return detailNavController.viewControllers.first
        }

        // Otherwise, navigate to where the Details view controller should be (if it is displayed)
        if masterNavigationController.viewControllers.count >= 2,
            let previewNavController = masterNavigationController.viewControllers[1] as? UINavigationController {
            return previewNavController.viewControllers.first
        }

        // The controller is not present
        return nil
    }

    func popDetailOrMasterToRoot(animated: Bool) {
        if let detailNav = detailNavigationController {
            detailNav.popToRootViewController(animated: animated)
        } else {
            masterNavigationController.popToRootViewController(animated: animated)
        }
    }
}

public extension UINavigationController {
    func dismissAndPopToRoot() {
        dismiss(animated: false)
        popToRootViewController(animated: false)
    }
}

public extension UIPopoverPresentationController {

    func setSourceCell(_ cell: UITableViewCell, inTableView tableView: UITableView, arrowDirections: UIPopoverArrowDirection = .any) {
        self.sourceRect = cell.frame
        self.sourceView = tableView
        self.permittedArrowDirections = arrowDirections
    }

    func setSourceCell(atIndexPath indexPath: IndexPath, inTable tableView: UITableView, arrowDirections: UIPopoverArrowDirection = .any) {
        let cell = tableView.cellForRow(at: indexPath)!
        setSourceCell(cell, inTableView: tableView, arrowDirections: arrowDirections)
    }

    func setButton(_ button: UIButton) {
        sourceView = button
        sourceRect = button.bounds
    }
}

public extension UITabBarItem {

    func configure(tag: Int, title: String, image: UIImage, selectedImage: UIImage) {
        self.tag = tag
        self.image = image
        self.selectedImage = selectedImage
        self.title = title
    }
}

public extension UIActivity.ActivityType {
    static var documentUnsuitableTypes: [UIActivity.ActivityType] {
        return [.addToReadingList, .assignToContact, .saveToCameraRoll, .postToFlickr, .postToVimeo,
                .postToTencentWeibo, .postToTwitter, .postToFacebook, .openInIBooks, .markupAsPDF]
    }
}

public extension UISearchBar {
    var isEnabled: Bool {
        get {
            return isUserInteractionEnabled
        }
        set {
            isUserInteractionEnabled = newValue
            alpha = newValue ? 1.0 : 0.5
        }
    }
}

public extension UIBarButtonItem {
    func setHidden(_ hidden: Bool) {
        isEnabled = !hidden
        tintColor = hidden ? .clear : nil
    }
}

public extension UITableViewController {
    @objc func toggleEditingAnimated() {
        setEditing(!isEditing, animated: true)
    }
}

public extension UITableViewRowAction {
    convenience init(style: UITableViewRowAction.Style, title: String?, color: UIColor, handler: @escaping (UITableViewRowAction, IndexPath) -> Void) {
        self.init(style: style, title: title, handler: handler)
        self.backgroundColor = color
    }
}

public extension UILabel {
    convenience init(font: UIFont, color: UIColor, text: String) {
        self.init()
        self.font = font
        self.textColor = color
        self.text = text
    }

    var isTruncated: Bool {
        guard let labelText = text else { return false }
        let labelTextSize = (labelText as NSString).boundingRect(
            with: CGSize(width: frame.size.width, height: .greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin,
            attributes: [.font: font!],
            context: nil).size
        return labelTextSize.height > bounds.size.height
    }

    func setTextOrHide(_ text: String?) {
        self.text = text
        self.isHidden = text == nil
    }

    @IBInspectable var dynamicFontSize: String? {
        get {
            return nil
        }
        set {
            guard let newValue = newValue else { return }
            font = font.scaled(forTextStyle: UIFont.TextStyle(rawValue: "UICTFontTextStyle\(newValue)"))
        }
    }

    func scaleFontBy(_ factor: CGFloat) {
        font = font.withSize(font.pointSize * factor)
    }
}

public extension UIFont {
    func scaled(forTextStyle textStyle: UIFont.TextStyle) -> UIFont {
        let fontSize = UIFont.preferredFont(forTextStyle: textStyle).pointSize
        return self.withSize(fontSize)
    }

    class func rounded(ofSize size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let systemFont = UIFont.systemFont(ofSize: size, weight: weight)

        guard let descriptor = systemFont.fontDescriptor.withDesign(.rounded) else { return systemFont }
        return UIFont(descriptor: descriptor, size: size)
    }
}

public extension UIImage {
    convenience init?(optionalData: Data?) {
        if let data = optionalData {
            self.init(data: data)
        } else {
            return nil
        }
    }

    /**
     Returns the UIImage with the provided system name, at large scale and the provided weight.
     */
    convenience init?(largeSystemImageNamed name: String) {
        self.init(systemName: name, withConfiguration: UIImage.SymbolConfiguration(scale: .large))
    }
}

public extension NSAttributedString {
    @objc convenience init(_ string: String, font: UIFont) {
        self.init(string: string, attributes: [.font: font])
    }

    func mutable() -> NSMutableAttributedString {
        return NSMutableAttributedString(attributedString: self)
    }
}

public extension NSMutableAttributedString {
    @objc convenience init(_ string: String, font: UIFont) {
        self.init(string: string, attributes: [.font: font])
    }

    @discardableResult func appending(_ text: String, font: UIFont) -> NSMutableAttributedString {
        self.append(NSAttributedString(text, font: font))
        return self
    }

    @discardableResult func attributedWithColor(_ color: UIColor) -> NSMutableAttributedString {
        self.addAttribute(.foregroundColor, value: color, range: NSRange(location: 0, length: self.length))
        return self
    }
}

public extension UITableView {
    func advisedFetchBatchSize(forTypicalCell cell: UITableViewCell) -> Int {
        return Int((self.frame.height / cell.frame.height) * 1.3)
    }

    func register<Cell: UITableViewCell>(_ type: Cell.Type) {
        register(UINib(type), forCellReuseIdentifier: String(describing: type))
    }

    func dequeue<Cell: UITableViewCell>(_ type: Cell.Type, for indexPath: IndexPath) -> Cell {
        guard let cell = dequeueReusableCell(withIdentifier: String(describing: type), for: indexPath) as? Cell else {
            preconditionFailure()
        }
        return cell
    }

    func register<HeaderFooter: UITableViewHeaderFooterView>(_ type: HeaderFooter.Type) {
        register(UINib(type), forHeaderFooterViewReuseIdentifier: String(describing: type))
    }

    func dequeue<HeaderFooter: UITableViewHeaderFooterView>(_ type: HeaderFooter.Type) -> HeaderFooter {
        guard let header = dequeueReusableHeaderFooterView(withIdentifier: String(describing: type)) as? HeaderFooter else {
            preconditionFailure()
        }
        return header
    }
}

public extension UITableViewCell {
    var isEnabled: Bool {
        get {
            return isUserInteractionEnabled && textLabel?.isEnabled != false && detailTextLabel?.isEnabled != false
        }
        set {
            isUserInteractionEnabled = newValue
            textLabel?.isEnabled = newValue
            detailTextLabel?.isEnabled = newValue
        }
    }

    func setSelectedBackgroundColor(_ color: UIColor) {
        guard selectionStyle != .none else { return }
        selectedBackgroundView = UIView(backgroundColor: color)
    }
}

public extension UIDeviceOrientation {
    var videoOrientation: AVCaptureVideoOrientation? {
        switch self {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeRight
        case .landscapeRight: return .landscapeLeft
        default: return nil
        }
    }
}

public extension UIDevice {

    // From https://stackoverflow.com/a/26962452/5513562
    var modelIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        return machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
    }

    var modelName: String {
        let identifier = modelIdentifier
        switch identifier {
        case "iPod7,1":                                 return "iPod Touch 6"
        case "iPod9,1":                                 return "iPod Touch 7"
        case "iPhone6,1", "iPhone6,2":                  return "iPhone 5s"
        case "iPhone7,2":                               return "iPhone 6"
        case "iPhone7,1":                               return "iPhone 6 Plus"
        case "iPhone8,1":                               return "iPhone 6s"
        case "iPhone8,2":                               return "iPhone 6s Plus"
        case "iPhone9,1", "iPhone9,3":                  return "iPhone 7"
        case "iPhone9,2", "iPhone9,4":                  return "iPhone 7 Plus"
        case "iPhone8,4":                               return "iPhone SE"
        case "iPhone10,1", "iPhone10,4":                return "iPhone 8"
        case "iPhone10,2", "iPhone10,5":                return "iPhone 8 Plus"
        case "iPhone10,3", "iPhone10,6":                return "iPhone X"
        case "iPhone11,2":                              return "iPhone XS"
        case "iPhone11,4", "iPhone11,6":                return "iPhone XS Max"
        case "iPhone11,8":                              return "iPhone XR"
        case "iPhone12,1":                              return "iPhone 11"
        case "iPhone12,3":                              return "iPhone 11 Pro"
        case "iPhone12,5":                              return "iPhone 11 Pro Max"
        case "iPhone12,8":                              return "iPhone SE (2nd Generation)"
        case "iPhone13,1":                              return "iPhone 12 Mini"
        case "iPhone13,2":                              return "iPhone 12"
        case "iPhone13,3":                              return "iPhone 12 Pro"
        case "iPhone13,4":                              return "iPhone 12 Pro Max"
        case "iPad4,1", "iPad4,2", "iPad4,3":           return "iPad Air"
        case "iPad5,3", "iPad5,4":                      return "iPad Air 2"
        case "iPad11,3", "iPad11,4":                    return "iPad Air 3"
        case "iPad6,11", "iPad6,12":                    return "iPad 5"
        case "iPad7,5", "iPad7,6":                      return "iPad 6"
        case "iPad4,4", "iPad4,5", "iPad4,6":           return "iPad Mini 2"
        case "iPad4,7", "iPad4,8", "iPad4,9":           return "iPad Mini 3"
        case "iPad5,1", "iPad5,2":                      return "iPad Mini 4"
        case "iPad11,1", "iPad11,2":                    return "iPad Mini 5"
        case "iPad6,3", "iPad6,4":                      return "iPad Pro 9.7 Inch"
        case "iPad6,7", "iPad6,8":                      return "iPad Pro 12.9 Inch"
        case "iPad7,1", "iPad7,2":                      return "iPad Pro 12.9 Inch (2nd Generation)"
        case "iPad7,3", "iPad7,4":                      return "iPad Pro 10.5 Inch"
        case "iPad8,1", "iPad8,2", "iPad8,3", "iPad8,4": return "iPad Pro 11 Inch"
        case "iPad8,9", "iPad8,10":                      return "iPad Pro 11 Inch (2nd Generation)"
        case "iPad8,5", "iPad8,6", "iPad8,7", "iPad8,8": return "iPad Pro 12.9 Inch (3rd Generation)"
        case "iPad8,11", "iPad8,12":                    return "iPad Pro 12.9 Inch (4th Generation)"
        default:                                        return identifier
        }
    }
}

public extension UIAlertController {
    func addActions<S>(_ actions: S) where S: Sequence, S.Element == UIAlertAction {
        for action in actions {
            addAction(action)
        }
    }
}
