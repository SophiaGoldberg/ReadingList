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
class SyncCoordinator: BackgroundChangeObserverDelegate {
    private let viewContext: NSManagedObjectContext
    private let syncContext: NSManagedObjectContext

    private lazy var backgroundChangeObserver =
        BackgroundChangeObserver(viewContext: viewContext, syncContext: syncContext, zoneID: remote.bookZoneID, delegate: self)
    private lazy var remoteUpdateInstructionSerialProcessor = RemoteInstructionSerialProcessor(remote: remote, syncContext: syncContext)

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
        syncContext.mergePolicy = NSMergePolicy.mergeByPropertyStoreTrump // TODO: Add a custom merge policy?
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
            startNotificationObserving()
            //downstreamChangeProcessor.processRemoteChanges()
            //processPendingRemoteChanges()
            remoteUpdateInstructionSerialProcessor.requestPull()
            backgroundChangeObserver.start()
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
            self.backgroundChangeObserver.stop()
        }
    }

    /**
     Requests any remote changes, merging them into the local store.
    */
    func remoteNotificationReceived(applicationCallback: ((UIBackgroundFetchResult) -> Void)? = nil) {
        remoteUpdateInstructionSerialProcessor.requestPull()
    }

    func requestPush(_ update: LocalChangeRemoteUpdateInstruction) {
        remoteUpdateInstructionSerialProcessor.requestPush(update)
    }

    /**
     Registers Save observers on both the viewContext and the syncContext, handling them by merging the save from
     one context to the other, and also calling `processPendingLocalChanges(objects:)` on the updated or inserted objects.
    */
    private func startNotificationObserving() {
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
}
