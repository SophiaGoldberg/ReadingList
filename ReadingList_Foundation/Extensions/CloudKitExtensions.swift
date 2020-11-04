import Foundation
import CloudKit

public extension CKRecord {
    convenience init?(systemFieldsData: Data) {
        let coder = NSKeyedUnarchiver(forReadingWith: systemFieldsData)
        coder.requiresSecureCoding = true
        self.init(coder: coder)
        coder.finishDecoding()
    }

    func encodedSystemFields() -> Data {
        let data = NSMutableData()
        let coder = NSKeyedArchiver(forWritingWith: data)
        coder.requiresSecureCoding = true
        encodeSystemFields(with: coder)
        coder.finishEncoding()
        return data as Data
    }

    /**
     Note that if a CKAsset is provided, and the asset's file URL does not exist on this device, will return false
     (unless they both don't exist).
    */
    static func valuesAreEqual(left: CKRecordValue?, right: CKRecordValue?) -> Bool {
        if left == nil && right == nil { return true }
        guard let left = left, let right = right else { return false }

        if let leftString = left as? NSString {
            return leftString == right as? NSString
        }
        if let leftNumber = left as? NSNumber {
            return leftNumber == right as? NSNumber
        }
        if let leftDate = left as? NSDate {
            return leftDate == right as? NSDate
        }
        if let leftData = left as? NSData {
            return leftData == right as? NSData
        }
        if let leftArray = left as? NSArray {
            return leftArray == right as? NSArray
        }
        if let leftAsset = left as? CKAsset {
            guard let rightAsset = right as? CKAsset else { return false }
            guard let leftAssetUrl = leftAsset.fileURL, let rightAssetUrl = rightAsset.fileURL else { return false }
            guard FileManager.default.fileExists(atPath: leftAssetUrl.path)
                && FileManager.default.fileExists(atPath: rightAssetUrl.path) else { return false }
            return FileManager.default.contentsEqual(atPath: leftAssetUrl.path, andPath: rightAssetUrl.path)
        }

        fatalError("Unexpected data type in CKRecordValue comparison.")
    }
}
