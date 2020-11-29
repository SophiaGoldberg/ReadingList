import Foundation
import CloudKit

extension CKRecord {
    func hasCKReference() -> Bool {
        allKeys().contains(where: { self[$0] is CKRecord.Reference })
    }
}
