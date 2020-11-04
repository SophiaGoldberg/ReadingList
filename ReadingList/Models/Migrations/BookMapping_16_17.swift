import Foundation
import CoreData

class BookMapping_16_17: NSEntityMigrationPolicy { //swiftlint:disable:this type_name

    //FUNCTION($entityPolicy, "destinationListItemsForSourceList:manager:" , $source.list, $manager)
    @objc func destinationListItems(forSourceList list: NSManagedObject, manager: NSMigrationManager) -> [NSManagedObject] {
        guard let books = list.value(forKey: "books") else { return [] }
        guard let booksSet = books as? NSOrderedSet else { preconditionFailure("Object at key 'books' was not an NSOrderedSet") }
        let sourceBooks = booksSet.array.map { $0 as! NSManagedObject }

        // I am pretty sure that this returns the instances in the same order they were provided. It doesn't document it as such,
        // but if it didn't then we'd be losing ordering every time we do a mirgation, since the default mapping model uses
        // this for ordered relationships.
        let migratedBooks = manager.destinationInstances(forEntityMappingName: "BookToBook", sourceInstances: sourceBooks)

        let migratedList = manager.destinationInstances(forEntityMappingName: "ListToList", sourceInstances: [list]).first!
        return migratedBooks.enumerated().map { index, migratedBook in
            let listBook = NSEntityDescription.insertNewObject(forEntityName: "ListItem", into: manager.destinationContext)
            listBook.setValue(index, forKey: "sort")
            listBook.setValue(migratedBook, forKey: "book")
            listBook.setValue(migratedList, forKey: "list")
            return listBook
        }
    }
}
