import Foundation
import CoreData
import os.log

extension NSManagedObjectContext {

    /**
     Creates a child managed object context, and adds an observer to the child context's willSave event in order to obtain permanent IDs on the child context. Once the save
     has taken place, the parent context will be saved, to cascade up to the persistent store.
     */
    func childContext(concurrencyType: NSManagedObjectContextConcurrencyType = .mainQueueConcurrencyType, autoMerge: Bool = true) -> NSManagedObjectContext {
        let childContext = NSManagedObjectContext(concurrencyType: concurrencyType)
        childContext.parent = self
        childContext.name = "\(self.name ?? "UnnamedContext")-child"
        childContext.automaticallyMergesChangesFromParent = autoMerge

        // When a child context is about to save, we should make sure that any inserted objects have permanent IDs, rather than
        // temporary IDs. Otherwise, we will end up with objects with temporary IDs in the viewContext, which will immediately
        // get picked up by any observing NSFetchedResultsControllers, and can cause crashes later on when the equivalent non-temporary
        // object changes.
        NotificationCenter.default.addObserver(childContext, selector: #selector(obtainPermanentIdsForInsertedObjects), name: .NSManagedObjectContextWillSave, object: childContext)

        // When a child context is saved, the changes are merged into its parent context automatically. However, we still need to
        // then save any changes from the root context (the viewContext) into the persistent store. This notification observer
        // triggers a save of *this* object (i.e. the child context's parent) in response to a save on the child context.
        NotificationCenter.default.addObserver(self, selector: #selector(saveAndLogIfErrored), name: .NSManagedObjectContextDidSave, object: childContext)

        os_log("Created child context %s", type: .debug, childContext.name!)
        return childContext
    }

    /**
     Tries to save the managed object context and logs an event and raises a fatal error if failure occurs.
     */
    @objc func saveAndLogIfErrored() {
        do {
            try self.save()
        } catch let error as NSError {
            UserEngagement.logError(error)
            preconditionFailure(error.localizedDescription)
        }
    }

    @objc private func obtainPermanentIdsForInsertedObjects() {
        guard !insertedObjects.isEmpty else { return }
        let temporaryObjects = Array(insertedObjects.filter { $0.objectID.isTemporaryID })
        guard !temporaryObjects.isEmpty else { return }
        os_log("Obtaining permanent IDs for %d objects", type: .debug, temporaryObjects.count)
        try! obtainPermanentIDs(for: temporaryObjects)
    }

    /**
     Saves if changes are present in the context.
     */
    @discardableResult func saveIfChanged() -> Bool {
        guard hasChanges else { return false }
        self.saveAndLogIfErrored()
        return true
    }

    func performAndSave(block: @escaping () -> Void) {
        perform { [unowned self] in
            block()
            self.saveAndLogIfErrored()
        }
    }
}

extension NSManagedObject {
    func deleteAndSave() {
        delete()
        managedObjectContext!.saveAndLogIfErrored()
    }
}
