import Foundation
import CloudKit

extension CKRecordValueProtocol {
    var asInt32: Int32? {
        guard let int64 = self as? Int64 else { return nil }
        return Int32(clamping: int64)
    }
    
    var asInt16: Int16? {
        guard let int64 = self as? Int64 else { return nil }
        return Int16(clamping: int64)
    }
}
