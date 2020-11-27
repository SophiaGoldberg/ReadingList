import Foundation
import CloudKit
import os.log
import PersistedPropertyWrapper
import ReadingList_Foundation
import CoreData

extension OSLog {
    static let syncCoordinator = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "SyncCoordinator")
}

@available(iOS 13.0, *)
final class SyncCoordinator { //swiftlint:disable:this type_body_length

    private let persistentStoreCoordinator: NSPersistentStoreCoordinator
    
    init(persistentStoreCoordinator: NSPersistentStoreCoordinator) {
        self.persistentStoreCoordinator = persistentStoreCoordinator
    }
    
    private let container = CKContainer.default()
    private lazy var privateDatabase = container.privateCloudDatabase
    private lazy var zoneID = CKRecordZone.ID(zoneName: "ReadingListZone", ownerName: CKCurrentUserDefaultName)
    private lazy var privateSubscriptionId = "\(zoneID.zoneName).subscription"

    private var buffer = [ManagedObjectChangeSet]()

    /// Called when models are deleted remotely.
    var didDeleteModels: ([String]) -> Void = { _ in }

    private let workQueue = DispatchQueue(label: "SyncEngine.Work", qos: .userInitiated)
    private let cloudQueue = DispatchQueue(label: "SyncEngine.Cloud", qos: .userInitiated)
    
    private lazy var syncContext: NSManagedObjectContext = {
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = persistentStoreCoordinator
        context.name = "SyncEngineContext"
        try! context.setQueryGenerationFrom(.current)
        context.mergePolicy = NSMergePolicy.mergeByPropertyStoreTrump // TODO: Add a custom merge policy?
        return context
    }()

    // MARK: - Setup boilerplate

    var completedStartup = false
    
    #if DEBUG
    var debugSimulatorSyncPollTimer: Timer?
    #endif

