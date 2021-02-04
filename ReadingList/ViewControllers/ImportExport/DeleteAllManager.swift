import Foundation
import UIKit
import CoreData
import os.log

class DeleteAllManager {
    /// A global reference to a shared instance, which can persist while switching out the window root view controller..
    static let shared = DeleteAllManager()

    /// Switch to the deletion screen, delete the persistent store, and then switch back to the app's normal root controller when complete.
    func deleteAll() {
        guard let window = AppDelegate.shared.window else { fatalError("No window available when attempting to delete all") }
        os_log("Replacing window root view controller with deletion placeholder view")
        window.rootViewController = DeleteAll()

        DispatchQueue.global(qos: .userInitiated).async {
            os_log("Destroying persistent store")
            PersistentStoreManager.container.persistentStoreCoordinator.destroyAndDeleteStore(at: PersistentStoreManager.storeLocation)

            os_log("Initialising persistent store")
            try! PersistentStoreManager.initalisePersistentStore {

                os_log("Persistent store initialised; replacing window root view controller")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    let newTabBarController = TabBarController()
                    window.rootViewController = newTabBarController
                    newTabBarController.presentImportExportView(importUrl: nil)
                }
            }
        }
    }
}
