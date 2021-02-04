import Foundation
import PersistedPropertyWrapper
import BackgroundTasks
import UIKit
import os.log

enum BackupFrequencyPeriod: Int, CaseIterable {
    case daily = 1
    case weekly = 2
    case off = 0
}

extension BackupFrequencyPeriod {
    var duration: TimeInterval? {
        switch self {
        case .daily: return 60 * 60 * 24
        case .weekly: return 60 * 60 * 24 * 7
        case .off: return nil
        }
    }
}

extension Notification.Name {
    static let autoBackupEnabledOrDisabled = Notification.Name("autoBackupEnabledOrDisabled")
}

class AutoBackupManager {
    static let shared = AutoBackupManager()

    private init() {
        NotificationCenter.default.addObserver(self, selector: #selector(autoBackupCapabilityDidChange), name: UIApplication.backgroundRefreshStatusDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ubiquityIdentityDidChange), name: .NSUbiquityIdentityDidChange, object: nil)
    }

    @objc private func ubiquityIdentityDidChange() {
        // If the ubiquity identity changes (i.e. the user logs in or out of iCloud), post this notification to have it be handled
        // in the same was as if they turned on or off auto backup.
        NotificationCenter.default.post(name: .autoBackupEnabledOrDisabled, object: nil)
    }

    @objc private func autoBackupCapabilityDidChange() {
        // If background app refresh has become available, schedule one now.
        if FileManager.default.ubiquityIdentityToken != nil && UIApplication.shared.backgroundRefreshStatus == .available {
            self.scheduleBackup()
        } else {
            self.nextBackupEarliestStartDate = nil
        }
    }

    var cannotRunScheduledAutoBackups: Bool {
        return FileManager.default.ubiquityIdentityToken != nil
            && UIApplication.shared.backgroundRefreshStatus != .available
            && backupFrequency != .off
    }

    @Persisted("backup-frequency-period", defaultValue: .daily)
    private(set) var backupFrequency: BackupFrequencyPeriod

    /// Sets the new backup frequency, cancelling or re-scheduling an auto-backup if appropriate. If auto-backups have been disabled or enabled by this call,
    /// posts a `.autoBackupEnabledOrDisabled` notification.
    func setBackupFrequency(_ newBackupFrequency: BackupFrequencyPeriod) {
        if backupFrequency == newBackupFrequency { return }
        let isEnableOrDisableChange = backupFrequency == .off || newBackupFrequency == .off
        backupFrequency = newBackupFrequency

        if newBackupFrequency == .off {
            cancelScheduledBackup()
        } else {
            scheduleBackup()
        }
        if isEnableOrDisableChange {
            NotificationCenter.default.post(name: .autoBackupEnabledOrDisabled, object: nil)
        }
        UserEngagement.logEvent(newBackupFrequency == .off ? .disableAutoBackup : .changeAutoBackupFrequency)
    }

    @Persisted("last-backup-completion-date")
    var lastBackupCompletion: Date?

    @Persisted("next-backup-earliest-start-date")
    var nextBackupEarliestStartDate: Date?

    @Persisted("last-auto-backup-failed", defaultValue: false)
    var lastAutoBackupFailed: Bool

    private let backgroundTaskIdentifier = "com.andrewbennet.books.backup"
    private let dispatchQueue = DispatchQueue(label: "com.andrewbennet.books.backup", qos: .background)

    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
            guard let processingTask = task as? BGProcessingTask else { preconditionFailure("Unexpected task type") }
            self.handleBackupTask(processingTask)
        }
    }

    func cancelScheduledBackup() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: backgroundTaskIdentifier)
        nextBackupEarliestStartDate = nil
    }

    func scheduleBackup(startingAfter earliestBeginDate: Date? = nil) {
        guard let backupInterval = backupFrequency.duration else { return }
        guard FileManager.default.ubiquityIdentityToken != nil else {
            os_log("No iCloud user logged in; not scheduling background backup.")
            return
        }

        let request = BGProcessingTaskRequest(identifier: backgroundTaskIdentifier)
        if let earliestBeginDate = earliestBeginDate {
            request.earliestBeginDate = earliestBeginDate
            os_log("Scheduled iCloud backup to start after %{public}s", earliestBeginDate.string(withDateFormat: "yyyy-MM-dd HH:mm:ss"))
        } else if let lastBackup = lastBackupCompletion {
            let nextBackupStartDate = lastBackup.advanced(by: backupInterval)
            request.earliestBeginDate = nextBackupStartDate
            os_log("Scheduled iCloud backup to start %d seconds after last backup, at %{public}s", backupInterval, nextBackupStartDate.string(withDateFormat: "yyyy-MM-dd HH:mm:ss"))
        }

        do {
            try BGTaskScheduler.shared.submit(request)
            nextBackupEarliestStartDate = request.earliestBeginDate ?? Date()
        } catch {
            guard let bgTaskError = error as? BGTaskScheduler.Error else {
                fatalError("Unexpected scheduling background task: \(error.localizedDescription)")
            }
            switch bgTaskError.code {
            case .tooManyPendingTaskRequests: fatalError("Unexpected 'tooManyPendingTaskRequests' error when scheduling background task")
            case .notPermitted: fatalError("Unexpected 'notPermitted' error when scheduling background task")
            case .unavailable: os_log("Background task scheduling is unavailable", type: .error)
            @unknown default:
                UserEngagement.logError(error)
                os_log("Unknown background task scheduling error with code %d", type: .error, bgTaskError.code.rawValue)
            }
        }
    }

    func handleBackupTask(_ task: BGProcessingTask) {
        // Schedule a new backup task
        if let backupInterval = backupFrequency.duration {
            scheduleBackup(startingAfter: Date(timeIntervalSinceNow: backupInterval))
        }

        // First, the more likely event: the persistent store container exists. Just perform the backup.
        if PersistentStoreManager.container != nil {
            self.performBackupFromTask(task)
            return
        }

        // Use a dispatch queue to ensure synchronised access to hasRunBackup
        os_log("Persistent container was not initialised when handling backup task: registering a notification observer")
        dispatchQueue.async {
            var hasRunBackup = false
            var observer: NSObjectProtocol?
            observer = NotificationCenter.default.addObserver(forName: .didCompletePersistentStoreInitialisation, object: nil, queue: nil) { _ in
                guard let observer = observer else { fatalError("Unexpected nil observer object") }
                NotificationCenter.default.removeObserver(observer)

                // Have the observation block switch back onto the same dispatch queue so that the following code is synchronised with
                // another check of persistent store manager container just afterwards.
                self.dispatchQueue.async {
                    guard !hasRunBackup else {
                        os_log("Backup has already been run; exiting")
                        return
                    }
                    os_log("Running backup in response to initialisationCompletion notification")
                    self.performBackupFromTask(task)
                }
            }

            // We have to be careful here that the initialisation did not complete between our first check, and when we registered
            // the notification observers. If that happened, we will never observe the notification (we missed it) so we need to
            // check the initialisation of the container again.
            if PersistentStoreManager.container != nil {
                os_log("Persistent store container is non-nil straight after registering initialisation completion notification observer")
                guard let observer = observer else { fatalError("Unexpected nil observer object") }
                NotificationCenter.default.removeObserver(observer)
                self.performBackupFromTask(task)
                hasRunBackup = true
            }
        }
    }

    func performBackupFromTask(_ task: BGProcessingTask) {
        let backupManager = BackupManager()
        do {
            try backupManager.performBackup()
            lastAutoBackupFailed = false
            UserEngagement.logEvent(.autoBackup)
            task.setTaskCompleted(success: true)
        } catch {
            os_log("Background backup task failed: %{public}s", type: .error, error.localizedDescription)
            lastAutoBackupFailed = true
            UserEngagement.logError(error)
            task.setTaskCompleted(success: false)
        }
        lastBackupCompletion = Date()
    }
}
