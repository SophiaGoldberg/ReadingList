import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var launchManager = LaunchManager()
    let upgradeManager = UpgradeManager()

    static var shared: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }

    var tabBarController: TabBarController? {
        return window?.rootViewController as? TabBarController
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        launchManager.initialise(window: window!)
        upgradeManager.performNecessaryUpgradeActions()

        // Grab any options which we will take action on after the persistent store is initialised
        let options = launchManager.extractRelevantLaunchOptions(launchOptions)
        launchManager.initialisePersistentStore(options)

        // If there were any options, they will be handled once the store is initialised
        return !options.any()
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
}
