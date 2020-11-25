import Foundation
import CloudKit

protocol CKRecordRepresentable {
    static var ckRecordType: String { get }
    var isDeleted: Bool { get }
    func recordForInsert(into zone: CKRecordZone.ID) -> CKRecord?
    func recordForUpdate(changedCoreDataKeys: [String]) -> CKRecord?
}