    func start() {
        prepareCloudEnvironment { [weak self] in
            guard let self = self else { return }
            os_log("Cloud environment preparation done", log: .syncCoordinator, type: .debug)

            self.completedStartup = true
            self.startObservingLocalChanges()
            self.uploadLocalDataNotUploadedYet()
            self.fetchRemoteChanges()
            
            #if DEBUG && targetEnvironment(simulator)
            self.debugSimulatorSyncPollTimer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(self.respondToRemoteChangeNotification), userInfo: nil, repeats: true)
            #endif
        }
    }
    
    @objc func respondToRemoteChangeNotification() {
        workQueue.async {
            self.fetchRemoteChanges()
        }
    }

    /// A single-concurrent-operation queue used to manage cloud-interation operations.
    private lazy var cloudOperationQueue: OperationQueue = {
        let operationQueue = OperationQueue()
        operationQueue.underlyingQueue = cloudQueue
        operationQueue.name = "SyncEngine.Cloud"
        operationQueue.maxConcurrentOperationCount = 1
        return operationQueue
    }()
    
    func suspendCloudInterop(dueTo error: Error) -> Bool {
        guard let effectiveError = error as? CKError else { return false }

        guard let retryDelay = effectiveError.retryAfterSeconds else {
            os_log("Error is not recoverable", log: .syncCoordinator, type: .error)
            return false
        }

        os_log("Error is recoverable. Will retry after %{public}f seconds", log: .syncCoordinator, type: .error, retryDelay)

        self.cloudOperationQueue.isSuspended = true
        workQueue.asyncAfter(deadline: .now() + retryDelay) {
            self.cloudOperationQueue.isSuspended = false
        }

        return true
    }

    @Persisted("SyncEngine_CustomZoneCreated", defaultValue: false)
    private var createdCustomZone: Bool

    @Persisted("SyncEngine_PrivateSubscriptionKey", defaultValue: false)
    private var createdPrivateSubscription: Bool

    private func prepareCloudEnvironment(then block: @escaping () -> Void) {
        workQueue.async { [weak self] in
            guard let self = self else { return }

            self.createCustomZoneIfNeeded()
            self.cloudOperationQueue.waitUntilAllOperationsAreFinished()
            guard self.createdCustomZone else { return }

            self.createPrivateSubscriptionsIfNeeded()
            self.cloudOperationQueue.waitUntilAllOperationsAreFinished()
            guard self.createdPrivateSubscription else { return }

            DispatchQueue.main.async { block() }
        }
    }

    private func createCustomZoneIfNeeded() {
        guard !createdCustomZone else {
            os_log("Already have custom zone, skipping creation but checking if zone really exists", log: .syncCoordinator, type: .debug)
            checkCustomZone()
            return
        }

        os_log("Creating CloudKit zone %@", log: .syncCoordinator, type: .info, zoneID)

        let zone = CKRecordZone(zoneID: zoneID)
        let operation = CKModifyRecordZonesOperation(recordZonesToSave: [zone], recordZoneIDsToDelete: nil)

        operation.modifyRecordZonesCompletionBlock = { [weak self] _, _, error in
            guard let self = self else { return }

            if let error = error {
                os_log("Failed to create custom CloudKit zone: %{public}@", log: .syncCoordinator, type: .error, String(describing: error))
                if self.suspendCloudInterop(dueTo: error) {
                    self.createCustomZoneIfNeeded()
                }
            } else {
                os_log("Zone created successfully", log: .syncCoordinator, type: .info)
                self.createdCustomZone = true
            }
        }

        operation.qualityOfService = .userInitiated
        operation.database = privateDatabase

        cloudOperationQueue.addOperation(operation)
    }

    private func checkCustomZone() {
        let operation = CKFetchRecordZonesOperation(recordZoneIDs: [zoneID])
        operation.fetchRecordZonesCompletionBlock = { [weak self] ids, error in
            guard let self = self else { return }

            if let error = error {
                os_log("Failed to check for custom zone existence: %{public}@", log: .syncCoordinator, type: .error, String(describing: error))

                if self.suspendCloudInterop(dueTo: error) {
                    self.checkCustomZone()
                } else {
                    os_log("Irrecoverable error when fetching custom zone, assuming it doesn't exist: %{public}@", log: .syncCoordinator, type: .error, String(describing: error))

                    DispatchQueue.main.async {
                        self.createdCustomZone = false
                        self.createCustomZoneIfNeeded()
                    }
                }
            } else if ids == nil || ids!.isEmpty {
                os_log("Custom zone reported as existing, but it doesn't exist. Creating.", log: .syncCoordinator, type: .error)
                self.createdCustomZone = false
                self.createCustomZoneIfNeeded()
            }
        }

        operation.qualityOfService = .userInitiated
        operation.database = privateDatabase

        cloudOperationQueue.addOperation(operation)
    }

    private func createPrivateSubscriptionsIfNeeded() {
        guard !createdPrivateSubscription else {
            os_log("Already subscribed to private database changes, skipping subscription but checking if it really exists", log: .syncCoordinator, type: .debug)
            checkSubscription()
            return
        }

        let subscription = CKRecordZoneSubscription(zoneID: zoneID, subscriptionID: privateSubscriptionId)

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: nil)

        operation.database = privateDatabase
        operation.qualityOfService = .userInitiated

        operation.modifySubscriptionsCompletionBlock = { [weak self] _, _, error in
            guard let self = self else { return }

            if let error = error {
                os_log("Failed to create private CloudKit subscription: %{public}@",
                       log: .syncCoordinator,
                       type: .error,
                       String(describing: error))

                if self.suspendCloudInterop(dueTo: error) {
                    self.createPrivateSubscriptionsIfNeeded()
                }
            } else {
                os_log("Private subscription created successfully", log: .syncCoordinator, type: .info)
                self.createdPrivateSubscription = true
            }
        }

        cloudOperationQueue.addOperation(operation)
    }

    private func checkSubscription() {
        let operation = CKFetchSubscriptionsOperation(subscriptionIDs: [privateSubscriptionId])

        operation.fetchSubscriptionCompletionBlock = { [weak self] ids, error in
            guard let self = self else { return }

            if let error = error {
                os_log("Failed to check for private zone subscription existence: %{public}@", log: .syncCoordinator, type: .error, String(describing: error))

                if self.suspendCloudInterop(dueTo: error) {
                    self.checkSubscription()
                } else {
                    os_log("Irrecoverable error when fetching private zone subscription, assuming it doesn't exist: %{public}@", log: .syncCoordinator, type: .error, String(describing: error))

                    DispatchQueue.main.async {
                        self.createdPrivateSubscription = false
                        self.createPrivateSubscriptionsIfNeeded()
                    }
                }
            } else if ids == nil || ids!.isEmpty {
                os_log("Private subscription reported as existing, but it doesn't exist. Creating.", log: .syncCoordinator, type: .error)

                DispatchQueue.main.async {
                    self.createdPrivateSubscription = false
                    self.createPrivateSubscriptionsIfNeeded()
                }
            }
        }

        operation.qualityOfService = .userInitiated
        operation.database = privateDatabase

        cloudOperationQueue.addOperation(operation)
    }

    // MARK: - Upload
    
    private func startObservingLocalChanges() {
        if lastCommittedLocalChangeToken == nil && startedWatchingForChangesTimestamp == nil {
            startedWatchingForChangesTimestamp = Date()
        }
        let notificationObserver = NotificationCenter.default.addObserver(forName: .NSPersistentStoreRemoteChange, object: persistentStoreCoordinator, queue: nil, using: handleStoreChange(notification:))
    }
    
    @Persisted(archivedDataKey: "SyncEngine_LocalChangeToken")
    private var lastCommittedLocalChangeToken: NSPersistentHistoryToken?

    @Persisted("SyncEngine_LocalChangeTimestamp")
    private var startedWatchingForChangesTimestamp: Date?
    
    private var lastSeenLocalChangeToken: NSPersistentHistoryToken?
    
    private lazy var historyFetcher = PersistentHistoryFetcher(context: syncContext, excludeHistoryFromContextWithName: syncContext.name!)

    private func handleStoreChange(notification: Notification) {
        self.syncContext.performAndWait {
            os_log(.info, log: .syncCoordinator, "Merging store changes into syncContext")
            self.syncContext.mergeChanges(fromContextDidSave: notification)
            
            let remoteUpdates = getLocalChanges()
            if !remoteUpdates.isEmpty {
                workQueue.async {
                    os_log(.info, log: .syncCoordinator, "%d change-sets added to buffer", remoteUpdates.count)
                    self.buffer.append(contentsOf: remoteUpdates)
                    self.uploadLocalDataNotUploadedYet()
                }
            }
        }
    }

    private func getLocalChanges() -> [ManagedObjectChangeSet] {
        let transactions: [NSPersistentHistoryTransaction]
        if let historyToken = lastCommittedLocalChangeToken {
            transactions = historyFetcher.fetch(fromToken: historyToken)
            os_log(.debug, log: .syncCoordinator, "%d transaction(s) retrieved using token", transactions.count)
        } else if let startedWatchingForChangesTimestamp = startedWatchingForChangesTimestamp {
            transactions = historyFetcher.fetch(fromDate: startedWatchingForChangesTimestamp)
            os_log(.debug, log: .syncCoordinator, "%d transaction(s) retrieved using timespan", transactions.count)
        } else {
            preconditionFailure("Unexpected nil startedWatchingForChangesTimestamp value")
        }

        return transactions
            .filter { $0.contextName != syncContext.name }
            .compactMap { $0.changeSet() }
    }

    private func uploadLocalDataNotUploadedYet() {
        os_log("%{public}@", log: .syncCoordinator, type: .debug, #function)
        if buffer.isEmpty { return }

        os_log("%d change-sets which haven't been uploaded yet.", log: .syncCoordinator, type: .debug, buffer.count)
        for (index, changeSet) in self.buffer.enumerated() {
            var records: [CKRecord] = []
            os_log("Processing change-set %d of %d", log: .syncCoordinator, type: .debug, index + 1, buffer.count)
            syncContext.performAndWait {
                let inserts = changeSet.inserts
                    .map(syncContext.object(with:))
                    .filter { !$0.isDeleted }
                    .compactMap { ($0 as? CKRecordRepresentable)?.recordForInsert(into: zoneID) }

                let updates = Array(changeSet.updates.keys)
                    .map { syncContext.object(with: $0) }
                    .filter { !$0.isDeleted }
                    .compactMap { managedObject -> (CKRecord?) in
                        guard let changedKeys = changeSet.updates[managedObject.objectID] else {
                            os_log("Error looking up changed keys for object update", log: .syncCoordinator, type: .fault)
                            return nil
                        }
                        guard let ckRecordRepresentable = managedObject as? CKRecordRepresentable else { return nil }
                        return ckRecordRepresentable.recordForUpdate(changedCoreDataKeys: changedKeys) ?? ckRecordRepresentable.recordForInsert(into: zoneID)
                    }

                records = inserts + updates
            }
            
            let deletionIDs = changeSet.deletions.map { CKRecord.ID(recordName: $0, zoneID: zoneID) }
            uploadChanges(records: records, deletions: deletionIDs) {
                guard let bufferIndex = self.buffer.firstIndex(of: changeSet) else {
                    os_log("Could not find index of uploaded local data", log: .syncCoordinator, type: .fault)
                    return
                }
                self.buffer.remove(at: bufferIndex)
                self.lastCommittedLocalChangeToken = changeSet.transactionToken
            }
        }
    }

    private func uploadChanges(records: [CKRecord], deletions: [CKRecord.ID], priority: Operation.QueuePriority = .normal, updateAllLocalMetadata: Bool = false, completion: @escaping () -> Void) {
        os_log("%{public}@ with %d record(s) and %d deletion(s)", log: .syncCoordinator, type: .debug, #function, records.count, deletions.count)
        if records.isEmpty && deletions.isEmpty {
            completion()
            return
        }

        let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: deletions)
        operation.modifyRecordsCompletionBlock = { [weak self] serverRecords, _, error in
            guard let self = self else { return }

            if let error = error {
                os_log("Failed to upload records", log: .syncCoordinator, type: .error)
                os_log("DEBUG INFO: %d server records", log: .syncCoordinator, type: .debug, serverRecords?.count ?? 0)
                self.handleUploadError(error, records: records, ids: deletions, completion: completion)
            } else {
                os_log("Successfully uploaded %{public}d record(s)", log: .syncCoordinator, type: .info, records.count)
                self.updateLocalModelsAfterUpload(with: records, updateAllMetadata: updateAllLocalMetadata)
                completion()
            }
        }

        operation.savePolicy = .ifServerRecordUnchanged
        operation.qualityOfService = .userInitiated
        operation.database = privateDatabase
        operation.queuePriority = priority
        cloudOperationQueue.addOperation(operation)
    }
    
    func handleUnexpectedResponse() {
        fatalError("Should stop syncing, at least for a bit")
    }

    private func handleUploadError(_ error: Error, records: [CKRecord], ids: [CKRecord.ID], completion: @escaping () -> Void) {
        guard let ckError = error as? CKError else {
            os_log("Error was not a CKError, giving up: %{public}@", log: .syncCoordinator, type: .fault, String(describing: error))
            return
        }

        if ckError.code == .limitExceeded {
            os_log("CloudKit batch limit exceeded, sending records in chunks", log: .syncCoordinator, type: .error)

            fatalError("Not implemented: batch uploads. Here we should divide the records in chunks and upload in batches instead of trying everything at once.")
        } else if ckError.code == .partialFailure {
            os_log("Upload partial failure", log: .syncCoordinator, type: .error)
            guard let errorsByItemId = ckError.userInfo[CKPartialErrorsByItemIDKey] as? [CKRecord.ID: Error] else {
                os_log("Missing CKPartialErrorsByItemIDKey data", log: .syncCoordinator, type: .fault)
                self.handleUnexpectedResponse()
                return
            }
            var newUploadBatch = [CKRecord]()
            for record in records {
                if let uploadError = errorsByItemId[record.recordID] as? CKError {
                    if uploadError.code == .serverRecordChanged {
                        guard let serverRecord = uploadError.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord else {
                            handleUnexpectedResponse()
                            return
                        }
                        // TODO: Instead, enqueue a fetch-record operation and subsequently push the local change again. This is currently messing up assets.
                        newUploadBatch.append(serverRecord)
                    } else if uploadError.code == .batchRequestFailed {
                        newUploadBatch.append(record)
                    }
                } else {
                    fatalError("We expected all records to be in the dictionary since operations are atomic")
                }
            }
            uploadChanges(records: newUploadBatch, deletions: ids, priority: .high, updateAllLocalMetadata: true, completion: completion)
        } else {
            if self.suspendCloudInterop(dueTo: error) {
                self.uploadChanges(records: records, deletions: ids, completion: completion)
            } else {
                os_log("Error is not recoverable: %{public}@", log: .syncCoordinator, type: .error, String(describing: error))
                handleUnexpectedResponse()
            }
        }
    }

    private func updateLocalModelsAfterUpload(with records: [CKRecord], updateAllMetadata: Bool = false) {
        guard !records.isEmpty else { return }
        syncContext.performAndWait {
            for record in records {
                let fetchRequest = NSManagedObject.fetchRequest(Book.self)
                fetchRequest.predicate = Book.candidateBookForRemoteIdentifier(record.recordID)
                fetchRequest.fetchLimit = 1
                let fetchResult = try! self.syncContext.fetch(fetchRequest)
                guard let localBook = fetchResult.first, !localBook.isDeleted else {
                    os_log("Local managed object does not exist or was deleted when attempting to update local state following an upload", log: .syncCoordinator, type: .default)
                    continue
                }
                if updateAllMetadata {
                    let keysPendingUpdate = buffer.compactMap { $0.updates[localBook.objectID] }.joined().compactMap { Book.CKRecordKey(rawValue: $0) }
                    localBook.update(from: record, excluding: keysPendingUpdate)
                    os_log("Updated metadata for CKRecord %{public}s on object %{public}s", log: .syncCoordinator, type: .info, record.recordID.recordName, localBook.objectID.uriRepresentation().relativeString)
                } else {
                    localBook.setSystemFields(record)
                    os_log("Updated system fields for CKRecord %{public}s on object %{public}s", log: .syncCoordinator, type: .info, record.recordID.recordName, localBook.objectID.uriRepresentation().relativeString)
                }
            }
            syncContext.saveAndLogIfErrored()
            os_log("Completed updating %d local model(s) after upload", log: .syncCoordinator, type: .default, records.count)
        }
    }

    // MARK: - Remote change tracking

    @Persisted(archivedDataKey: "SyncEngine_SeverChangeToken")
    private var privateChangeToken: CKServerChangeToken?

    private func fetchRemoteChanges() {
        os_log("%{public}@", log: .syncCoordinator, type: .debug, #function)

        var changedRecords: [CKRecord] = []
        var deletedRecordIDs: [CKRecord.ID] = []

        let operation = CKFetchRecordZoneChangesOperation()
        operation.name = "FetchRemoteChanges"
        
        if cloudOperationQueue.operations.contains(where: {
            $0.name == operation.name && !$0.isExecuting && !$0.isCancelled && !$0.isFinished
        }) {
            os_log("Skipping remote change enqeue since one is already enqueued", log: .syncCoordinator, type: .default)
            return
        }

        let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration(
            previousServerChangeToken: privateChangeToken,
            resultsLimit: nil,
            desiredKeys: nil
        )
        operation.configurationsByRecordZoneID = [zoneID: config]
        operation.recordZoneIDs = [zoneID]
        operation.fetchAllChanges = true

        operation.recordZoneChangeTokensUpdatedBlock = { [weak self] _, changeToken, _ in
            guard let self = self else { return }
            guard let changeToken = changeToken else { return }
            self.privateChangeToken = changeToken
        }

        operation.recordZoneFetchCompletionBlock = { [weak self] _, token, _, _, error in
            guard let self = self else { return }

            if let error = error as? CKError {
                os_log("Failed to fetch record zone changes: %{public}@",
                       log: .syncCoordinator,
                       type: .error,
                       String(describing: error))

                if error.code == .changeTokenExpired {
                    os_log("Change token expired, resetting token and trying again", log: .syncCoordinator, type: .error)

                    self.privateChangeToken = nil

                    DispatchQueue.main.async { self.fetchRemoteChanges() }
                } else {
                    if self.suspendCloudInterop(dueTo: error) {
                        self.fetchRemoteChanges()
                    }
                }
            } else {
                os_log("Commiting new change token", log: .syncCoordinator, type: .debug)

                self.privateChangeToken = token
            }
        }

        operation.recordChangedBlock = { changedRecords.append($0) }

        operation.recordWithIDWasDeletedBlock = { recordID, _ in
            // In the future we may need to use the second arg to this closure and map
            // between record types and deleted record IDs (when we need to sync more types)
            deletedRecordIDs.append(recordID)
        }

        operation.fetchRecordZoneChangesCompletionBlock = { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                os_log("Failed to fetch record zone changes: %{public}@",
                       log: .syncCoordinator,
                       type: .error,
                       String(describing: error))

                if self.suspendCloudInterop(dueTo: error) {
                    self.fetchRemoteChanges()
                }
            } else {
                os_log("Finished fetching record zone changes", log: .syncCoordinator, type: .info)

                DispatchQueue.main.async { self.commitServerChangesToDatabase(with: changedRecords, deletedRecordIDs: deletedRecordIDs) }
            }
        }

        operation.qualityOfService = .userInitiated
        operation.database = privateDatabase

        cloudOperationQueue.addOperation(operation)
    }

    private func commitServerChangesToDatabase(with changedRecords: [CKRecord], deletedRecordIDs: [CKRecord.ID]) {
        guard !changedRecords.isEmpty || !deletedRecordIDs.isEmpty else {
            os_log("Finished record zone changes fetch with no changes", log: .syncCoordinator, type: .info)
            return
        }

        os_log("Will commit %d changed record(s) and %d deleted record(s) to the database", log: .syncCoordinator, type: .info, changedRecords.count, deletedRecordIDs.count)

        workQueue.async {
            self.syncContext.performAndWait {
                for record in changedRecords {
                    self.downloadBook(record)
                }
                for deletedID in deletedRecordIDs {
                    self.locallyPresentBook(withId: deletedID)?.delete()
                }
                self.syncContext.saveAndLogIfErrored()
                os_log("Completed updating local model(s) after download", log: .syncCoordinator, type: .default)
            }
        }
    }
    
    private func downloadBook(_ remoteBook: CKRecord) {
        if remoteBook.recordType == Book.ckRecordType {
            if let localBook = self.lookupLocalBook(for: remoteBook) {
                os_log("Updating existing local book with remote record %{public}s", log: .syncCoordinator, type: .info, remoteBook.recordID.recordName)
                let keysPendingUpdate = buffer.compactMap { $0.updates[localBook.objectID] }.joined().compactMap { Book.CKRecordKey(rawValue: $0) }
                localBook.update(from: remoteBook, excluding: keysPendingUpdate)
            } else {
                os_log("Creating new book from remote record %{public}s", log: .syncCoordinator, type: .info, remoteBook.recordID.recordName)
                let book = Book(context: self.syncContext)
                book.update(from: remoteBook, excluding: nil)
            }
        }
    }

    private func lookupLocalBook(for remoteBook: CKRecord) -> Book? {
        let remoteIdLookup = NSManagedObject.fetchRequest(Book.self)
        remoteIdLookup.predicate = Book.withRemoteIdentifier(remoteBook.recordID.recordName)
        remoteIdLookup.fetchLimit = 1
        if let book = (try! syncContext.fetch(remoteIdLookup)).first {
            os_log("Found local book with specified remote identifier %{public}s", log: .syncCoordinator, type: .debug, remoteBook.recordID.recordName)
            return book
        }

        let localIdLookup = NSManagedObject.fetchRequest(Book.self)
        localIdLookup.fetchLimit = 1
        localIdLookup.predicate = Book.candidateBookForRemoteIdentifier(remoteBook.recordID)
        if let book = (try! syncContext.fetch(localIdLookup)).first {
            os_log("Found candidate local book corresponding to remote identifier %{public}s", log: .syncCoordinator, type: .debug, remoteBook.recordID.recordName)
            return book
        }

        return nil
    }

    private func locallyPresentBook(withId id: CKRecord.ID) -> Book? {
        os_log("Fetching local book corresponding to supplied remote identifier %{public}s", log: .syncCoordinator, type: .debug, id.recordName)
        let fetchRequest = NSManagedObject.fetchRequest(Book.self)
        fetchRequest.predicate = Book.withRemoteIdentifier(id.recordName)
        return (try! syncContext.fetch(fetchRequest)).first
    }

}
