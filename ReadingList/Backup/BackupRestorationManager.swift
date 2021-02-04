import Foundation
import UIKit
import os.log

/// A utility which is capable of swapping the window's root view controller to the `BackupRestoreProgress` controller, and then swapping back to the
/// normal `TabBarController` when complete, displaying an alert when the restoration is complete.
final class BackupRestorationManager {
    private init() { }

    /// A persistent reference to the restoration manager, so we don't have to worry about references being deallocated if held, for example, on other view controllers.
    static let shared = BackupRestorationManager()

    /// Switch to the backup restore screen, restore from the provided backup, and then switch back to the app's normal root controller when complete.
    func performRestore(from backup: BackupInfo) {
        guard let window = AppDelegate.shared.window else { fatalError("No window available when attempting to restore") }
        window.rootViewController = BackupRestoreProgress(backupInfo: backup) { result in
            if case let BackupRestoreResult.failure(error) = result {
                UserEngagement.logError(error)
            }
            DispatchQueue.main.async {
                let newTabBarController = TabBarController()
                window.rootViewController = newTabBarController
                switch result {
                case .cancelled: break
                case .success:
                    let successAlert = UIAlertController(title: "Restore Complete", message: nil, preferredStyle: .alert)
                    successAlert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                    newTabBarController.present(successAlert, animated: true)
                case .failure(let error):
                    let errorMessage = self.errorMessage(for: error)
                    let failureAlert = UIAlertController(title: "Failed to Restore", message: errorMessage, preferredStyle: .alert)
                    failureAlert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                    newTabBarController.present(failureAlert, animated: true)
                }
            }
        }
    }

    private func errorMessage(for error: BackupManager.RestorationFailure) -> String {
        switch error {
        case .archiveDownloadTimeout: return "The backup data could not be downloaded. Please ensure your device is connected to the Internet and try again."
        case .unsupportedVersion: return "The backup was made on a newer version of this app. Please update Reading List and try again."
        case .missingDataArchive: return "The backup data could not found on iCloud."
        case .backupCreationFailure: return "An attempt to temporarily back up the current data failed, so the restore process was aborted."
        case .unpackArchiveFailure: return "The backup data could not be unpacked."
        case .replaceStoreFailure: return "The restoration process failed."
        case .initialisationFailure: return "The backup data could not be loaded."
        case .errorRecoveryFailure: return "An unrecoverable error occurred."
        }
    }
}
