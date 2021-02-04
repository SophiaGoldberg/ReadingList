import Foundation
import UIKit

public extension UILabel {
    static func tableCellBadge() -> UILabel {
        let size: CGFloat = 22
        let badge = UILabel(frame: CGRect(x: 0, y: 0, width: size, height: size))
        badge.text = "1"
        badge.layer.cornerRadius = size / 2
        badge.layer.masksToBounds = true
        badge.textAlignment = .center
        badge.textColor = .white
        badge.backgroundColor = .systemRed
        return badge
    }
}
