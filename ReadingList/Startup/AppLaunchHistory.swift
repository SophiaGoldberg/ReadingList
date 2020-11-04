import Foundation
import PersistedPropertyWrapper

struct AppLaunchHistory {
    private init() { }

    @Persisted(encodedDataKey: "lastLaunchedBuild")
    static var lastLaunchedBuildInfo: BuildInfo?

    @Persisted("appStartupCount", defaultValue: 0)
    static var appOpenedCount: Int

    @Persisted("lastAppliedUpgradeAction")
    static var lastAppliedUpgradeAction: Int?
}
