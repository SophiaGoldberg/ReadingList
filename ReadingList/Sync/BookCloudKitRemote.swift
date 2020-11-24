import Foundation
import CoreData
import CloudKit
import PersistedPropertyWrapper
import os.log

class BookCloudKitRemote {
    let bookZoneName = "BookZone"

    private let userRecordNameKey = "CK_UserRecordName"

    private(set) var userRecordName: String!
    private(set) var bookZoneID: CKRecordZone.ID!

    @Persisted("bookZoneAndSubscriptionCreated", defaultValue: false)
    var bookZoneAndSubscriptionCreated: Bool

    var privateCloudDatabase: CKDatabase {
        return CKContainer.default().privateCloudDatabase
    }

    var isInitialised: Bool {
        return bookZoneID != nil
    }

    func initialise(completion: @escaping (Error?) -> Void) {
        if let userRecordName = UserDefaults.standard.string(forKey: userRecordNameKey) {
            createZoneAndSubscription(userRecordName: userRecordName, completion: completion)
        } else {
            CKContainer.default().fetchUserRecordID { ckRecordID, error in
                if let error = error {
                    completion(error)
                } else {
                    UserDefaults.standard.set(ckRecordID!.recordName, forKey: self.userRecordNameKey)
                    self.createZoneAndSubscription(userRecordName: ckRecordID!.recordName, completion: completion)
                }
            }
        }
    }

    private func createZoneAndSubscription(userRecordName: String, completion: @escaping (Error?) -> Void) {
        self.userRecordName = userRecordName
        self.bookZoneID = CKRecordZone.ID(zoneName: bookZoneName, ownerName: userRecordName)
        if bookZoneAndSubscriptionCreated {
            os_log(.info, "Book zone and subscription already exist (apparently)")
            completion(nil)
            return
        }

        // Ensure the book zone exists. We're not calling the error callback here, since the subsequent operation is
        // not cancelled if this one fails. If the zone fails to get created, then the second operation will fail too.
        let bookZone = CKRecordZone(zoneID: bookZoneID)
        let createZoneOperation = CKModifyRecordZonesOperation(recordZonesToSave: [bookZone], recordZoneIDsToDelete: nil)
        createZoneOperation.modifyRecordZonesCompletionBlock = { _, _, error in
            if let error = error {
                os_log("Book record zone creation failed: %{public}s", type: .error, error.localizedDescription)
            } else {
                os_log("Record zone created", type: .info)
            }
        }
        createZoneOperation.qualityOfService = .userInitiated
        privateCloudDatabase.add(createZoneOperation)

        // Create a subscribe and to it
        let subscription = CKRecordZoneSubscription(zoneID: bookZone.zoneID, subscriptionID: "BookChanges")
        subscription.notificationInfo = CKSubscription.NotificationInfo(shouldSendContentAvailable: true)

        let modifySubscriptionOperation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: nil)
        modifySubscriptionOperation.addDependency(createZoneOperation)
        modifySubscriptionOperation.qualityOfService = .userInitiated
        modifySubscriptionOperation.modifySubscriptionsCompletionBlock = { [weak self] _, _, error in
            if let error = error {
                os_log("Book record zone subscription creation failed: %{public}s", type: .error, error.localizedDescription)
                completion(error)
            } else {
                os_log("Record zone subscription created", type: .info)
                self?.bookZoneAndSubscriptionCreated = true
                completion(nil)
            }
        }
        privateCloudDatabase.add(modifySubscriptionOperation)
    }

    func fetchRecordChangesOperation(changeToken: CKServerChangeToken?, recordDeletion: @escaping (CKRecord.ID) -> Void,
                                     recordChange: @escaping (CKRecord) -> Void, changeTokenUpdate: @escaping (CKServerChangeToken) -> Void,
                                     completion: @escaping (Error?) -> Void) -> CKDatabaseOperation {
        if changeToken == nil {
            os_log("Fetching record changes without change token", type: .info)
        } else {
            os_log("Fetching record changes with change token", type: .info)
        }

        let options = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        if let changeToken = changeToken {
            options.previousServerChangeToken = changeToken
        }

        let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [bookZoneID], configurationsByRecordZoneID: [bookZoneID: options])
        operation.qualityOfService = .userInitiated

        operation.recordChangedBlock = { record in
            recordChange(record)
        }
        operation.recordWithIDWasDeletedBlock = { recordID, _ in
            recordDeletion(recordID)
        }
        operation.recordZoneChangeTokensUpdatedBlock = { _, changeToken, _ in
            os_log("Record fetch change token updated", type: .info)
            if let changeToken = changeToken { changeTokenUpdate(changeToken) }
        }
        operation.recordZoneFetchCompletionBlock = { _, changeToken, _, moreComing, error in
            if let changeToken = changeToken {
                changeTokenUpdate(changeToken)
            }
            if !moreComing {
                os_log("Record fetch batch operation complete", type: .info)
                completion(error)
            }
        }
        return operation
    }

    func upload(_ records: [CKRecord], dependentOperation: Operation? = nil, completion: @escaping (Error?) -> Void) -> Operation {
        upload(recordsToSave: records, recordsToDelete: [], dependentOperation: dependentOperation, completion: completion)
    }

    func remove(_ recordIDs: [CKRecord.ID], dependentOperation: Operation? = nil, completion: @escaping (Error?) -> Void) {
        upload(recordsToSave: [], recordsToDelete: recordIDs, dependentOperation: dependentOperation, completion: completion)
    }

    @discardableResult
    func upload(recordsToSave: [CKRecord]?, recordsToDelete: [CKRecord.ID]?, dependentOperation: Operation? = nil, completion: @escaping (Error?) -> Void) -> Operation {
        let operation = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: recordsToDelete)
        operation.qualityOfService = .userInitiated
        if let dependentOperation = dependentOperation {
            operation.addDependency(dependentOperation)
        }
        operation.modifyRecordsCompletionBlock = { _, _, error in
            completion(error)
        }
        privateCloudDatabase.add(operation)
        return operation
    }

    func uploadOperation(recordsToSave: [CKRecord]?, recordsToDelete: [CKRecord.ID]?, completion: @escaping (Error?) -> Void) -> CKDatabaseOperation {
        let operation = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: recordsToDelete)
        operation.qualityOfService = .userInitiated
        operation.modifyRecordsCompletionBlock = { _, _, error in
            completion(error)
        }
        return operation
    }

    func scheduleOperation(_ operation: CKDatabaseOperation) {
        privateCloudDatabase.add(operation)
    }
}
