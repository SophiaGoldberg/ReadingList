import Foundation
import os.log

extension OSLog {
    private static let subsystem = Bundle.main.bundleIdentifier!
    static let sync = OSLog(subsystem: subsystem, category: "sync")
    static let syncUpstream = OSLog(subsystem: subsystem, category: "sync_upstream")
    static let syncDownstream = OSLog(subsystem: subsystem, category: "sync_downstream")
}
