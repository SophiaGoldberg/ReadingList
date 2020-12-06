import Foundation
import CloudKit
import os.log
import PersistedPropertyWrapper
import ReadingList_Foundation
import CoreData
import Reachability

@available(iOS 13.0, *)
final class SyncCoordinator { //swiftlint:disable:this type_body_length

    private let persistentStoreCoordinator: NSPersistentStoreCoordinator
    private let orderedTypesToSync: [CKRecordRepresentable.Type]

    public init(persistentStoreCoordinator: NSPersistentStoreCoordinator, orderedTypesToSync: [CKRecordRepresentable.Type]) {
        self.persistentStoreCoordinator = persistentStoreCoordinator
        self.orderedTypesToSync = orderedTypesToSync
    }

    /// Local Core Data transactions which have not yet been confirmed to have been pushed  to CloudKit. The push may have been initiated, but
    /// no response yet received.
    private var unconfirmedLocalTransactions = [NSPersistentHistoryTransaction]()

    private let workQueue = DispatchQueue(label: "SyncEngine.Work", qos: .userInitiated)
    private let cloudOperationQueue = ConcurrentCKQueue()
    private lazy var cloudKitInitialiser = CloudKitInitialiser(cloudOperationQueue: cloudOperationQueue)
    
    private let reachability: Reachability? = {
        do {
            return try Reachability()
        } catch {
            os_log("Reachability could not be initialized: %{public}@", log: .syncCoordinator, type: .error, error.localizedDescription)
            return nil
        }
    }()

    private lazy var syncContext: NSManagedObjectContext = {
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = persistentStoreCoordinator
        context.name = "SyncEngineContext"
        try! context.setQueryGenerationFrom(.current)
        // Ensure that other changes made to the store trump the changes made in this context, so that UI changes don't get overwritten
        // by sync chnages.
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        return context
    }()

    #if DEBUG
    private var debugSimulatorSyncPollTimer: Timer?
    #endif

