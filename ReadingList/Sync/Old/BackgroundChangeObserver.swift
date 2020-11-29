import Foundation
import CoreData
import os.log
import PersistedPropertyWrapper
/*

extension OSLog {
    static let syncLocalChangeProcessor = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "sync_upstream")
}

/**
    The background change observer watches for changes on the ViewContext, and - when one occurs - merges that change into the SyncContext,
    transforms the pending local change into a remote update instruction, and then makes a request to the delegate for that update to be performed.
 */
@available(iOS 13.0, *)
class BackgroundChangeObserver {
    private let viewContext: NSManagedObjectContext
    private let syncContext: NSManagedObjectContext
    private let historyFetcher: PersistentHistoryFetcher
    private let zoneID: CKRecordZone.ID
    private weak var delegate: BackgroundChangeObserverDelegate?
    private var notificationObserver: NSObjectProtocol?

    init(viewContext: NSManagedObjectContext, syncContext: NSManagedObjectContext, zoneID: CKRecordZone.ID, delegate: BackgroundChangeObserverDelegate) {
        self.viewContext = viewContext
        self.syncContext = syncContext
        self.historyFetcher = PersistentHistoryFetcher(context: syncContext)
        self.zoneID = zoneID
        self.delegate = delegate
    }

    func start() {
        if startedWatchingForChangesTimestamp == nil {
            startedWatchingForChangesTimestamp = Date()
        }
        notificationObserver = NotificationCenter.default.addObserver(forName: .NSManagedObjectContextDidSave, object: viewContext, queue: nil, using: handleViewContextSave(notification:))
        
        self.syncContext.performAndWait {
            if let remoteUpdate = getPendingRemoteInstruction() {
                os_log(.info, log: .sync, "Requesting push of pending pushes present at load")
                delegate?.requestPush(remoteUpdate)
            }
        }
    }

    func stop() {
        if let notificationObserver = notificationObserver {
            NotificationCenter.default.removeObserver(notificationObserver)
        }
    }

    @Persisted(archivedDataKey: "sync_localChangeToken")
    private var lastCommittedLocalChangeToken: NSPersistentHistoryToken?

    @Persisted("sync_localChangeTimestamp")
    private var startedWatchingForChangesTimestamp: Date?
    
    private var lastSeenLocalChangeToken: NSPersistentHistoryToken?

    private func handleViewContextSave(notification: Notification) {
        os_log(.info, log: .sync, "ViewContext save notification triggered local change processing")
        self.syncContext.performAndWait {
            os_log(.info, log: .sync, "Merging changes into syncContext")
            self.syncContext.mergeChanges(fromContextDidSave: notification)

            if let remoteUpdate = getPendingRemoteInstruction() {
                delegate?.requestPush(remoteUpdate)
            }
        }
    }

    private func getPendingRemoteInstruction() -> ManagedObjectChangeSet? {
        guard let (localChanges, transactionToken) = self.getLocalChanges() else { return nil }

        lastSeenLocalChangeToken = transactionToken
        guard let unwrappedLocalChanges = localChanges else {
            os_log(.info, log: .sync, "Local changes were not sync-relevant")
            return nil
        }

        os_log(.info, log: .sync, "Local changes converted to new pending remote instruction")
        return unwrappedLocalChanges.remoteInstruction(context: syncContext, zoneId: zoneID, finalTransactionToken: transactionToken)
    }

    private func getLocalChanges() -> ([ManagedObjectChange]?, NSPersistentHistoryToken)? {
        let transactions: [NSPersistentHistoryTransaction]
        if let historyToken = lastCommittedLocalChangeToken {
            transactions = historyFetcher.fetch(fromToken: historyToken)
            os_log(.debug, log: .syncLocalChangeProcessor, "%d transactions retrieved using token", transactions.count)
        } else if let startedWatchingForChangesTimestamp = startedWatchingForChangesTimestamp {
            transactions = historyFetcher.fetch(fromDate: startedWatchingForChangesTimestamp)
            os_log(.debug, log: .syncLocalChangeProcessor, "%d transactions retrieved using timespan", transactions.count)
        } else {
            preconditionFailure("Unexpected nil startedWatchingForChangesTimestamp value")
        }

        guard let lastTransaction = transactions.last else { return nil }
        os_log(.debug, log: .syncLocalChangeProcessor, "Processing %d transactions", transactions.count)

        return (transactions.compactMap { $0.changeSet() }.flatMap { $0 }, lastTransaction.token)
    }
}

protocol BackgroundChangeObserverDelegate: class {
    func requestPush(_ update: ManagedObjectChangeSet)
}
*/
