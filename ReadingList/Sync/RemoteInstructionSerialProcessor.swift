import Foundation
import CloudKit
import CoreData
import os.log
import PersistedPropertyWrapper
import ReadingList_Foundation
import UIKit

@available(iOS 13.0, *)
class RemoteInstructionSerialProcessor {
    let remote: BookCloudKitRemote
    private let persistentStoreCoordinator: NSPersistentStoreCoordinator
    private let dispatchQueue = DispatchQueue(label: "remote-instruction-serial-processor", qos: .userInitiated)
    private let syncContext: NSManagedObjectContext
    private let historyFetcher: PersistentHistoryFetcher
    private var notificationObserver: NSObjectProtocol?

    private lazy var remotePushProcessor = RemotePushProcessor(remote: remote, syncContext: syncContext)
    private lazy var remotePullProcessor = RemotePullProcessor(remote: remote, syncContext: syncContext)
    let pushOperationDispatchGroup = DispatchGroup()

    init(remote: BookCloudKitRemote, persistentStoreCoordinator: NSPersistentStoreCoordinator) {
        self.remote = remote
        self.persistentStoreCoordinator = persistentStoreCoordinator

        syncContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        syncContext.persistentStoreCoordinator = persistentStoreCoordinator
        syncContext.name = "syncContext"
        try! syncContext.setQueryGenerationFrom(.current)
        // We handle conflicts by letting the persistent store changes trump the in-memory (i.e. downloaded) changes.
        syncContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        
        // If this is first startup, we don't have a date or a token to work with when detecting changes. Use the current date.
        if Self.startedWatchingForChangesTimestamp == nil {
            Self.startedWatchingForChangesTimestamp = Date()
        }
        
        self.historyFetcher = PersistentHistoryFetcher(context: syncContext)
    }
    
    func start() {
        // Watch for changes to the persistent store
        notificationObserver = NotificationCenter.default.addObserver(forName: .NSPersistentStoreRemoteChange, object: persistentStoreCoordinator, queue: nil, using: handleStoreChange(notification:))
        
        // In case there are any already-pending updates, perform a push
        requestPush()
        requestPull()
    }
    
    func requestPush() {
        dispatchQueue.async {
            self.pushOperationDispatchGroup.enter()
            self.syncContext.perform {
                if let remoteUpdate = self.getPendingRemoteInstruction() {
                    self.remotePushProcessor.push(remoteUpdate) {
                        self.lastCommittedLocalChangeToken = remoteUpdate.finalTransactionToken
                        self.pushOperationDispatchGroup.leave()
                    }
                }
            }
        }
    }
    
    var pendingPull = false

    func requestPull(applicationCallback: ((UIBackgroundFetchResult) -> Void)? = nil) {
        dispatchQueue.async {
            if self.pendingPull {
                os_log("A pull was requested but one is already pending", log: .syncDownstream)
                return
            }
            self.pendingPull = true
            self.pushOperationDispatchGroup.notify(queue: self.dispatchQueue) {
                self.pendingPull = false
                self.remotePullProcessor.pull() {
                    applicationCallback?(.newData) // TODO We haven't actually checked whether there is new data...
                }
            }
        }
    }
    
    @Persisted(archivedDataKey: "sync_localChangeToken")
    private var lastCommittedLocalChangeToken: NSPersistentHistoryToken?

    @Persisted("sync_localChangeTimestamp")
    static var startedWatchingForChangesTimestamp: Date?
    
    private var lastSeenLocalChangeToken: NSPersistentHistoryToken?

    private func handleStoreChange(notification: Notification) {
        os_log(.info, log: .sync, "Store change notification triggered local change processing")
        dispatchQueue.async {
            self.pushOperationDispatchGroup.notify(queue: self.dispatchQueue) {
                self.syncContext.perform {
                    os_log(.info, log: .sync, "Merging changes into syncContext")
                    if let userInfo = notification.userInfo {
                        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: userInfo, into: [self.syncContext])
                    }
                    self.requestPush()
                }
            }
        }
    }

    private func getPendingRemoteInstruction() -> LocalChangeRemoteUpdateInstruction? {
        guard let (localChanges, transactionToken) = self.getLocalChanges() else { return nil }

        lastSeenLocalChangeToken = transactionToken
        guard let unwrappedLocalChanges = localChanges else {
            os_log(.info, log: .sync, "Local changes were not sync-relevant")
            return nil
        }

        os_log(.info, log: .sync, "Local changes converted to new pending remote instruction")
        return unwrappedLocalChanges.remoteInstruction(context: syncContext, zoneId: remote.bookZoneID, finalTransactionToken: transactionToken)
    }

    private func getLocalChanges() -> ([LocalChange]?, NSPersistentHistoryToken)? {
        let transactions: [NSPersistentHistoryTransaction]
        if let historyToken = lastCommittedLocalChangeToken {
            transactions = historyFetcher.fetch(fromToken: historyToken)
            os_log(.debug, log: .syncLocalChangeProcessor, "%d transactions retrieved using token", transactions.count)
        } else if let startedWatchingForChangesTimestamp = Self.startedWatchingForChangesTimestamp {
            transactions = historyFetcher.fetch(fromDate: startedWatchingForChangesTimestamp)
            os_log(.debug, log: .syncLocalChangeProcessor, "%d transactions retrieved using timespan", transactions.count)
        } else {
            preconditionFailure("Unexpected nil startedWatchingForChangesTimestamp value")
        }

        guard let lastTransaction = transactions.last else { return nil }
        os_log(.debug, log: .syncLocalChangeProcessor, "Processing %d transactions", transactions.count)

        return (transactions.compactMap { $0.localChangeRepresentations() }.flatMap { $0 }, lastTransaction.token)
    }
}
