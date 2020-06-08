import Foundation
import SwiftyStoreKit
import SVProgressHUD
import os.log
import CoreData
import ReadingList_Foundation

class LaunchManager {

    var window: UIWindow!
    var storeMigrationFailed = false

    /**
     Performs any required initialisation immediately post after the app has launched.
     This must be called prior to any other initialisation actions.
    */
    func initialise(window: UIWindow) {
        self.window = window

        #if DEBUG
        Debug.initialiseSettings()
        #endif
        UserEngagement.initialiseUserAnalytics()
        SVProgressHUD.setDefaults()
        SwiftyStoreKit.completeTransactions()
    }

    func handleApplicationDidBecomeActive() {
        UserEngagement.onAppOpen()

        if storeMigrationFailed {
            presentIncompatibleDataAlert()
        }
    }

    func extractRelevantLaunchOptions(_ launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> LaunchOptions {
        let quickAction: QuickAction?
        if let shortcut = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
            quickAction = QuickAction(rawValue: shortcut.type)
        } else {
            quickAction = nil
        }

        let csvFileUrl: URL?
        if let url = launchOptions?[.url] as? URL {
            csvFileUrl = url.isFileURL && url.pathExtension == "csv" ? url : nil
        } else {
            csvFileUrl = nil
        }

        return LaunchOptions(url: csvFileUrl, quickAction: quickAction)
    }

    /**
     Initialises the persistent store on a background thread. If successfully completed, the main thread
     will instantiate the root view controller, perform some other app-startup work. If the persistent store
     fails to initialise, then an error alert is presented to the user.
     */
    func initialisePersistentStore(_ options: LaunchOptions? = nil) {
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                try PersistentStoreManager.initalisePersistentStore {
                    os_log("Persistent store loaded", type: .info)
                    DispatchQueue.main.async {
                        self.initialiseAfterPersistentStoreLoad()
                        if let options = options {
                            self.handleLaunchOptions(options)
                        }
                    }
                }
            } catch MigrationError.incompatibleStore {
                DispatchQueue.main.async {
                    self.storeMigrationFailed = true
                    self.presentIncompatibleDataAlert()
                }
            } catch {
                UserEngagement.logError(error)
                fatalError(error.localizedDescription)
            }
        }
    }

    private func handleLaunchOptions(_ options: LaunchOptions) {
        guard let tabBarController = window.rootViewController as? TabBarController else {
            assertionFailure()
            return
        }

        if let quickAction = options.quickAction {
            quickAction.perform(from: tabBarController)
        } else if let csvFileUrl = options.url {
            self.handleOpenUrl(csvFileUrl)
        }
    }

    /**
     Returns whether the provided URL could be handled.
    */
    @discardableResult func handleOpenUrl(_ url: URL) -> Bool {
        guard url.isFileURL && url.pathExtension == "csv" else { return false }
        guard let tabBarController = window.rootViewController as? TabBarController else { return false }
        UserEngagement.logEvent(.openCsvInApp)
        tabBarController.selectedTab = .settings

        let settingsSplitView = tabBarController.selectedSplitViewController!
        let navController = settingsSplitView.masterNavigationController
        navController.dismiss(animated: false)

        // FUTURE: The pop was preventing the segue from occurring. We can end up with a taller
        // than usual navigation stack. Looking for a way to pop and then push in quick succession.
        navController.viewControllers.first!.performSegue(withIdentifier: "settingsData", sender: url)
        return true
    }

    func handleQuickAction(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard let quickAction = QuickAction(rawValue: shortcutItem.type) else { return false }
        guard let tabBarController = window.rootViewController as? TabBarController else { return false }
        quickAction.perform(from: tabBarController)
        return true
    }

    private func initialiseAfterPersistentStoreLoad() {
        #if DEBUG
        Debug.initialiseData()
        #endif
        DefaultDataManager().createWishListIfNeeded(viewContext: PersistentStoreManager.container.viewContext)
        
        window.rootViewController = TabBarController()

        // Initialise app-level theme, and monitor the set theme, if on iOS >13
        if #available(iOS 13.0, *) { } else {
            initialiseTheme()
            NotificationCenter.default.addObserver(self, selector: #selector(self.initialiseTheme), name: .ThemeSettingChanged, object: nil)
        }

        UserDefaults.standard[.mostRecentWorkingVersion] = BuildInfo.appConfiguration.fullDescription
    }

    @available(iOS, obsoleted: 13.0)
    @objc private func initialiseTheme() {
        if #available(iOS 13.0, *) { return }
        let theme = UserDefaults.standard[.theme]
        theme.configureForms()
        window.tintColor = theme.tint
    }

    private func presentIncompatibleDataAlert() {
        #if RELEASE
        // This is a common error during development, but shouldn't occur in production
        guard UserDefaults.standard[.mostRecentWorkingVersion] != BuildInfo.appConfiguration.fullDescription else {
            UserEngagement.logError(NSError(code: .invalidMigration, userInfo: ["mostRecentWorkingVersion": UserDefaults.standard[.mostRecentWorkingVersion] ?? "unknown"]))
            preconditionFailure("Migration error thrown for store of same version.")
        }
        #endif

        guard window.rootViewController?.presentedViewController == nil else { return }

        let compatibilityVersionMessage: String?
        if let mostRecentWorkingVersion = UserDefaults.standard[.mostRecentWorkingVersion] {
            compatibilityVersionMessage = """
            \n\nYou previously had version \(mostRecentWorkingVersion), but now have version \
            \(BuildInfo.appConfiguration.fullDescription). You will need to install \
            \(mostRecentWorkingVersion) again to be able to access your data.
            """
        } else {
            UserEngagement.logError(NSError(code: .noPreviousStoreVersionRecorded))
            compatibilityVersionMessage = nil
            assertionFailure("No recorded previously working version")
        }

        let alert = UIAlertController(title: "Incompatible Data", message: """
            The data on this device is not compatible with this version of Reading List.\(compatibilityVersionMessage ?? "")
            """, preferredStyle: .alert)

        #if DEBUG
        alert.addAction(UIAlertAction(title: "Delete Store", style: .destructive) { _ in
            NSPersistentStoreCoordinator().destroyAndDeleteStore(at: URL.applicationSupport.appendingPathComponent(PersistentStoreManager.storeFileName))
            self.initialisePersistentStore()
            self.storeMigrationFailed = false
        })
        #endif

        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        window.rootViewController!.present(alert, animated: true)
    }
}

struct LaunchOptions {
    let url: URL?
    let quickAction: QuickAction?

    func any() -> Bool {
        return url != nil || quickAction != nil
    }
}
