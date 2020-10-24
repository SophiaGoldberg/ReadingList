import Foundation
import CoreData
import UIKit
import os.log

public extension NSManagedObject {
    /// Can be useful when requiring a sort keyPath which points to a property which is the same for all objects.
    @objc var constantEmptyString: String {
        return ""
    }

    func delete() {
        guard let context = managedObjectContext else {
            assertionFailure("Attempted to delete an object which was not in a context"); return
        }
        context.delete(self)
    }

    func safelySetPrimitiveValue(_ value: Any?, forKey key: String) {
        willChangeValue(forKey: key)
        setPrimitiveValue(value, forKey: key)
        didChangeValue(forKey: key)
    }

    func safelyGetPrimitiveValue(forKey key: String) -> Any? {
        willAccessValue(forKey: key)
        let value = primitiveValue(forKey: key)
        didAccessValue(forKey: key)
        return value
    }

    static func fetchRequest<T: NSManagedObject>(_ type: T.Type, limit: Int? = nil, batch: Int? = nil) -> NSFetchRequest<T> {
        // Apple bug: the following lines do not work when run from a test target
        // let fetchRequest = T.fetchRequest() as! NSFetchRequest<T>
        // let fetchRequest = NSFetchRequest<T>(entityName: type.entity().managedObjectClassName)
        let fetchRequest = NSFetchRequest<T>(entityName: String(describing: type))
        if let limit = limit { fetchRequest.fetchLimit = limit }
        if let batch = batch { fetchRequest.fetchBatchSize = batch }
        return fetchRequest
    }

    func isValidForUpdate() -> Bool {
        do {
            try self.validateForUpdate()
            return true
        } catch {
            return false
        }
    }

    func inContext(_ context: NSManagedObjectContext) -> Self {
        return context.object(with: objectID) as! Self
    }
}

public extension NSManagedObjectContext {

    /**
     With a valid URL representation of a Managed Object ID, returns the managed object.
    */
    func object(withID id: URL) -> NSManagedObject {
        return object(with: persistentStoreCoordinator!.managedObjectID(forURIRepresentation: id)!)
    }

    /**
     Gets the maximum value of the item at the specified keypath.
     */
    func getMaximum<Entity, SortValue>(sortValueKeyPath keyPath: KeyPath<Entity, SortValue>) -> SortValue?
        where SortValue: Comparable, Entity: NSManagedObject {
        let fetchRequest = NSManagedObject.fetchRequest(Entity.self, limit: 1)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath, ascending: false)]
        fetchRequest.returnsObjectsAsFaults = false
        let result = try! fetch(fetchRequest)
        if let firstResult = result.first {
            return firstResult[keyPath: keyPath]
        } else {
            return nil
        }
    }
}

public extension NSPersistentStoreCoordinator {

    /**
     Attempts to destory and then delete the store at the specified URL. If an error occurs, prints the error; does not rethrow.
     */
    func destroyAndDeleteStore(at url: URL) {
        do {
            try destroyPersistentStore(at: url, ofType: NSSQLiteStoreType, options: nil)
            try FileManager.default.removeItem(at: url)
            try FileManager.default.removeItem(at: URL(fileURLWithPath: url.path.appending("-shm")))
            try FileManager.default.removeItem(at: URL(fileURLWithPath: url.path.appending("-wal")))
        } catch {
            os_log("Failed to destroy or delete persistent store at %{public}s: %{public}s", type: .error, url.path, error.localizedDescription)
        }
    }
}

public extension NSEntityMigrationPolicy {

    func copyValue(oldObject: NSManagedObject, newObject: NSManagedObject, key: String) {
        newObject.setValue(oldObject.value(forKey: key), forKey: key)
    }

    func copyValues(oldObject: NSManagedObject, newObject: NSManagedObject, keys: String...) {
        for key in keys {
            copyValue(oldObject: oldObject, newObject: newObject, key: key)
        }
    }
}

