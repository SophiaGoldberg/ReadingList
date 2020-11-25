import CloudKit
import CoreData
import Foundation
import os.log
import ReadingList_Foundation

class InitialUpstreamLoader {
    let syncContext: NSManagedObjectContext
    let remote: BookCloudKitRemote

    init(syncContext: NSManagedObjectContext, remote: BookCloudKitRemote) {
        self.syncContext = syncContext
        self.remote = remote
    }

    var batchSize: Int {
        #if DEBUG
        return 5
        #else
        return 200
        #endif
    }

    func performInitialUpstreamLoad(onCompletion: @escaping () -> Void) {
        syncContext.perform { [weak self] in
            guard let self = self else { return }
            let fetchRequest = Book.fetchRequest(Book.self, batch: self.batchSize)
            let books = try! self.syncContext.fetch(fetchRequest)
            guard !books.isEmpty else {
                onCompletion()
                return
            }

            var operation: Operation?
            for (index, batch) in books.chunked(by: self.batchSize).enumerated() {
                os_log(.default, log: .syncUpstream, "Uploading %d inserts for batch %d", batch.count, index)
                let ckRecords = batch.map { $0.recordForInsert(into: self.remote.bookZoneID) }
                let uploadOperation = self.remote.upload(recordsToSave: ckRecords, recordsToDelete: nil, dependentOperation: operation) { err in
                    os_log(.info, log: .syncUpstream, "Upload operation of batch %d (%d records) completed %s", index, batch.count, err == nil ? "" : "(errored)")
                }
                operation = uploadOperation
            }
            os_log(.default, log: .syncUpstream, "All remote inserts scheduled")
        }
    }
}
