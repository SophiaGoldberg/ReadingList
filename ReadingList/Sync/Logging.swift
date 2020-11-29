import Foundation
import os.log

extension OSLog {
    static let subsystem = Bundle.main.bundleIdentifier!
    static let syncCoordinator = OSLog(subsystem: subsystem, category: "SyncCoordinator")
}
