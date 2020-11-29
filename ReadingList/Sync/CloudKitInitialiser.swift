import Foundation
import CloudKit
import PersistedPropertyWrapper
import os.log

class CloudKitInitialiser {
    private let cloudOperationQueue: ConcurrentCKQueue

    init(cloudOperationQueue: ConcurrentCKQueue) {
        self.cloudOperationQueue = cloudOperationQueue
    }

    @Persisted("SyncEngine_CustomZoneCreated", defaultValue: false)
    private var createdCustomZone: Bool

    @Persisted("SyncEngine_PrivateSubscriptionKey", defaultValue: false)
    private var createdPrivateSubscription: Bool

    static let privateSubscriptionId = "\(SyncConstants.zoneID.zoneName).subscription"

    func prepareCloudEnvironment(completion: @escaping () -> Void) {
        self.createCustomZoneIfNeeded()
        self.cloudOperationQueue.operationQueue.waitUntilAllOperationsAreFinished()
        guard self.createdCustomZone else { return }

        self.createPrivateSubscriptionsIfNeeded()
        self.cloudOperationQueue.operationQueue.waitUntilAllOperationsAreFinished()
        guard self.createdPrivateSubscription else { return }

        completion()
    }

    private func createCustomZoneIfNeeded() {
        guard !createdCustomZone else {
            os_log("Already have custom zone, skipping creation but checking if zone really exists", log: .syncCoordinator, type: .debug)
            checkCustomZone()
            return
        }

        os_log("Creating CloudKit zone %@", log: .syncCoordinator, type: .info, SyncConstants.zoneID)

        let zone = CKRecordZone(zoneID: SyncConstants.zoneID)
        let operation = CKModifyRecordZonesOperation(recordZonesToSave: [zone], recordZoneIDsToDelete: nil)

        operation.modifyRecordZonesCompletionBlock = { [weak self] _, _, error in
            guard let self = self else { return }

            if let error = error {
                os_log("Failed to create custom CloudKit zone: %{public}@", log: .syncCoordinator, type: .error, String(describing: error))
                if self.cloudOperationQueue.suspendCloudInterop(dueTo: error) {
                    self.createCustomZoneIfNeeded()
                }
            } else {
                os_log("Zone created successfully", log: .syncCoordinator, type: .info)
                self.createdCustomZone = true
            }
        }

        operation.qualityOfService = .userInitiated
        cloudOperationQueue.addOperation(operation)
    }

    private func checkCustomZone() {
        let operation = CKFetchRecordZonesOperation(recordZoneIDs: [SyncConstants.zoneID])
        operation.fetchRecordZonesCompletionBlock = { [weak self] ids, error in
            guard let self = self else { return }

            if let error = error {
                os_log("Failed to check for custom zone existence: %{public}@", log: .syncCoordinator, type: .error, String(describing: error))

                if self.cloudOperationQueue.suspendCloudInterop(dueTo: error) {
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
        cloudOperationQueue.addOperation(operation)
    }

    private func createPrivateSubscriptionsIfNeeded() {
        guard !createdPrivateSubscription else {
            os_log("Already subscribed to private database changes, skipping subscription but checking if it really exists", log: .syncCoordinator, type: .debug)
            checkSubscription()
            return
        }

        let subscription = CKRecordZoneSubscription(zoneID: SyncConstants.zoneID, subscriptionID: Self.privateSubscriptionId)

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: nil)
        operation.qualityOfService = .userInitiated

        operation.modifySubscriptionsCompletionBlock = { [weak self] _, _, error in
            guard let self = self else { return }

            if let error = error {
                os_log("Failed to create private CloudKit subscription: %{public}@",
                       log: .syncCoordinator,
                       type: .error,
                       String(describing: error))

                if self.cloudOperationQueue.suspendCloudInterop(dueTo: error) {
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
        let operation = CKFetchSubscriptionsOperation(subscriptionIDs: [Self.privateSubscriptionId])

        operation.fetchSubscriptionCompletionBlock = { [weak self] ids, error in
            guard let self = self else { return }

            if let error = error {
                os_log("Failed to check for private zone subscription existence: %{public}@", log: .syncCoordinator, type: .error, String(describing: error))

                if self.cloudOperationQueue.suspendCloudInterop(dueTo: error) {
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
        cloudOperationQueue.addOperation(operation)
    }
}