@available(iOS 13.0, *)
public extension NSFetchedResultsController {
    /**
     Generates a `NSDiffableDataSourceSnapshot` where the section identifiers are the fetched section names, and the item identifiers are the fetched object's `NSManagedObjectID`.
     */
    @objc func snapshot() -> NSDiffableDataSourceSnapshot<String, NSManagedObjectID> {
        return NSDiffableDataSourceSnapshot<String, NSManagedObjectID>(self as! NSFetchedResultsController<NSFetchRequestResult>)
    }
}

@available(iOS 13.0, *)
public extension NSDiffableDataSourceSnapshot {
    mutating func loadSectionChanges(_ change: CollectionDifference<SectionIdentifierType>.Change) {
        switch change {
        case .insert(offset: sectionIdentifiers.count, let element, _):
            // If the offset is such that it places this item at the end of collection, append it
            appendSections([element])
        case .insert(let offset, let element, _):
            // Otherwise, insert the new item before the item which is currently at the desired position
            let existingSection = sectionIdentifiers[offset]
            insertSections([element], beforeSection: existingSection)
        case .remove(_, let element, _):
            deleteSections([element])
        }
    }

    mutating func loadItemChanges(_ change: CollectionDifference<ItemIdentifierType>.Change, inSection section: SectionIdentifierType) {
        switch change {
        case .insert(itemIdentifiers(inSection: section).count, let element, _):
            // If the offset is such that it places this item at the end of collection, append it
            appendItems([element], toSection: section)
        case .insert(let offset, let element, _):
            // Otherwise, insert the new item before the item which is currently at the desired position
            let existingItem = itemIdentifiers(inSection: section)[offset]
            insertItems([element], beforeItem: existingItem)
        case .remove(_, let element, _):
            deleteItems([element])
        }
    }

    /**
     Appends the sections and items from the provided snapshot to this snapshot.
     */
    mutating func append(_ snapshot: NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType>) {
        appendSections(snapshot.sectionIdentifiers)
        for section in snapshot.sectionIdentifiers {
            appendItems(snapshot.itemIdentifiers(inSection: section), toSection: section)
        }
    }

    /**
    Appends the sections and items from the provided snapshots to this snapshot, in order.
    */
    mutating func append(_ snapshots: [NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType>]) {
        for snapshot in snapshots {
            append(snapshot)
        }
    }

    /**
     Calls `reloadItems` with the supplied items filtered to only include those which are present in the current snapshot.
     */
    mutating func reloadValidItems(_ changedObjects: [ItemIdentifierType]) {
        reloadItems(changedObjects.filter { self.itemIdentifiers.contains($0) })
    }
}

@available(iOS 13.0, *)
public extension NSDiffableDataSourceSnapshot where ItemIdentifierType == NSManagedObjectID {
    /**
    Constructs a `NSDiffableDataSourceSnapshot` where the section identifiers are the fetched section names with the provided mapping function applied, and the
     item identifiers are the fetched object's `NSManagedObjectID`.
    */
    init<FetchedResultType>(_ controller: NSFetchedResultsController<FetchedResultType>, mappingSections: (String) -> SectionIdentifierType) {
        self.init()
        guard let sections = controller.sections else { preconditionFailure("Controller sections info was nil: a fetch must be performed before generating a snapshot") }

        for section in sections {
            let mappedSection = mappingSections(section.name)
            guard let objects = section.objects else { preconditionFailure() }
            appendSections([mappedSection])
            let objectIds = objects.map { ($0 as! NSManagedObject).objectID }
            assert(objectIds.filter { $0.isTemporaryID }.isEmpty, "Found objects with temporary IDs during snapshot generation")
            appendItems(objectIds, toSection: mappedSection)
        }
    }
}

@available(iOS 13.0, *)
public extension NSDiffableDataSourceSnapshot where SectionIdentifierType == String, ItemIdentifierType == NSManagedObjectID {
    /**
    Constructs a `NSDiffableDataSourceSnapshot` where the section identifiers are the fetched section names, and the item identifiers are the fetched object's `NSManagedObjectID`.
    */
    init(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.init(controller) { $0 }
    }
}
