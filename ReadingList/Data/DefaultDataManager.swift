import Foundation
import CoreData

class DefaultDataManager {
    func createWishListIfNeeded(viewContext: NSManagedObjectContext) {
        let fetchRequest = List.fetchRequest()
        fetchRequest.resultType = .countResultType
        fetchRequest.predicate = NSPredicate(format: "%K == 0 AND %K == %@", #keyPath(List.custom), #keyPath(List.name), StockList.wishList.rawValue)
        fetchRequest.fetchLimit = 1
        let result = try! viewContext.count(for: fetchRequest)
        if result > 0 { return }

        let childContext = viewContext.childContext()
        childContext.performAndSave {
            let list = List(context: childContext)
            list.setValue(false, forKey: #keyPath(List.custom))
            list.name = StockList.wishList.rawValue
            list.sort = 0
        }
    }
}
