import Foundation
import CoreData
import os.log

@available(iOS 13.0, *)
struct PersistentHistoryFetcher {
    let context: NSManagedObjectContext

    /// Fetches transactions created by other contexts
    func fetch(fromToken token: NSPersistentHistoryToken) -> [NSPersistentHistoryTransaction] {
        let fetchRequest = createFetchRequest(fromToken: token)
        return fetchHistory(fetchRequest)
    }

    func fetch(fromDate date: Date) -> [NSPersistentHistoryTransaction] {
        let fetchRequest = createFetchRequest(fromDate: date)
        return fetchHistory(fetchRequest)
    }

    private func fetchHistory(_ fetchRequest: NSPersistentHistoryChangeRequest) -> [NSPersistentHistoryTransaction] {
        let historyResult: NSPersistentHistoryResult
        do {
            guard let historyExecutionResult = try context.execute(fetchRequest) as? NSPersistentHistoryResult else {
                fatalError("Unexpected return type when fetching transaction history")
            }
            historyResult = historyExecutionResult
        } catch {
            os_log(.error, "Failed to fetch transaction history with token")
            return []
        }
        return historyResult.result as! [NSPersistentHistoryTransaction]
    }

    private func createFetchRequest(fromToken token: NSPersistentHistoryToken) -> NSPersistentHistoryChangeRequest {
        let historyFetchRequest = NSPersistentHistoryChangeRequest.fetchHistory(after: token)
        historyFetchRequest.fetchRequest = fetchRequest()
        return historyFetchRequest
    }

    private func createFetchRequest(fromDate date: Date) -> NSPersistentHistoryChangeRequest {
        let historyFetchRequest = NSPersistentHistoryChangeRequest.fetchHistory(after: date)
        historyFetchRequest.fetchRequest = fetchRequest()
        return historyFetchRequest
    }

    private func fetchRequest() -> NSFetchRequest<NSFetchRequestResult>? {
        guard let fetchRequest = NSPersistentHistoryTransaction.fetchRequest else {
            os_log(.error, "NSPersistentHistoryTransaction.fetchRequest was nil")
            return nil
        }

        if let contextName = context.name {
            // Only look at transactions from our current context
            fetchRequest.predicate = NSPredicate(format: "%K != %@", #keyPath(NSPersistentHistoryTransaction.contextName), contextName)
        }
        return fetchRequest
    }

    func deleteHistory(beforeToken token: NSPersistentHistoryToken) {
        let deletionRequest = NSPersistentHistoryChangeRequest.deleteHistory(before: token)
        do {
            try context.execute(deletionRequest)
        } catch {
            assertionFailure("Failed to delete persistent history")
        }
    }
}
