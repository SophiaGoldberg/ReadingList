import Foundation
import CoreSpotlight
import os.log
import ReadingList_Foundation

struct UpgradeAction {
    let id: Int
    let action: () -> Void
}

class UpgradeManager {
    let actions = [
        // Previous versions of the app stored the persistent store in a non-default location.
        // This file move was previously attempted every launch; the vast majority of users
        // will already have their store in the new location.
        UpgradeAction(id: 3) {
            PersistentStoreManager.moveStoreFromLegacyLocationIfNecessary()
        },

        // 1.13.0 changed the storage mechanism of some UserDefaults values
        UpgradeAction(id: 4) {
            // The book sort order settings we are changing a bit more...
            var sortOrders = [BookReadState: BookSort]()
            func copySort(fromKey key: String, for readState: BookReadState, defaultValue: BookSort) {
                if let sortValue = UserDefaults.standard.object(forKey: key) as? Int16 {
                    sortOrders[readState] = BookSort(rawValue: sortValue)!
                } else {
                    sortOrders[readState] = defaultValue
                }
            }
            copySort(fromKey: "toReadSortOrder", for: .toRead, defaultValue: .custom)
            copySort(fromKey: "readingSortOrder", for: .reading, defaultValue: .startDate)
            copySort(fromKey: "finishedSortOrder", for: .finished, defaultValue: .finishDate)
            let data = try! JSONEncoder().encode(sortOrders)
            UserDefaults.standard.setValue(data, forKey: "bookSortOrdersByReadState")
        },

        UpgradeAction(id: 5) {
            guard AppLaunchHistory.appOpenedCount > 0 else { return }
            // Spoof a previously last-launched version of 1.0, upon upgrade to 1.13. This version is only used
            // in tracking what features to show upon upgrade, and 1.13 was the first version to introduce in-app
            // change lists, so we shouldn't get any erroneous behaviour by this little lie.
            do {
                let versionData = try JSONEncoder().encode((Version(major: 1, minor: 0, patch: 0)))
                UserDefaults.standard.set(versionData, forKey: "lastLaunchedVersion")
            } catch {
                os_log("Error encoding spoof version 1.0.0 as data", type: .error)
            }
        },

        UpgradeAction(id: 6) {
            guard AppLaunchHistory.appOpenedCount > 0 else { return }
            // Migrate the previously stored Version to a BuildInfo
            if let lastLaunchedVersionData = UserDefaults.standard.data(forKey: "lastLaunchedVersion"),
               let lastLaunchedVersion = try? JSONDecoder().decode(Version.self, from: lastLaunchedVersionData) {
                // Build number of 1 and type of .appStore are made up!
                AppLaunchHistory.lastLaunchedBuildInfo = BuildInfo(version: lastLaunchedVersion, buildNumber: 1, type: .appStore)
            }
        }
    ]

    /**
     Performs any necessary upgrade actions required, prior to the initialisation of the persistent store.
    */
    func performNecessaryUpgradeActions() {
        // Work out what our threshold should be when considering which upgrade actions to apply
        let threshold: Int?
        if let lastAppliedUpgradeAction = AppLaunchHistory.lastAppliedUpgradeAction {
            threshold = lastAppliedUpgradeAction
        } else {
            let startupCount = AppLaunchHistory.appOpenedCount
            if startupCount > 0 {
                os_log("No record of applying actions, but startup count is %d: will run upgrade actions anyway.", startupCount)
                // Use 0 as the threshold when applying upgrade actions when we don't know what version we came from.
                // This will apply them all.
                threshold = 0
            } else {
                threshold = nil
            }
        }

        // If we have a threshold, apply the relevant actions.
        if let threshold = threshold {
            applyActions(threshold: threshold)
        } else {
            os_log("First launch: no upgrade actions to run.")
        }

        // Now that we have applied any necessary actions, update the storage of the most recent started version
        AppLaunchHistory.lastAppliedUpgradeAction = actions.last!.id
    }

    private func applyActions(threshold: Int) {
        // We can exit early if the threshold is same version as the last upgrade action id
        if threshold == actions.last?.id {
            os_log("No upgrade actions to apply")
            return
        }

        // Look for relevant actions to apply; run each in order that match
        let relevantActions = actions.filter { $0.id > threshold }
        relevantActions.forEach { action in
            os_log("Running upgrade action with id %d", action.id)
            action.action()
        }
        if !relevantActions.isEmpty {
            os_log("All %d upgrade actions completed", relevantActions.count)
        }
    }
}
