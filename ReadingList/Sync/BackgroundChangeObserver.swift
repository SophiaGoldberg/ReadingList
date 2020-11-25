import Foundation
import CoreData
import os.log
import PersistedPropertyWrapper

extension OSLog {
    static let syncLocalChangeProcessor = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "sync_upstream")
}
//
///**
//    The background change observer watches for changes on the ViewContext, and - when one occurs - merges that change into the SyncContext,
//    transforms the pending local change into a remote update instruction, and then makes a request to the delegate for that update to be performed.
// */
//@available(iOS 13.0, *)
//class BackgroundChangeObserver {
//    private let syncContext: NSManagedObjectContext
//    private let historyFetcher: PersistentHistoryFetcher
//    private let remote: BookCloudKitRemote
//    private let persistentStoreCoordinator: NSPersistentStoreCoordinator
//    private weak var delegate: BackgroundChangeObserverDelegate?
//    private var notificationObserver: NSObjectProtocol?
//
//    init(persistentStoreCoordinator: NSPersistentStoreCoordinator, syncContext: NSManagedObjectContext, remote: BookCloudKitRemote, delegate: BackgroundChangeObserverDelegate) {
//        self.remote = remote
//        self.persistentStoreCoordinator = persistentStoreCoordinator
//        self.syncContext = syncContext
//
//        self.historyFetcher = PersistentHistoryFetcher(context: syncContext)
//        self.delegate = delegate
//    }
//
//    func start() {
//        // If this is first startup, we don't have a date or a token to work with when detecting changes. Use the current date.
//        if startedWatchingForChangesTimestamp == nil {
//            startedWatchingForChangesTimestamp = Date()
//        }
//        
//        // Watch for changes to the persistent store
//        notificationObserver = NotificationCenter.default.addObserver(forName: .NSPersistentStoreRemoteChange, object: persistentStoreCoordinator, queue: nil, using: handleStoreChange(notification:))
//        
//        // In case there are any already-pending updates, perform a push
//        self.delegate?.requestPush()
//    }
//
//    func stop() {
//        if let notificationObserver = notificationObserver {
//            NotificationCenter.default.removeObserver(notificationObserver)
//        }
//    }
//
//    @Persisted(archivedDataKey: "sync_localChangeToken")
//    private var lastCommittedLocalChangeToken: NSPersistentHistoryToken?
//
//    @Persisted("sync_localChangeTimestamp")
//    private var startedWatchingForChangesTimestamp: Date?
//    
//    private var lastSeenLocalChangeToken: NSPersistentHistoryToken?
//
//    private func handleStoreChange(notification: Notification) {
//        os_log(.info, log: .sync, "ViewContext save notification triggered local change processing")
//        self.syncContext.perform {
//            os_log(.info, log: .sync, "Merging changes into syncContext")
//            if let userInfo = notification.userInfo {
//                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: userInfo, into: [self.syncContext])
//            }
//
//            if let remoteUpdate = self.getPendingRemoteInstruction() {
//                os_log(.info, log: .sync, "Performing remote push due to store changes")
//                self.delegate?.requestPush(remoteUpdate) {
//                    os_log(.info, log: .sync, "Push competed; saving change token")
//                    self.lastCommittedLocalChangeToken = remoteUpdate.finalTransactionToken
//                }
//            }
//        }
//    }
//
//    private func getPendingRemoteInstruction() -> LocalChangeRemoteUpdateInstruction? {
//        guard let (localChanges, transactionToken) = self.getLocalChanges() else { return nil }
//
//        lastSeenLocalChangeToken = transactionToken
//        guard let unwrappedLocalChanges = localChanges else {
//            os_log(.info, log: .sync, "Local changes were not sync-relevant")
//            return nil
//        }
//
//        os_log(.info, log: .sync, "Local changes converted to new pending remote instruction")
//        return unwrappedLocalChanges.remoteInstruction(context: syncContext, zoneId: remote.bookZoneID, finalTransactionToken: transactionToken)
//    }
//
//    private func getLocalChanges() -> ([LocalChange]?, NSPersistentHistoryToken)? {
//        let transactions: [NSPersistentHistoryTransaction]
//        if let historyToken = lastCommittedLocalChangeToken {
//            transactions = historyFetcher.fetch(fromToken: historyToken)
//            os_log(.debug, log: .syncLocalChangeProcessor, "%d transactions retrieved using token", transactions.count)
//        } else if let startedWatchingForChangesTimestamp = startedWatchingForChangesTimestamp {
//            transactions = historyFetcher.fetch(fromDate: startedWatchingForChangesTimestamp)
//            os_log(.debug, log: .syncLocalChangeProcessor, "%d transactions retrieved using timespan", transactions.count)
//        } else {
//            preconditionFailure("Unexpected nil startedWatchingForChangesTimestamp value")
//        }
//
//        guard let lastTransaction = transactions.last else { return nil }
//        os_log(.debug, log: .syncLocalChangeProcessor, "Processing %d transactions", transactions.count)
//
//        return (transactions.compactMap { $0.localChangeRepresentations() }.flatMap { $0 }, lastTransaction.token)
//    }
//}
//
//protocol BackgroundChangeObserverDelegate: class {
//    func requestPush()
//}
