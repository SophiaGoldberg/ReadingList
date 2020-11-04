import Foundation
import CoreData
import UIKit
import CloudKit
import Reachability
import os.log

/**
 Coordinates synchronisation of a local CoreData store with a CloudKit remote store.
*/
class SyncCoordinator {

    /*
     The SyncCoordinator is in charge of ensuring all local changes are pushed to CloudKit, and all
     remote CloudKit changes are downloaded and integrated with the local store. The strategy is
     inspired by the chapter "Syncing with Web-Services" in the objc book "Core Data". It is roughly
     as follows:
     
        - A background NSManagedObjectContext is created from the viewContext, named the "syncContext"
        - Core Data change notifications trigger merges between the two contexts
        - There are a sequence of "ChangeProcessors": either upstream or downstream
        - Each upstream change processor has an NSPredicate which determines whether any object has a "pending change"
        - Any object modification merged into the sync context will be checked against each change processor
        - Objects which do have a pending change are used to push that change to CloudKit
        - Upon confirmation of the change being received, some modification is made to the object; this should prevent
            the object from being seen as having pending changes. (These modifications will be merged back to the viewContext).
        - Meanwhile, the syncCoordinator registers for notifications of remote changes
        - Anytime a remote change notification comes in, the syncCoordinator fetches changes from CloudKit using a stored
            change token object.
        - The downloaded remote records are used to update objects in Core Data
        - The new change token is also updated in Core Data (and the books and change token are saved together, atomically).
    */

    private let viewContext: NSManagedObjectContext
    private let syncContext: NSManagedObjectContext

    private let upstreamChangeProcessors: [UpstreamChangeProcessor]
    private let downstreamChangeProcessor: BookDownloader

    let reachability = try! Reachability()
    let remote = BookCloudKitRemote()

    private var notificationObservers = [NSObjectProtocol]()
    private(set) var isStarted = false

    init(container: NSPersistentContainer) {
        viewContext = container.viewContext
        viewContext.name = "viewContext"

        syncContext = container.newBackgroundContext()
        syncContext.name = "syncContext"
        syncContext.mergePolicy = NSMergePolicy.mergeByPropertyStoreTrump // FUTURE: Add a custom merge policy?

        self.downstreamChangeProcessor = BookDownloader(syncContext, remote)
        self.upstreamChangeProcessors = [BookUploader(syncContext, remote)
                                         // TODO: Restore book deleter
                                         //,BookDeleter(syncContext, remote)
        ]
    }

