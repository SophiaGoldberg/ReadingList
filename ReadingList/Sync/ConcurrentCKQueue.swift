import Foundation
import CloudKit
import os.log

class ConcurrentCKQueue {
    init() { }

    private let cloudQueue = DispatchQueue(label: "SyncEngine.CloudQueue", qos: .userInitiated)
    private let container = CKContainer.default()
    private lazy var privateDatabase = container.privateCloudDatabase

    /// A single-concurrent-operation queue used to manage cloud-interation operations.
    lazy var operationQueue: OperationQueue = {
        let operationQueue = OperationQueue()
        operationQueue.underlyingQueue = cloudQueue
        operationQueue.name = "SyncEngine.Cloud"
        operationQueue.maxConcurrentOperationCount = 1
        return operationQueue
    }()

    func addOperation(_ operation: CKDatabaseOperation, qos: QualityOfService = .userInitiated) {
        operation.database = privateDatabase
        operation.qualityOfService = qos
        operationQueue.addOperation(operation)
    }

    func suspendCloudInterop(dueTo error: Error) -> Bool {
        guard let effectiveError = error as? CKError else { return false }
        guard let retryDelay = effectiveError.retryAfterSeconds else {
            os_log("Error is not recoverable", log: .syncCoordinator, type: .error)
            return false
        }

        os_log("Error is recoverable. Will retry after %{public}f seconds", log: .syncCoordinator, type: .error, retryDelay)
        self.operationQueue.isSuspended = true
        // TODO Wrong queue, really
        cloudQueue.asyncAfter(deadline: .now() + retryDelay) {
            self.operationQueue.isSuspended = false
        }

        return true
    }
}