    public func start() {
        workQueue.async {
            self.cloudKitInitialiser.prepareCloudEnvironment { [weak self] in
                guard let self = self else { return }
                self.workQueue.async {
                    os_log("Cloud environment preparation done", log: .syncCoordinator, type: .default)

                    // Initialise our in-memory transaction retrieval timestamp from the persisted cloudkit commited timestamp
                    self.localTransactionBufferTimestamp = self.lastLocaTransactionTimestampCommittedToCloudKit
                    
                    // Read the local transactions, and observe future changes so we continue to do this ongoing
                    self.readLocalTransactionsToBuffer()
                    NotificationCenter.default.addObserver(forName: .NSPersistentStoreRemoteChange, object: self.persistentStoreCoordinator, queue: nil, using: self.handleStoreChange(notification:))
                    
                    // Monitoring the network reachabiity will allow us to automatically re-do work when network connectivity resumes
                    self.monitorNetworkReachability()

                    // Do some syncing!
                    self.performSync()

                    #if DEBUG && targetEnvironment(simulator)
                    self.debugSimulatorSyncPollTimer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(self.respondToRemoteChangeNotification), userInfo: nil, repeats: true)
                    #endif
                }
            }
        }
    }

    @objc public func respondToRemoteChangeNotification() {
        workQueue.async {
            self.fetchRemoteChanges()
        }
    }

    // MARK: - Network Monitoring
    private func monitorNetworkReachability() {
        guard let reachability = reachability else { return }
        do {
            try reachability.startNotifier()
            NotificationCenter.default.addObserver(self, selector: #selector(networkConnectivityDidChange), name: .reachabilityChanged, object: nil)
        } catch {
            os_log("Error starting reachability notifier: %{public}s", log: .syncCoordinator, type: .error, error.localizedDescription)
        }
    }

    @objc private func networkConnectivityDidChange() {
        guard let reachability = reachability else { preconditionFailure("Reachability was nil in a networkChange callback") }
        os_log("Network connectivity changed to %{public}s", log: .syncCoordinator, type: .info, reachability.connection.description)
        if reachability.connection == .unavailable {
            cloudOperationQueue.suspend()
        } else {
            cloudOperationQueue.resume()
            fetchRemoteChanges()
        }
    }
    
    private func performSync() {
        self.fetchRemoteChanges()
        self.uploadLocalChanges()
    }
    
    
    // MARK: - Upload

    @Persisted("SyncEngine_LocalChangeTimestamp")
    private var lastLocaTransactionTimestampCommittedToCloudKit: Date?

    private var localTransactionBufferTimestamp: Date?

    private lazy var historyFetcher = PersistentHistoryFetcher(context: syncContext, excludeHistoryFromContextWithName: syncContext.name!)

    private func handleStoreChange(notification: Notification) {
        self.syncContext.performAndWait {
            os_log(.info, log: .syncCoordinator, "Merging store changes into syncContext")
            self.syncContext.mergeChanges(fromContextDidSave: notification)
            self.readLocalTransactionsToBuffer()
            self.uploadLocalChanges()
        }
    }

    private func readLocalTransactionsToBuffer() {
        guard let fetchFromWhen = localTransactionBufferTimestamp else {
            os_log(.default, log: .syncCoordinator, "No last retrieved timestamp recorded; cannot extract changes yet")
            return
        }

        let transactions = historyFetcher.fetch(fromDate: fetchFromWhen)
        if let lastTransactionTimestamp = transactions.last?.timestamp {
            self.localTransactionBufferTimestamp = lastTransactionTimestamp
        }
        os_log(.info, log: .syncCoordinator, "Retrieved %d transaction(s) since %{time_t}d", transactions.count, time_t(fetchFromWhen.timeIntervalSince1970))
        
        guard !transactions.isEmpty else { return }

        self.unconfirmedLocalTransactions.append(contentsOf: transactions)
        os_log(.info, log: .syncCoordinator, "%d transaction(s) added to upload buffer", transactions.count)
    }

    private func getAllObjectCkRecords() -> [CKRecord] {
        var ckRecords: [CKRecord] = []
        syncContext.performAndWait {
            for entity in orderedTypesToSync.map({ $0.entity() }) {
                let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest()
                request.entity = entity
                request.returnsObjectsAsFaults = false
                request.includesPropertyValues = true
                request.fetchBatchSize = 100
                let objects = try! syncContext.fetch(request) as! [CKRecordRepresentable]
                ckRecords.append(contentsOf: objects.map { $0.buildCKRecord() })
            }
            syncContext.saveIfChanged()
        }
        return ckRecords
    }

    private func uploadLocalChanges() {
        if lastLocaTransactionTimestampCommittedToCloudKit == nil {
            let now = Date()
            localTransactionBufferTimestamp = now
            let allRecords = getAllObjectCkRecords()
            uploadChanges(records: allRecords, deletions: []) {
                self.lastLocaTransactionTimestampCommittedToCloudKit = now
            }
            return
        }

        guard let transactionToUpload = unconfirmedLocalTransactions.first else {
            os_log("No transactions to process", log: .syncCoordinator, type: .info, unconfirmedLocalTransactions.count)
            return
        }

        func onTransactionUploadCompletion() {
            workQueue.async {
                let removedFirstTransaction = self.unconfirmedLocalTransactions.removeFirst()
                if transactionToUpload != removedFirstTransaction {
                    preconditionFailure("Concurrency error; first transaction in buffer is not the same as the processed transaction")
                }

                self.lastLocaTransactionTimestampCommittedToCloudKit = removedFirstTransaction.timestamp
                os_log("Updated last-pushed local timestamp to %{time_t}d", time_t(removedFirstTransaction.timestamp.timeIntervalSince1970))

                self.uploadLocalChanges()
            }
        }

        guard let changes = transactionToUpload.changes else {
            onTransactionUploadCompletion()
            return
        }
        
        os_log("Processing persistent changes: %@", log: .syncCoordinator, type: .debug, changes.map {
            var base = "\($0.changeType.description) \($0.changedObjectID)"
            if $0.changeType == .update {
                base += " with changed keys [\($0.updatedProperties?.map(\.name).joined(separator: ", ") ?? "")]"
            }
            return base
        }.joined(separator: "\n"))

        syncContext.perform {
            // We want to extract the objects corresponding to the changes to that we can determine the entity types,
            // and then order them according to the orderedTypesToSync property (this will help keep CKReferences intact),
            // before generating our CKRecords.
            let changesAndObjects = changes.filter { $0.changeType != .delete }
                .compactMap { change -> (change: NSPersistentHistoryChange, managedObject: CKRecordRepresentable)? in
                    guard let managedObject = self.syncContext.object(with: change.changedObjectID) as? CKRecordRepresentable else { return nil }
                    return (change, managedObject)
                }
            let changesByEntityType = Dictionary(grouping: changesAndObjects, by: { $0.managedObject.entity })
            
            let ckRecords = self.orderedTypesToSync.compactMap { changesByEntityType[$0.entity()] }
                .flatMap { $0 }
                .compactMap { (change, managedObject) -> CKRecord? in
                    let ckKeysToUpload: [String]?
                    if change.changeType == .update {
                        guard let coreDataKeys = change.updatedProperties?.map(\.name) else { return nil }
                        let ckRecordKeys = coreDataKeys.compactMap { managedObject.ckRecordKey(forLocalPropertyKey: $0) }
                        if ckRecordKeys.isEmpty { return nil }
                        ckKeysToUpload = ckRecordKeys
                    } else {
                        ckKeysToUpload = nil
                    }

                    return managedObject.buildCKRecord(ckRecordKeys: ckKeysToUpload)
                }

            let deletionIDs = changes.filter { $0.changeType == .delete }
                .compactMap { (change: NSPersistentHistoryChange) -> CKRecord.ID? in
                    guard let remoteIdentifier = change.tombstone?[SyncConstants.remoteIdentifierKeyPath] as? String else { return nil }
                    return CKRecord.ID(recordName: remoteIdentifier, zoneID: SyncConstants.zoneID)
                }
            
            // Buiding the CKRecord can in some cases cause updates to the managed object; save if this is the case
            self.syncContext.saveIfChanged()

            self.workQueue.async {
                self.uploadChanges(records: ckRecords, deletions: deletionIDs, completion: onTransactionUploadCompletion)
            }
        }
    }

    private func uploadChanges(records: [CKRecord], deletions: [CKRecord.ID], priority: Operation.QueuePriority = .normal, completion: @escaping () -> Void) {
        if records.isEmpty && deletions.isEmpty {
            completion()
            return
        }

        os_log("Uploading %d record(s) and %d deletion(s)", log: .syncCoordinator, type: .info, records.count, deletions.count)
        let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: deletions)
        operation.perRecordCompletionBlock = { record, error in
            if let error = error {
                os_log("Error uploading CKRecord %@ with keys %@", log: .syncCoordinator, type: .debug, record.recordID.recordName, record.allKeys())
            } else {
                os_log("CKRecord %@ uploaded with keys %@", log: .syncCoordinator, type: .debug, record.recordID.recordName, record.allKeys())
            }
        }
        operation.modifyRecordsCompletionBlock = { [weak self] serverRecords, _, error in
            guard let self = self else { return }

            if let error = error {
                os_log("Failed to upload records", log: .syncCoordinator, type: .error)
                self.handleUploadError(error, records: records, ids: deletions, completion: completion)
            } else {
                os_log("Successfully uploaded %{public}d record(s) and %{public}d deletion(s)", log: .syncCoordinator, type: .info, records.count, deletions.count)
                guard let serverRecords = serverRecords else {
                    os_log("Unexpected nil `serverRecords` in response from CKModifyRecordsOperation operation", log: .syncCoordinator, type: .fault)
                    self.handleUnexpectedResponse()
                    return
                }
                self.updateLocalModelsAfterUpload(with: serverRecords)
                completion()
            }
        }

        operation.savePolicy = .ifServerRecordUnchanged
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
            var refetchIDs = [CKRecord.ID]()
            for record in records {
                if let uploadError = errorsByItemId[record.recordID] as? CKError {
                    if uploadError.code == .serverRecordChanged {
                        refetchIDs.append(record.recordID)
                    } else if uploadError.code == .batchRequestFailed {
                        continue
                    }
                } else {
                    handleUnexpectedResponse()
                    return
                }
            }

            fetchRecords(refetchIDs) {
                self.uploadLocalChanges()
            }
        } else {
            if cloudOperationQueue.suspendCloudInterop(dueTo: error) {
                self.uploadChanges(records: records, deletions: ids, completion: completion)
            } else {
                os_log("Error is not recoverable: %{public}@", log: .syncCoordinator, type: .error, String(describing: error))
                handleUnexpectedResponse()
            }
        }
    }

    private func updateLocalModelsAfterUpload(with records: [CKRecord]) {
        guard !records.isEmpty else { return }
        syncContext.performAndWait {
            for record in records {
                saveRecordDataLocally(ckRecord: record, option: .storeSystemFieldsOnly)
            }
            syncContext.saveAndLogIfErrored()
            os_log("Completed updating %d local model(s) after upload", log: .syncCoordinator, type: .default, records.count)
        }
    }

    // MARK: - Remote change tracking

    @Persisted(archivedDataKey: "SyncEngine_SeverChangeToken")
    private var privateChangeToken: CKServerChangeToken?

    private func fetchRemoteChanges() {
        var changedRecords: [CKRecord] = []
        var deletedRecordIDs: [CKRecordIdentity] = []

        let operation = CKFetchRecordZoneChangesOperation()
        let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration(
            previousServerChangeToken: privateChangeToken,
            resultsLimit: nil,
            desiredKeys: nil
        )
        operation.configurationsByRecordZoneID = [SyncConstants.zoneID: config]
        operation.recordZoneIDs = [SyncConstants.zoneID]
        operation.fetchAllChanges = true

        var newChangeToken: CKServerChangeToken?
        operation.recordZoneChangeTokensUpdatedBlock = { _, changeToken, _ in
            guard let changeToken = changeToken else { return }
            newChangeToken = changeToken
        }

        operation.recordZoneFetchCompletionBlock = { [weak self] _, token, _, _, error in
            guard let self = self else { return }

            if let error = error as? CKError {
                os_log("Failed to fetch record zone changes: %{public}@", log: .syncCoordinator, type: .error, String(describing: error))

                if error.code == .changeTokenExpired {
                    os_log("Change token expired, resetting token and trying again", log: .syncCoordinator, type: .error)
                    self.privateChangeToken = nil
                    self.fetchRemoteChanges()
                } else {
                    if self.cloudOperationQueue.suspendCloudInterop(dueTo: error) {
                        self.fetchRemoteChanges()
                    }
                }
            } else {
                os_log("Commiting new change token", log: .syncCoordinator, type: .debug)

                self.privateChangeToken = token
            }
        }

        operation.recordChangedBlock = { changedRecords.append($0) }

        operation.recordWithIDWasDeletedBlock = { recordID, recordType in
            deletedRecordIDs.append(CKRecordIdentity(ID: recordID, type: recordType))
        }

        operation.fetchRecordZoneChangesCompletionBlock = { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                os_log("Failed to fetch record zone changes: %{public}@", log: .syncCoordinator, type: .error, String(describing: error))

                if self.cloudOperationQueue.suspendCloudInterop(dueTo: error) {
                    self.fetchRemoteChanges()
                }
            } else {
                os_log("Finished fetching record zone changes", log: .syncCoordinator, type: .info)
                self.commitServerChangesToDatabase(with: changedRecords, deletedRecordIDs: deletedRecordIDs)
                self.privateChangeToken = newChangeToken
            }
        }

        operation.queuePriority = .high
        cloudOperationQueue.addOperation(operation)
    }

    private func fetchRecords(_ recordIDs: [CKRecord.ID], completion: @escaping () -> Void) {
        let operation = CKFetchRecordsOperation(recordIDs: recordIDs)
        operation.fetchRecordsCompletionBlock = { records, error in
            if let error = error {
                os_log("Failed to fetch records: %{public}@", log: .syncCoordinator, type: .error, String(describing: error))

                if self.cloudOperationQueue.suspendCloudInterop(dueTo: error) {
                    self.fetchRecords(recordIDs, completion: completion)
                } else {
                    os_log("WHAT TO DO HERE?", log: .syncCoordinator, type: .fault)
                }
                return
            }

            guard let records = records else {
                self.handleUnexpectedResponse()
                return
            }
            self.commitServerChangesToDatabase(with: Array(records.values), deletedRecordIDs: [])
            completion()
        }

        operation.queuePriority = .high
        cloudOperationQueue.addOperation(operation)
    }

    private func commitServerChangesToDatabase(with changedRecords: [CKRecord], deletedRecordIDs: [CKRecordIdentity]) {
        guard !changedRecords.isEmpty || !deletedRecordIDs.isEmpty else {
            os_log("Finished record zone changes fetch with no changes", log: .syncCoordinator, type: .info)
            return
        }

        os_log("Will commit %d changed record(s) and %d deleted record(s) to the database", log: .syncCoordinator, type: .info, changedRecords.count, deletedRecordIDs.count)

        workQueue.async {
            self.syncContext.performAndWait {
                for record in changedRecords {
                    self.saveRecordDataLocally(ckRecord: record, option: .createIfNotFound)
                }
                for deletedID in deletedRecordIDs {
                    self.localEntity(forIdentifier: deletedID)?.delete()
                }
                self.syncContext.saveAndLogIfErrored()
                os_log("Completed updating local model(s) after download", log: .syncCoordinator, type: .default)
            }
        }
    }

    private func saveRecordDataLocally(ckRecord: CKRecord, option: DownloadOption?) {
        switch ckRecord.recordType {
        case Book.ckRecordType: saveRecordDataLocally(Book.self, ckRecord, option: option)
        case List.ckRecordType: saveRecordDataLocally(List.self, ckRecord, option: option)
        case ListItem.ckRecordType: saveRecordDataLocally(ListItem.self, ckRecord, option: option)
        default:
            os_log("Unexpected record type during download: %{public}s", log: .syncCoordinator, type: .error, ckRecord.recordType)
        }
    }

    private func localEntity(forIdentifier remoteIdentifier: CKRecordIdentity) -> NSManagedObject? {
        switch remoteIdentifier.type {
        case Book.ckRecordType: return lookupLocalObject(ofType: Book.self, withIdentifier: remoteIdentifier.ID.recordName)
        case List.ckRecordType: return lookupLocalObject(ofType: List.self, withIdentifier: remoteIdentifier.ID.recordName)
        case ListItem.ckRecordType: return lookupLocalObject(ofType: ListItem.self, withIdentifier: remoteIdentifier.ID.recordName)
        default:
            os_log("Unexpected record type supplied: %{public}s", log: .syncCoordinator, type: .error, remoteIdentifier.type)
            return nil
        }
    }

    enum DownloadOption {
        case storeSystemFieldsOnly
        case createIfNotFound
    }

    private func saveRecordDataLocally<LocalType>(_ type: LocalType.Type, _ ckRecord: CKRecord, option: DownloadOption?) where LocalType: CKRecordRepresentable {
        if let localObject: LocalType = lookupLocalObject(for: ckRecord) {
            if localObject.isDeleted {
                os_log("Local %{public}s was deleted; skipping local update", log: .syncCoordinator, type: .default, ckRecord.recordType)
                return
            }

            os_log("Updating existing local %{public}s with remote record %{public}s", log: .syncCoordinator, type: .info, ckRecord.recordType, ckRecord.recordID.recordName)
            if option == .storeSystemFieldsOnly {
                localObject.setSystemAndIdentifierFields(from: ckRecord)
                os_log("Updated system fields for CKRecord %{public}s on object %{public}s", log: .syncCoordinator, type: .info, ckRecord.recordID.recordName, localObject.objectID.uriRepresentation().relativeString)
            } else {
                let keysPendingUpdate = unconfirmedLocalTransactions.compactMap { $0.changes }
                    .flatMap { $0 }
                    .filter { $0.changeType == .update && $0.changedObjectID == localObject.objectID }
                    .compactMap { $0.updatedProperties }
                    .flatMap { $0 }
                    .map { $0.name }
                    .distinct()

                localObject.update(from: ckRecord, excluding: keysPendingUpdate)
                os_log("Updated metadata for CKRecord %{public}s on object %{public}s", log: .syncCoordinator, type: .info, ckRecord.recordID.recordName, localObject.objectID.uriRepresentation().relativeString)
            }
        } else if option == .createIfNotFound {
            os_log("No local %{public}s found for %{public}s with record name %{public}s", log: .syncCoordinator, type: .default, ckRecord.recordType, ckRecord.recordType, ckRecord.recordID.recordName)
            let newItem = LocalType(context: syncContext)
            newItem.update(from: ckRecord, excluding: nil)
        }
    }

    func lookupLocalObject<LocalType>(for remoteRecord: CKRecord) -> LocalType? where LocalType: CKRecordRepresentable {
        let recordName = remoteRecord.recordID.recordName
        if let localItem = lookupLocalObject(ofType: LocalType.self, withIdentifier: recordName) {
            os_log("Found local %{public}s with specified remote identifier %{public}s", log: .syncCoordinator, type: .debug, LocalType.ckRecordType, recordName)
            return localItem
        }
        os_log("No local %{public}s with specified remote identifier %{public}s; looking for other candidates", log: .syncCoordinator, type: .debug, LocalType.ckRecordType, recordName)

        let localIdLookup = LocalType.fetchRequest()
        localIdLookup.fetchLimit = 1
        localIdLookup.predicate = NSCompoundPredicate(
            andPredicateWithSubpredicates: [
                NSPredicate(format: "%K == NULL", SyncConstants.remoteIdentifierKeyPath),
                LocalType.matchCandidateItemForRemoteRecord(remoteRecord)
            ]
        )

        if let localItem = (try! syncContext.fetch(localIdLookup)).first as? LocalType {
            os_log("Found candidate local %{public}s for remote record %{public}s using metadata", log: .syncCoordinator, type: .debug,
                   LocalType.ckRecordType, recordName)
            return localItem
        }

        os_log("No local %{public}s found for remote record %{public}s", log: .syncCoordinator, type: .debug, LocalType.ckRecordType, recordName)
        return nil
    }

    func lookupLocalObject<LocalType>(ofType type: LocalType.Type, withIdentifier recordName: String) -> LocalType? where LocalType: CKRecordRepresentable {
        let fetchRequest = LocalType.fetchRequest()
        fetchRequest.predicate = LocalType.remoteIdentifierPredicate(recordName)
        fetchRequest.fetchLimit = 1
        return (try! syncContext.fetch(fetchRequest)).first as? LocalType
    }
}

extension NSPersistentHistoryChangeType {
    var description: String {
        switch self {
        case .insert: return "Insert"
        case .update: return "Update"
        case .delete: return "Delete"
        @unknown default: return "Unknown"
        }
    }
}
