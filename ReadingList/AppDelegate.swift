import UIKit
import Reachability
import os.log

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    lazy var launchManager = LaunchManager(window: window)
    let upgradeManager = UpgradeManager()

    /// Will be nil until after the persistent store is initialised.
    var syncCoordinator: SyncCoordinator?

    static var shared: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }

    var tabBarController: TabBarController? {
        return window?.rootViewController as? TabBarController
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        launchManager.initialise()
        upgradeManager.performNecessaryUpgradeActions()

        // Remote notifications are required for iCloud sync.
        application.registerForRemoteNotifications()

        // Grab any options which we will take action on after the persistent store is initialised
        let options = launchManager.extractRelevantLaunchOptions(launchOptions)
        launchManager.initialisePersistentStore {
            self.initialiseSyncCoordinator()
            self.launchManager.handleLaunchOptions(options)
        }

        // If there were any options, they will be handled once the store is initialised
        return !options.any()
    }
    
    private func initialiseSyncCoordinator() {
        // Initialise the Sync Coordinator which will maintain iCloud synchronisation
        self.syncCoordinator = SyncCoordinator(
            persistentStoreCoordinator: PersistentStoreManager.container.persistentStoreCoordinator,
            orderedTypesToSync: [Book.self, List.self, ListItem.self]
        )
        if GeneralSettings.iCloudSyncEnabled {
            syncCoordinator?.start()
        }
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        launchManager.handleApplicationDidBecomeActive()
    }

    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        let didHandle = launchManager.handleQuickAction(shortcutItem)
        completionHandler(didHandle)
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return launchManager.handleOpenUrl(url)
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        os_log("Successfully registered for remote notifications", type: .info)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        os_log("Failed to register for remote notifications: %{public}s", type: .error, error.localizedDescription)
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        guard #available(iOS 13.0, *) else { return }
        if GeneralSettings.iCloudSyncEnabled, let syncCoordinator = (self.syncCoordinator as? SyncCoordinator) {
            syncCoordinator.respondToRemoteChangeNotification()
        }
    }
}
