import Foundation
import SwiftyStoreKit
import SVProgressHUD
import os.log
import CoreData
import ReadingList_Foundation
import Reachability
import PersistedPropertyWrapper

class LaunchManager {

    var window: UIWindow!
    var storeMigrationFailed = false
    var isFirstLaunch = false

    /**
     Performs any required initialisation immediately post after the app has launched.
     This must be called prior to any other initialisation actions.
    */
    func initialise(window: UIWindow) {
        self.window = window

        isFirstLaunch = AppLaunchHistory.appOpenedCount == 0
        #if DEBUG
        Debug.initialiseSettings()
        #endif
        UserEngagement.initialiseUserAnalytics()
        SVProgressHUD.setDefaults()
        SwiftyStoreKit.completeTransactions()
    }

    func handleApplicationDidBecomeActive() {
        AppLaunchHistory.appOpenedCount += 1

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

        return LaunchOptions(url: launchOptions?[.url] as? URL, quickAction: quickAction)
    }

    /**
     Initialises the persistent store on a background thread. If successfully completed, the callback will be run
     on the main thread. If the persistent store fails to initialise, then an error alert is presented to the user.
     */
    func initialisePersistentStore(_ onSuccess: (() -> Void)? = nil) {
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                try PersistentStoreManager.initalisePersistentStore {
                    os_log("Persistent store loaded", type: .info)
                    DispatchQueue.main.async {
                        AppLaunchHistory.lastLaunchedBuildInfo = BuildInfo.thisBuild
                        onSuccess?()
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

    func handleLaunchOptions(_ options: LaunchOptions, tabBarController: TabBarController) {
        if let quickAction = options.quickAction {
            quickAction.perform(from: tabBarController)
        } else if let launchUrl = options.url {
            self.handleOpenUrl(launchUrl)
        }
    }

    /**
     Returns whether the provided URL could be handled.
    */
    @discardableResult func handleOpenUrl(_ url: URL) -> Bool {
        if url.isFileURL && url.pathExtension == "csv" {
            return openCsvFileInApp(url: url)
        } else if url.scheme == ProprietaryURLManager.scheme {
            if let urlAction = ProprietaryURLManager().getAction(from: url) {
                return ProprietaryURLActionHandler(window: window).handle(urlAction)
            } else {
                os_log("Unparsable URL: %{public}s", type: .error, url.absoluteString)
                return false
            }
        } else {
            os_log("Unrecognised URL type; handling not possible: %{public}s", type: .error, url.absoluteString)
            return false
        }
    }

    private func openCsvFileInApp(url: URL) -> Bool {
        os_log("Opening CSV file URL: %{public}s", type: .default, url.absoluteString)

        guard let tabBarController = window.rootViewController as? TabBarController else {
            assertionFailure()
            return false
        }
        UserEngagement.logEvent(.openCsvInApp)

        // First select the correct tab (Settings)
        tabBarController.selectedTab = .settings
        let settingsSplitVC = tabBarController.selectedSplitViewController!

        // Dismiss any existing navigation stack (implementation depends on whether the views are split or not)
        if let detailNav = settingsSplitVC.detailNavigationController {
            detailNav.popToRootViewController(animated: false)
        } else {
            settingsSplitVC.masterNavigationController.popToRootViewController(animated: false)
        }

        // Select the Import Export row to ensure it is highlighted
        guard let settingsVC = settingsSplitVC.masterNavigationController.viewControllers.first as? Settings else {
            assertionFailure()
            return false
        }
        settingsVC.tableView.selectRow(at: Settings.importExportIndexPath, animated: false, scrollPosition: .none)

        // Instantiate the destination view controller
        guard let importVC = UIStoryboard.ImportExport.instantiateViewController(withIdentifier: "Import") as? Import else {
            assertionFailure()
            return false
        }
        importVC.preProvidedImportFile = url

        // Instantiate the stack of view controllers leading up to the Import view controller
        guard let navigation = UIStoryboard.ImportExport.instantiateViewController(withIdentifier: "Navigation") as? UINavigationController else {
            preconditionFailure()
        }
        navigation.setViewControllers([
            UIStoryboard.ImportExport.instantiateViewController(withIdentifier: "ImportExport"),
            importVC
        ], animated: false)

        // Put them on the screen
        settingsSplitVC.showDetailViewController(navigation, sender: self)
        return true
    }

    func handleQuickAction(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard let quickAction = QuickAction(rawValue: shortcutItem.type) else { return false }
        guard let tabBarController = window.rootViewController as? TabBarController else { return false }
        quickAction.perform(from: tabBarController)
        return true
    }

    var presentFirstLaunchOrChangeLog: Bool {
        #if DEBUG
        return !CommandLine.arguments.contains("--UITests_Screenshots")
        #else
        return true
        #endif
    }

    func initialiseAfterPersistentStoreLoad() {
        #if DEBUG
        Debug.initialiseData()
        #endif
        window.rootViewController = TabBarController()

        // Initialise app-level theme, and monitor the set theme, if < iOS 13
        if #available(iOS 13.0, *) { } else {
            initialiseTheme()
            NotificationCenter.default.addObserver(self, selector: #selector(self.initialiseTheme), name: .ThemeSettingChanged, object: nil)
        }

        if presentFirstLaunchOrChangeLog {
            if isFirstLaunch {
                let firstOpenScreen = FirstOpenScreenProvider().build()
                window.rootViewController!.present(firstOpenScreen, animated: true)
            } else if let lastLaunchedVersion = AppLaunchHistory.lastLaunchedBuildInfo?.version {
                if let changeList = ChangeListProvider().changeListController(after: lastLaunchedVersion) {
                    window.rootViewController!.present(changeList, animated: true)
                }
            }
        }

        if #available(iOS 14.0, *) {
            BookDataSharer.instance.inititialise(persistentContainer: PersistentStoreManager.container)
            if AppLaunchHistory.lastLaunchedBuildInfo?.buildNumber != BuildInfo.thisBuild.buildNumber || BuildInfo.thisBuild.type == .debug {
                // Not strictly a save, but the first time we launch an updated version of the app, we ought to repopulate the shared book data
                os_log("Repopulating shared book data for widget", type: .default)
                BookDataSharer.instance.handleChanges(forceUpdate: true)
            }
        }

        AppLaunchHistory.lastLaunchedBuildInfo = BuildInfo.thisBuild
    }

    @available(iOS, obsoleted: 13.0)
    @objc private func initialiseTheme() {
        if #available(iOS 13.0, *) { return }
        let theme = GeneralSettings.theme
        theme.configureForms()
        window.tintColor = theme.tint
    }

    private func presentIncompatibleDataAlert() {
        #if RELEASE
        // This is a common error during development, but shouldn't occur in production
        guard AppLaunchHistory.lastLaunchedBuildInfo?.version != BuildInfo.thisBuild.version else {
            UserEngagement.logError(
                NSError(code: .invalidMigration,
                        userInfo: ["mostRecentWorkingVersion": AppLaunchHistory.lastLaunchedBuildInfo?.fullDescription ?? "unknown"])
            )
            preconditionFailure("Migration error thrown for store of same version.")
        }
        #endif

        guard window.rootViewController?.presentedViewController == nil else { return }

        let compatibilityVersionMessage: String?
        if let mostRecentWorkingVersion = AppLaunchHistory.lastLaunchedBuildInfo?.fullDescription {
            compatibilityVersionMessage = """
            \n\nYou previously had version \(mostRecentWorkingVersion), but now have version \
            \(BuildInfo.thisBuild.fullDescription). You will need to install \
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
            // More accurately model a reinstall by clearing UserDefaults too
            UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
            UserDefaults.standard.synchronize()
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
