import Foundation
import UIKit
import os.log

/**
 A utility which can be used to determine whether to show a restoration prompt upon first launch of the app.
 */
final class FirstLaunchRestorationManager {

    /// A global reference to a shared instance, which can persist while waiting for backup info files to download.
    static let shared = FirstLaunchRestorationManager()

    private let backupManager = BackupManager()
    private let dispatchQueue = DispatchQueue(label: "com.andrewbennet.books.FirstLaunchRestorationManager", qos: .userInitiated)

    private var hasStartedLookingForEligibleBackups = false

    /**
     Call this function when the app is first launched; once all backup infos are known, it will determine whether any are appropriate for restoriation on this device.
     If any are appropriate, an alert will be shown giving the opportunity for restoration.
    */
    func presentRestorePromptIfSuitableBackupFound() {
        dispatchQueue.async {
            // If no iCloud account, then don't bother looking for a backup
            guard FileManager.default.ubiquityIdentityToken != nil else { return }

            // Register an observer for this notification now, to avoid timing issues between checking `hasDownloadedAllInitialInfoFiles` and, if it's false,
            // registering an observer. The backup files may have been downloaded between those two operations in this object. So register the observer first,
            // and then remove it if its not needed.
            NotificationCenter.default.addObserver(self, selector: #selector(self.initialBackupInfoFilesDownloaded), name: .initialBackupInfoFilesDownloaded, object: nil)

            if BackupInfoMonitor.shared.hasDownloadedAllInitialInfoFiles {
                self.hasStartedLookingForEligibleBackups = true
                NotificationCenter.default.removeObserver(self, name: .initialBackupInfoFilesDownloaded, object: nil)

                os_log("Initial info files are all downloaded; will present a backup restore prompt if eligible")
                self.findEligibleBackupsAndPresentRestorationPrompt()
            } else {
                os_log("Initial info files are not yet all downloaded; waiting for notification of info files download before checking for backup restoration eligibility.")

                // But don't wait longer than 10 seconds! It could give a weird experience if the prompt randomly appears while using the app.
                self.dispatchQueue.asyncAfter(deadline: .now() + 10) {
                    NotificationCenter.default.removeObserver(self, name: .initialBackupInfoFilesDownloaded, object: nil)
                }
            }
        }
    }

    @objc private func initialBackupInfoFilesDownloaded() {
        if hasStartedLookingForEligibleBackups {
            os_log("Backup info download notification received, but this instance has already started looking for eligible backups. Exiting.")
            return
        }

        hasStartedLookingForEligibleBackups = true
        NotificationCenter.default.removeObserver(self, name: .initialBackupInfoFilesDownloaded, object: nil)

        findEligibleBackupsAndPresentRestorationPrompt()
    }

    private func findEligibleBackupsAndPresentRestorationPrompt() {
        guard let backupInfo = findEligibleBackupForRestoration() else { return }
        DispatchQueue.main.async {
            guard let rootViewController = AppDelegate.shared.window?.rootViewController else { return }
            let restorationAlert = self.backupRestorationAlert(backupInfo)
            rootViewController.present(restorationAlert, animated: true)
        }
    }

    private func findEligibleBackupForRestoration() -> BackupInfo? {
        let backups = self.backupManager.readBackups()
        if backups.isEmpty {
            os_log("No backups found to use for first-launch restoration")
            return nil
        }

        // We only prompt if we found a backup from the same device class as this one. We don't intend for backups
        // to be used as a means to transfer data between iPhone and iPad, rather as a means to restore data from
        // one device to the same device (after a reinstall) or its replacement.
        if let backup = backups.filter({ $0.markerFileInfo.deviceIdiom == UIDevice.current.userInterfaceIdiom })
            .max(by: { $0.markerFileInfo.isPreferableTo($1.markerFileInfo) }) {
            os_log("Found candidate backup to propose restoration")
            return backup
        } else {
            os_log("No backups matched requirements to propose backup restoration")
            return nil
        }
    }

    private func backupRestorationAlert(_ backupInfo: BackupInfo) -> UIAlertController {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        let alert = UIAlertController(
            title: "Restore from Backup?",
            message: """
            A data backup made on \(dateFormatter.string(from: backupInfo.markerFileInfo.created)) on \
            \(backupInfo.markerFileInfo.deviceName) was found. Do you want to restore the data from the backup?
            """,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Restore", style: .destructive) { _ in
            UserEngagement.logEvent(.restoreFromBackupOnFirstLaunch)
            BackupRestorationManager.shared.performRestore(from: backupInfo)
        })
        alert.addAction(UIAlertAction(title: "More Info", style: .default) { _ in
            guard let tabBarController = AppDelegate.shared.tabBarController else { fatalError("Missing tab bar controller") }
            tabBarController.presentBackupView()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        return alert
    }
}
