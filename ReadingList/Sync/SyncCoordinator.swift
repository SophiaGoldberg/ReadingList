import Foundation
import CoreData
import UIKit
import CloudKit
import Reachability
import os.log
import PersistedPropertyWrapper

/**
 Coordinates synchronisation of a local CoreData store with a CloudKit remote store.
*/
@available(iOS 13.0, *)
class SyncCoordinator {
    private let viewContext: NSManagedObjectContext
    private let syncContext: NSManagedObjectContext

    private lazy var downstreamChangeProcessor = BookRemoteChangeProcessor(context: syncContext, remote: remote, syncCoordinator: self)
    private lazy var localChangeProcessor = BookLocalChangeProcessor(syncContext: syncContext, viewContext: viewContext, remote: remote)

    let reachability = try! Reachability()
    let remote = BookCloudKitRemote()

    private var notificationObservers = [NSObjectProtocol]()
    private(set) var isStarted = false

    init(container: NSPersistentContainer) {
        viewContext = container.viewContext
        viewContext.name = "viewContext"

        syncContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        syncContext.persistentStoreCoordinator = container.persistentStoreCoordinator
        syncContext.name = "syncContext"
        try! syncContext.setQueryGenerationFrom(.current)
        syncContext.mergePolicy = NSMergePolicy.mergeByPropertyStoreTrump // FUTURE: Add a custom merge policy?
    }

    func monitorNetworkReachability() {
        do {
            try reachability.startNotifier()
            NotificationCenter.default.addObserver(self, selector: #selector(networkConnectivityDidChange), name: .reachabilityChanged, object: nil)
        } catch {
            os_log("Error starting reachability notifier: %{public}s", log: .sync, type: .error, error.localizedDescription)
        }
    }

    @objc func networkConnectivityDidChange() {
        os_log("Network connectivity changed to %{public}s", log: .sync, type: .info, reachability.connection.description)
        if reachability.connection == .unavailable {
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
            syncContext.refreshAllObjects() // TODO Needed?
            startNotificationObserving()
            downstreamChangeProcessor.processRemoteChanges()
            processPendingRemoteChanges()
        }

        syncContext.perform {
            guard !self.isStarted else {
                os_log("SyncCoordinator instructed to start but it is already started", log: .sync, type: .info)
                return
            }

            os_log("SyncCoordinator starting...")
            self.isStarted = true

            if !self.remote.isInitialised {
                self.remote.initialise { error in
                    self.syncContext.perform {
                        if let error = error {
                            os_log("Error initialising CloudKit remote connectivity: %{public}s", log: .sync, type: .error, error.localizedDescription)
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
                os_log("SyncCoordinator instructed to stop but it is already stopped", log: .sync, type: .info)
                return
            }

            os_log("SyncCoordinator stopping...", log: .sync)
            self.isStarted = false
            self.notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
            self.notificationObservers.removeAll()
        }
    }

    var pendingRemoteUpdates: LocalChangeRemoteUpdateInstruction?

    func handleViewContextSave(notification: Notification) {
        os_log(.info, log: .sync, "ViewContext save notification triggered local change processing")
        self.syncContext.perform {
            self.syncContext.mergeChanges(fromContextDidSave: notification)
            self.processPendingRemoteChanges()
        }
    }

    func processPendingRemoteChanges() {
        let dispatchGroup = DispatchGroup()
        dispatchGroup.notify(queue: .global(qos: .userInitiated)) {
            self.syncContext.perform {
                self.pendingRemoteUpdates = nil
            }
        }
        guard let currentRemoteUpdateInstructions = self.localChangeProcessor.getRemoteUpdateInstructions() else {
            return
        }
        self.pendingRemoteUpdates = currentRemoteUpdateInstructions
        dispatchGroup.enter()
        self.localChangeProcessor.performRemoteUpdate(currentRemoteUpdateInstructions) {
            dispatchGroup.leave()
        }
    }

    /**
     Registers Save observers on both the viewContext and the syncContext, handling them by merging the save from
     one context to the other, and also calling `processPendingLocalChanges(objects:)` on the updated or inserted objects.
    */
    private func startNotificationObserving() {
        // Merge syncContext changes into the viewContext
//        NotificationCenter.default.addObserver(forName: .NSManagedObjectContextDidSave, object: syncContext, queue: nil) { [weak self] note in
//            guard let self = self else { return }
//            self.viewContext.perform {
//                self.viewContext.mergeChanges(fromContextDidSave: note)
//            }
//        }

        let saveObserver = NotificationCenter.default.addObserver(forName: .NSManagedObjectContextDidSave, object: viewContext, queue: nil, using: handleViewContextSave(notification:))
        notificationObservers.append(saveObserver)

        let stopObserver = NotificationCenter.default.addObserver(forName: .DisableCloudSync, object: nil, queue: nil) { [weak self] _ in
            self?.stop()
        }
        notificationObservers.append(stopObserver)

        let pauseObserver = NotificationCenter.default.addObserver(forName: .PauseCloudSync, object: nil, queue: nil) { [weak self] notification in
            guard let self = self else { return }
            let retryAfterSeconds: Double
            if let postedRetryTime = notification.object as? Double {
                retryAfterSeconds = postedRetryTime
            } else {
                retryAfterSeconds = 10.0
            }
            os_log("Pause sync notification received: stopping SyncCoordinator for %d seconds", log: .sync, retryAfterSeconds)

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
            os_log("Processing changes in response to a remote notification", log: .sync, type: .info)
            self.downstreamChangeProcessor.processRemoteChanges(callback: applicationCallback)
        }
    }
}
