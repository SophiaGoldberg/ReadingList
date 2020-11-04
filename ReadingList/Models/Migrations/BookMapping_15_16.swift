import Foundation
import CoreData

class BookMapping_15_16: NSEntityMigrationPolicy { //swiftlint:disable:this type_name

    @objc func hasSubtitle(forSubtitle subtitle: String?) -> NSNumber {
        let hasSubtitle = subtitle != nil
        // Bools must be returned as NSNumber, it seems. Migration crashes otherwise
        return NSNumber(value: hasSubtitle)
    }
}