    func monitorNetworkReachability() {
        do {
            try reachability.startNotifier()
            NotificationCenter.default.addObserver(self, selector: #selector(networkConnectivityDidChange), name: .reachabilityChanged, object: nil)
        } catch {
            os_log("Error starting reachability notifier: %{public}s", type: .error, error.localizedDescription)
        }
    }

    @objc func networkConnectivityDidChange() {
        let currentConnection = reachability.connection
        os_log("Network connectivity changed to %{public}s", type: .info, currentConnection.description)
        if currentConnection == .unavailable {
            stop()
        } else {
            start()
        }
    }

    /**
     Starts monitoring for changes in CoreData, and immediately process any outstanding pending changes.
     */
    func start() {

        func postRemoteInitialisation() {
            syncContext.refreshAllObjects()
            startNotificationObserving()
            downstreamChangeProcessor.processRemoteChanges()
            processPendingLocalChanges()
        }

        syncContext.perform {
            guard !self.isStarted else {
                os_log("SyncCoordinator instructed to start but it is already started", type: .info)
                return
            }

            os_log("SyncCoordinator starting...")
            self.isStarted = true

            if !self.remote.isInitialised {
                self.remote.initialise { error in
                    self.syncContext.perform {
                        if let error = error {
                            os_log("Error initialising CloudKit remote connectivity: %{public}s", type: .error, error.localizedDescription)
                            self.isStarted = false
                        } else {
                            postRemoteInitialisation()
                        }
                    }
                }
            } else {
                postRemoteInitialisation()
            }
        }
    }

    /**
     Stops the monitoring of CoreData changes.
    */
    func stop() {
        syncContext.perform {
            guard self.isStarted else {
                os_log("SyncCoordinator instructed to stop but it is already stopped", type: .info)
                return
            }

            os_log("SyncCoordinator stopping...")
            self.isStarted = false
            self.notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
            self.notificationObservers.removeAll()
        }
    }

    /**
     Registers Save observers on both the viewContext and the syncContext, handling them by merging the save from
     one context to the other, and also calling `processPendingLocalChanges(objects:)` on the updated or inserted objects.
    */
    private func startNotificationObserving() {
        func registerForMergeOnSave(from sourceContext: NSManagedObjectContext, to destinationContext: NSManagedObjectContext) {
            let observer = NotificationCenter.default.addObserver(forName: .NSManagedObjectContextDidSave, object: sourceContext, queue: nil) { [weak self] note in

                // Merge the changes into the destination context, on the appropriate thread
                os_log("Merging save from %{public}s to %{public}s", type: .debug, sourceContext.name!, destinationContext.name!)
                destinationContext.performMergeChanges(from: note)

                // Take the new or modified objects, mapped to the syncContext, and process them as local changes.
                // There may be nothing to perform with these local objects; the eligibility of the objects will
                // be checked within processPendingLocalChanges(objects:).
                guard let coordinator = self else { return }
                coordinator.syncContext.perform {
                    // We unpack the notification here, to make sure it is retained until this point.
                    let updates = note.updatedObjects?.map { $0.inContext(coordinator.syncContext) } ?? []
                    let inserts = note.insertedObjects?.map { $0.inContext(coordinator.syncContext) } ?? []
                    let localChanges = updates + inserts
                    if !localChanges.isEmpty {
                        coordinator.processPendingLocalChanges(objects: localChanges)
                    }
                }
            }
            notificationObservers.append(observer)
        }

        registerForMergeOnSave(from: syncContext, to: viewContext)
        registerForMergeOnSave(from: viewContext, to: syncContext)

        let stopObserver = NotificationCenter.default.addObserver(forName: .DisableCloudSync, object: nil, queue: nil) { _ in
            self.stop()
        }
        notificationObservers.append(stopObserver)

        let pauseObserver = NotificationCenter.default.addObserver(forName: .PauseCloudSync, object: nil, queue: nil) { notification in
            let retryAfterSeconds: Double
            if let postedRetryTime = notification.object as? Double {
                retryAfterSeconds = postedRetryTime
            } else {
                retryAfterSeconds = 10.0
            }
            os_log("Pause sync notification received: stopping SyncCoordinator for %d seconds", retryAfterSeconds)

            self.stop()
            DispatchQueue.main.asyncAfter(deadline: .now() + retryAfterSeconds) {
                self.start()
            }
        }
        notificationObservers.append(pauseObserver)
    }

    /**
     Requests any remote changes, merging them into the local store.
    */
    func remoteNotificationReceived(applicationCallback: ((UIBackgroundFetchResult) -> Void)? = nil) {
        syncContext.perform {
            os_log("Processing changes in response to a remote notification", type: .info)
            self.downstreamChangeProcessor.processRemoteChanges(callback: applicationCallback)
        }
    }

    // We prevent the processing objects that are already being processed. This is an easy way to prevent some
    // errors on the CloudKit end, like uploading a new book twice, due to its creation and a successive edit
    // (before the creation's callback runs).
    private var objectsBeingProcessed = Set<NSManagedObject>()

    private func processPendingLocalChanges(objects: [NSManagedObject]? = nil) {
        for changeProcessor in upstreamChangeProcessors {
            // If we were passed some pending objects, select the ones which are pending a change process.
            // Otherwise, select all pending objects. We always exclude objects which are already being processed.
            let objectToProcess: [NSManagedObject]
            if let objects = objects {
                objectToProcess = objects.filter { object($0, isPendingFor: changeProcessor) && !objectsBeingProcessed.contains($0) }
            } else {
                objectToProcess = self.pendingObjects(for: changeProcessor).filter { !objectsBeingProcessed.contains($0) }
            }

            // Quick exit if there are no pending objects
            guard !objectToProcess.isEmpty else { continue }

            // Track which objects are passed to the change processor. They will not be passed to any other
            // change processor until this one has run its completion block.
            objectsBeingProcessed.formUnion(objectToProcess)
            changeProcessor.processLocalChanges(objectToProcess) { [weak self] in
                self?.objectsBeingProcessed.subtract(objectToProcess)
            }
        }

        // TODO: Re-process the objects which are still eligible for processing after this operation?
        // This could be due to local edits which occurred while the remote update operation was pending.
        // Alternatively, capture the objects which came in again but were rejected, and reprocess those ones?
    }

    private func pendingObjects(for changeProcessor: UpstreamChangeProcessor) -> [NSManagedObject] {
        let fetchRequest = changeProcessor.unprocessedChangedObjectsRequest
        fetchRequest.returnsObjectsAsFaults = false
        return try! syncContext.fetch(fetchRequest) as! [NSManagedObject]
    }

    private func object(_ object: NSManagedObject, isPendingFor changeProcessor: UpstreamChangeProcessor) -> Bool {
        let fetchRequest = changeProcessor.unprocessedChangedObjectsRequest
        // Entity name comparison is done since the NSEntityDescription is not necessarily present until a fetch has been peformed
        return object.entity.name == fetchRequest.entityName && fetchRequest.predicate?.evaluate(with: object) != false
    }
}
