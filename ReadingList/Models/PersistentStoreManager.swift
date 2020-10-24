import CoreData
import CoreSpotlight
import os.log

class PersistentStoreManager {

    private(set) static var container: NSPersistentContainer!

    private static let storeName = "books"
    static var storeFileName: String { return "\(storeName).sqlite" }
    static var storeLocation: URL { return URL.applicationSupport.appendingPathComponent(storeFileName) }

    /**
     Creates the NSPersistentContainer, migrating if necessary.
    */
    static func initalisePersistentStore(completion: @escaping () -> Void) throws {
        if container != nil {
            os_log("Reinitialising persistent container")
        }

        // Register our custom transformer for Author tranformable attributes
        AuthorTransformer.register()

        // Migrate the store to the latest version if necessary and then initialise
        container = NSPersistentContainer(name: storeName, manuallyMigratedStoreAt: storeLocation)
        try container.migrateAndLoad(BooksModelVersion.self) {
            self.container.viewContext.automaticallyMergesChangesFromParent = true
            self.container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
            completion()
        }
    }

    /**
     If a store exists in the Documents directory, copies it to the Application Support directory and destroys
     the old store.
    */
    static func moveStoreFromLegacyLocationIfNecessary() {
        let legacyStoreLocation = URL.documents.appendingPathComponent(storeFileName)
        if FileManager.default.fileExists(atPath: legacyStoreLocation.path) && !FileManager.default.fileExists(atPath: storeLocation.path) {
            os_log("Store located in Documents directory; migrating to Application Support directory")
            let tempStoreCoordinator = NSPersistentStoreCoordinator()
            try! tempStoreCoordinator.replacePersistentStore(
                at: storeLocation,
                destinationOptions: nil,
                withPersistentStoreFrom: legacyStoreLocation,
                sourceOptions: nil,
                ofType: NSSQLiteStoreType)

            // Delete the old store
            tempStoreCoordinator.destroyAndDeleteStore(at: legacyStoreLocation)
        }
    }

    /**
     Deletes all objects of the given type
    */
    static func delete<T>(type: T.Type) where T: NSManagedObject {
        os_log("Deleting all %{public}s objects", String(describing: type))
        let batchDelete = NSBatchDeleteRequest(fetchRequest: type.fetchRequest())
        batchDelete.resultType = .resultTypeObjectIDs
        let result = try! PersistentStoreManager.container.persistentStoreCoordinator.execute(batchDelete, with: container.viewContext)
        guard let deletedObjectIds = (result as? NSBatchDeleteResult)?.result as? [NSManagedObjectID] else {
            preconditionFailure("Unexpected batch delete result format: \(result)")
        }
        if deletedObjectIds.isEmpty { return }
        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: [NSDeletedObjectsKey: deletedObjectIds],
                                            into: [PersistentStoreManager.container.viewContext])
    }

    /**
     Deletes all data from the persistent store.
    */
    static func deleteAll() {
        delete(type: List.self)
        delete(type: Subject.self)
        delete(type: Book.self)
    }
}
