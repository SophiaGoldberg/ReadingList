import Foundation
import UIKit

extension UIImage {
    convenience init?(ifAvailable systemName: String) {
        if #available(iOS 13.0, *) {
            self.init(systemName: systemName)
        } else {
            return nil
        }
    }
}

enum ImageNames {
    static let startBookPlay = "play"
    static let finishBookCheckmark = "checkmark"
    static let moveUp = "arrow.up"
    static let moveDown = "arrow.down"
    static let moveUpOrDown = "arrow.up.arrow.down"
    static let navigationBarMore = "ellipsis.circle"
    static let scanBarcode = "barcode.viewfinder"
    static let searchOnline = "magnifyingglass"
    static let addBookManually = "doc.text"
    static let updateNotes = "text.bubble"
    static let manageLists = "tray.2"
    static let editBook = "square.and.pencil"
    static let manageLog = "calendar"
    static let delete = "trash.fill"
    static let moreEllipsis = "ellipsis.circle.fill"
}
