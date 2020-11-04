#if DEBUG

import Foundation
import CoreData
import PersistedPropertyWrapper

class Debug {

    @Persisted("showSortNumber", defaultValue: false)
    static var showSortNumber: Bool

    private static let screenshotsCommand = "--UITests_Screenshots"

    static func initialiseSettings() {
        if CommandLine.arguments.contains("--reset") {
            UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
            NSPersistentStoreCoordinator().destroyAndDeleteStore(at: URL.applicationSupport.appendingPathComponent(PersistentStoreManager.storeFileName))
        }
    }

    static func initialiseData() {
        if CommandLine.arguments.contains("--UITests_PopulateData") {
            loadData(downloadImages: CommandLine.arguments.contains(screenshotsCommand)) {
                if CommandLine.arguments.contains("--UITests_DeleteLists") {
                    PersistentStoreManager.delete(type: List.self)
                }
            }
        }
    }

    static func loadData(downloadImages: Bool, _ completion: (() -> Void)?) {
        let csvPath = Bundle.main.url(forResource: "examplebooks", withExtension: "csv")!
        let settings = BookCSVImportSettings(downloadCoverImages: downloadImages)
        BookCSVImporter(format: .readingList, settings: settings).startImport(fromFileAt: csvPath) { result in
            guard case .success = result else { preconditionFailure("Error in CSV file") }
            DispatchQueue.main.async {
                completion?()
            }
        }
    }
}

#endif
