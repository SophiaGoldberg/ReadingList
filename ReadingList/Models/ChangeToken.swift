import Foundation
import CoreData
import CloudKit

@objc(ChangeToken)
public class ChangeToken: NSManagedObject {
    @NSManaged private(set) var ownerName: String
    @NSManaged private(set) var zoneName: String
    @NSManaged private var changeTokenData: Data

    var changeToken: CKServerChangeToken {
        get { return try! NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: changeTokenData)! }
        set { changeTokenData = try! NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: true) }
    }

    convenience init(context: NSManagedObjectContext, zoneID: CKRecordZone.ID) {
        self.init(context: context)
        self.ownerName = zoneID.ownerName
        self.zoneName = zoneID.zoneName
    }

    static func get(fromContext context: NSManagedObjectContext, for zoneID: CKRecordZone.ID) -> ChangeToken? {
        let fetchRequest = NSManagedObject.fetchRequest(ChangeToken.self, limit: 1, batch: 1)
        fetchRequest.predicate = NSPredicate(format: "%K == %@ AND %K == %@",
                                             #keyPath(ChangeToken.zoneName), zoneID.zoneName,
                                             #keyPath(ChangeToken.ownerName), zoneID.ownerName)
        fetchRequest.returnsObjectsAsFaults = false
        return (try! context.fetch(fetchRequest)).first
    }
}
