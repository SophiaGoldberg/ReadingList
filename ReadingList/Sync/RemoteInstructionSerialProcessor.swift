import Foundation
import CloudKit
import CoreData
import os.log
import PersistedPropertyWrapper
import ReadingList_Foundation

class RemoteInstructionSerialProcessor: RemotePushProcessorDelegate, RemotePullProcessorDelegate {
    let remote: BookCloudKitRemote
    private let dispatchQueue = DispatchQueue(label: "remote-instruction-serial-processor", qos: .userInitiated)
    private let syncContext: NSManagedObjectContext
    private var pendingPushWork = Queue<LocalChangeRemoteUpdateInstruction>()
    private lazy var remotePushProcessor = RemotePushProcessor(remote: remote, syncContext: syncContext, delegate: self)
    private lazy var remotePullProcessor = RemotePullProcessor(remote: remote, syncContext: syncContext, delegate: self)

    init(remote: BookCloudKitRemote, syncContext: NSManagedObjectContext) {
        self.remote = remote
        self.syncContext = syncContext
    }

    /// A queue of remote operations which have been added to the CloudKit database. Each operation in the queue is dependent on the operation in front of it.
    /// Operations are removed from the queue when complete. The operation at the front of the queue should therefore only depend on completed operations.
    private var remoteOperationQueue = Queue<Operation>()

    func requestPush(_ remoteUpdate: LocalChangeRemoteUpdateInstruction) {
        dispatchQueue.async {
            self.pendingPushWork.enqueue(remoteUpdate)
            let pushOperation = self.remotePushProcessor.pushOperation(remoteUpdate)
            if let operationQueueFront = self.remoteOperationQueue.front {
                pushOperation.addDependency(operationQueueFront)
            }
            self.remoteOperationQueue.enqueue(pushOperation)
            self.remote.scheduleOperation(pushOperation)
        }
    }

    func onPushSuccess(operationName: String, remoteUpdate: LocalChangeRemoteUpdateInstruction) {
        self.dispatchQueue.sync {
            guard let dequeuedOperation = self.remoteOperationQueue.dequeue() else {
                os_log(.fault, "Error in Push operation management: no queued operations present during completion of an operation")
                assertionFailure("Error in Push operation management: no queued operations present during completion of an operation")
                return
            }
            assert(dequeuedOperation.name == operationName)

            guard let dequeuedPushWork = self.pendingPushWork.dequeue() else {
                os_log(.fault, "Error in Push operation management: no queued push work present during completion of an operation")
                assertionFailure("Error in Push operation management: no queued push work present during completion of an operation")
                return
            }
            assert(dequeuedPushWork == remoteUpdate)
        }
    }

    func pendingUpdateRecordKeys(for id: String) -> Set<String>? {
        dispatchQueue.sync {
            if pendingPushWork.items.isEmpty { return nil }
            var result = Set<String>()
            for pendingWork in pendingPushWork.items {
                guard let changedKeys = pendingWork.updates[id]?.changedKeys() else { continue }
                result.formUnion(changedKeys)
            }
            return result
        }
    }

    func requestPull() {
        dispatchQueue.async {
            let pullOperation = self.remotePullProcessor.pullOperation()
            if let operationQueueFront = self.remoteOperationQueue.front {
                pullOperation.addDependency(operationQueueFront)
            }
            self.remoteOperationQueue.enqueue(pullOperation)
            self.remote.scheduleOperation(pullOperation)
        }
    }

    func onPullSuccess(operationName: String) {
        self.dispatchQueue.sync {
            guard let dequeuedOperation = self.remoteOperationQueue.dequeue() else {
                os_log(.fault, "Error in Pull operation management: no queued operations present during completion of an operation")
                assertionFailure("Error in Pull operation management: no queued operations present during completion of an operation")
                return
            }
            assert(dequeuedOperation.name == operationName)
        }
    }
}
