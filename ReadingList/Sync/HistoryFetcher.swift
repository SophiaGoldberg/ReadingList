import Foundation
import CoreData

@available(iOS 13.0, *)
struct PersistentHistoryFetcher {
    let context: NSManagedObjectContext

    /// Fetches transactions created by other contexts
    func fetch(fromToken token: NSPersistentHistoryToken) -> [NSPersistentHistoryTransaction] {
        let fetchRequest = createFetchRequest(fromToken: token)
        return fetchHistory(fetchRequest)
    }

    func fetchLatest() -> NSPersistentHistoryTransaction? {
        let fetchRequest = createFetchRequestForLatest()
        return fetchHistory(fetchRequest).first
    }
    
    private func fetchHistory(_ fetchRequest: NSPersistentHistoryChangeRequest) -> [NSPersistentHistoryTransaction] {
        let historyResult: NSPersistentHistoryResult
        do {
            guard let historyExecutionResult = try context.execute(fetchRequest) as? NSPersistentHistoryResult else {
                fatalError("Unexpected return type when fetching transaction history")
            }
            historyResult = historyExecutionResult
        } catch {
            assertionFailure("Failure while fetching transaction history")
            return []
        }
        guard let history = historyResult.result as? [NSPersistentHistoryTransaction] else {
            fatalError("Unexpected result type when fetching transaction history")
        }

        return history
    }

    private func createFetchRequest(fromToken token: NSPersistentHistoryToken) -> NSPersistentHistoryChangeRequest {
        let historyFetchRequest = NSPersistentHistoryChangeRequest.fetchHistory(after: token)

        guard let fetchRequest = NSPersistentHistoryTransaction.fetchRequest else { preconditionFailure() }
        if let contextName = context.name {
            // Only look at transactions not from our current context
            fetchRequest.predicate = NSPredicate(format: "%K != %@", #keyPath(NSPersistentHistoryTransaction.contextName), contextName)
        }
        historyFetchRequest.fetchRequest = fetchRequest

        return historyFetchRequest
    }
    
    private func createFetchRequestForLatest() -> NSPersistentHistoryChangeRequest {
        guard let fetchRequest = NSPersistentHistoryTransaction.fetchRequest else { preconditionFailure() }
        fetchRequest.fetchLimit = 1
        fetchRequest.sortDescriptors = [NSSortDescriptor(#keyPath(NSPersistentHistoryTransaction.timestamp), ascending: false)]
        return NSPersistentHistoryChangeRequest.fetchHistory(withFetch: fetchRequest)
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
