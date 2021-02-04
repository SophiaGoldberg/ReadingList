import Foundation
import UIKit
import ReadingList_Foundation
import os.log
import SVProgressHUD

final class Backup: UITableViewController {
    private let backupManager = BackupManager()
    private var backupsInfo = [BackupInfo]()

    // FUTURE: Consider iCloud storage? Alert if full, etc?
    // FUTURE: Alert if repeated auto-backup failures?
    // FUTURE: Expose a mechanism to backup and restore to/from a zip file

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let refreshControl = self.refreshControl else { preconditionFailure("Missing refresh control") }
        refreshControl.addTarget(self, action: #selector(self.didPullToRefresh), for: .valueChanged)

        reloadBackupInfoInBackground()
        NotificationCenter.default.addObserver(self, selector: #selector(reloadBackupInfoInBackground), name: .initialBackupInfoFilesDownloaded, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadBackupInfoInBackground), name: .backupInfoFilesChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(respondToUploadStateChange), name: .backupArchiveUploadStateChanges, object: nil)

        // Watch for changes in the ability to run background tasks
        NotificationCenter.default.addObserver(self, selector: #selector(backgroundRefreshStatusDidChange),
                                               name: UIApplication.backgroundRefreshStatusDidChangeNotification, object: nil)
    }

    @objc private func reloadBackupInfoInBackground() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.reloadBackupInfo()
        }
    }

    @objc private func respondToUploadStateChange() {
        DispatchQueue.main.async {
            os_log("Backup archive upload state change notification received; reloading table")
            self.tableView.reloadData()
        }
    }

    @objc private func didPullToRefresh() {
        guard let refreshControl = self.refreshControl else { preconditionFailure("Missing refresh control") }
        DispatchQueue.global(qos: .userInitiated).async {
            self.reloadBackupInfo {
                refreshControl.endRefreshing()
            }
        }
    }

    @objc private func backgroundRefreshStatusDidChange() {
        if tableView.numberOfSections == 3 {
            tableView.reloadSections(IndexSet(arrayLiteral: 2), with: .automatic)
        } else {
            os_log("Detected background refresh status change, but no row at (2, 0) to be refreshed")
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        // We don't show the backup history section if the user isn't logged in to iCloud, since they are likely to be stale
        return FileManager.default.ubiquityIdentityToken == nil ? 1 : 3
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 1
        case 1: return backupsInfo.isEmpty ? 1 : backupsInfo.count
        case 2: return 1
        default: fatalError("Unexpected call to numberOfRowsInSection for section \(section)")
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Backup"
        case 1: return "Restore"
        case 2: return "Auto-Backup"
        default: return nil
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0:
            if FileManager.default.ubiquityIdentityToken == nil {
                return "App backup data is stored in iCloud. Ensure you are logged in to iCloud in order to back up or restore your data."
            } else {
                var title = "Back up to iCloud to keep your data safe in case you lose your \(UIDevice.current.model) or switch to a new one."

                let mostRecentBackupOnThisDevice = backupsInfo
                    .filter { $0.markerFileInfo.deviceVendorIdentifier == UIDevice.current.identifierForVendor }
                    .max(by: { $0.markerFileInfo.created < $1.markerFileInfo.created })
                if let mostRecentBackupOnThisDevice = mostRecentBackupOnThisDevice {
                    title += "\nLast backed up: \(dateFormatter.string(from: mostRecentBackupOnThisDevice.markerFileInfo.created))"
                }
                return title
            }
        case 1:
            if backupsInfo.isEmpty {
                return "App data backups will be listed here once they have been made. Note that it can take some time for backups to sync with iCloud."
            } else {
                return "Tap a specific backup to overwrite the data on this \(UIDevice.current.model) with the data from a backup. Note that it can take some time for backups to sync with iCloud. Backups not yet uploaded to iCloud are indicated with a dashed cloud icon."
            }
        case 2:
            if #available(iOS 13.0, *), UIApplication.shared.backgroundRefreshStatus != .available {
                var notAvailableText = "Automatic backups are not available as 'Background App Refresh' is not enabled."
                if UIApplication.shared.backgroundRefreshStatus == .denied {
                    notAvailableText += " Enable 'Background App Refresh' in Settings > General > Background App Refresh to enable automatic backups."
                }
                return notAvailableText
            }
            var backupFrequencyText = "Select the frequency that Reading List automatically backs up your data."
            if #available(iOS 13.0, *) {
                // The use of the background operation for backups is only on iOS 13 and up; only include
                // this note on iOS 13 therefore.
                backupFrequencyText += " Backups will made in the background, when your \(UIDevice.current.model) is locked and connected to power, and uploaded to iCloud when connected to the Internet."
            }
            return backupFrequencyText
        default: return nil
        }
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private let byteFormatter = ByteCountFormatter()
    private let basicCellIdentifier = "BasicCell"
    private let subtitleCellIdentifier = "SubtitleCell"
    private let rightDetailCellIdentifier = "RightDetailCell"
    private let backupNowCellIndexPath = IndexPath(row: 0, section: 0)

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            return backupNowCell(indexPath)
        case 1:
            guard !backupsInfo.isEmpty else { return noBackupsAvailableCell(indexPath) }
            return backupInfoCell(at: indexPath)
        case 2:
            return backupFrequencyCell(indexPath)
        default: fatalError("Unexpected index path section \(indexPath.section)")
        }
    }

    private func backupNowCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: basicCellIdentifier, for: indexPath)
        guard let textLabel = cell.textLabel else { fatalError("Missing text label on cell") }
        if FileManager.default.ubiquityIdentityToken == nil {
            cell.isEnabled = false
            textLabel.text = "Log in to iCloud to Back Up"
            if #available(iOS 13.0, *) {
                textLabel.textColor = .secondaryLabel
            }
        } else {
            cell.isEnabled = true
            textLabel.text = "Back Up Now"
            textLabel.textColor = .systemBlue
        }
        return cell
    }

    private func noBackupsAvailableCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: basicCellIdentifier, for: indexPath)
        guard let textLabel = cell.textLabel else { fatalError("Missing text label on cell") }
        textLabel.text = "No Backups Available"
        if #available(iOS 13.0, *) {
            textLabel.textColor = .label
        }
        cell.isEnabled = false
        return cell
    }

    private func backupInfoCell(at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: subtitleCellIdentifier, for: indexPath)
        guard let textLabel = cell.textLabel, let subtitleLabel = cell.detailTextLabel else { fatalError("Missing text label on cell") }
        let backup = backupsInfo[indexPath.row]
        textLabel.text = "\(backup.markerFileInfo.deviceName) (\(byteFormatter.string(fromByteCount: Int64(backup.markerFileInfo.sizeBytes))))"
        subtitleLabel.text = dateFormatter.string(from: backup.markerFileInfo.created)

        // Indicate the backups which are not uploaded yet with a dashed cloud icon
        let isUploaded = (try? backup.backupDataFilePath.isUploaded()) ?? false
        if !isUploaded {
            let dashedCloud = UIImage(imageLiteralResourceName: "DashedCloud")
                .withRenderingMode(.alwaysTemplate)
            let dashedCloudImageView = UIImageView(image: dashedCloud)
            dashedCloudImageView.tintColor = view.tintColor
            dashedCloudImageView.frame.size = CGSize(width: 26, height: 26)
            cell.accessoryView = dashedCloudImageView
        } else {
            cell.accessoryView = nil
        }
        return cell
    }

    private func backupFrequencyCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: rightDetailCellIdentifier, for: indexPath)
        guard let textLabel = cell.textLabel, let rightDetailLabel = cell.detailTextLabel else { fatalError("Missing text label on cell") }
        if #available(iOS 13.0, *) {
            rightDetailLabel.textColor = .secondaryLabel
        }
        textLabel.text = "Backup Frequency"
        if AutoBackupManager.shared.cannotRunScheduledAutoBackups {
            rightDetailLabel.text = nil
            cell.accessoryView = UILabel.tableCellBadge()
        } else {
            rightDetailLabel.text = AutoBackupManager.shared.backupFrequency.description
            cell.accessoryType = .disclosureIndicator
            cell.accessoryView = nil
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.section == 1 else { return nil }
        if self.backupsInfo.isEmpty { return nil }

        let backupInfo = self.backupsInfo[indexPath.row]
        // We always provide a delete action, which deletes the backup from iCloud + local disk, but
        // we only provide a "remove" action if the data archive is present on the local device.
        var swipeActions = [UIContextualAction(style: .destructive, title: "Delete") { _, _, completion in
            let confirmation = UIAlertController(title: "Confirm Deletion", message: "This action will delete the backup from iCloud, which will remove it as a backup option from all devices. Deleting this backup is irreversible. Are you sure you wish to delete this backup?", preferredStyle: .actionSheet)
            confirmation.addAction(UIAlertAction(title: "Delete iCloud Backup", style: .destructive) { _ in
                do {
                    try FileManager.default.removeItem(at: backupInfo.backupDirectory)
                    completion(true)
                } catch {
                    // The most likely error is due to the file already being deleted; let's just act as if it was deleted,
                    // and it may come back when next refreshed...
                    os_log("Error deleting backup: %{public}s", type: .error, error.localizedDescription)
                    completion(false)
                }

                // Update the model then then table
                self.backupsInfo.remove(at: indexPath.row)

                if self.backupsInfo.isEmpty {
                    // Deleting the last row takes us from 1 row to 1 "No Backups" row, so just reload it
                    // rather than removing it.
                    tableView.reloadRows(at: [indexPath], with: .automatic)
                } else {
                    tableView.deleteRows(at: [indexPath], with: .automatic)
                }
            })
            confirmation.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                completion(false)
            })
            confirmation.popoverPresentationController?.setSourceCell(atIndexPath: indexPath, inTable: tableView)
            self.present(confirmation, animated: true)
        }]

        if (try? backupInfo.backupDataFilePath.isDownloaded()) ?? false {
            swipeActions.append(UIContextualAction(style: .normal, title: "Remove") { _, _, completion in
                let confirmation = UIAlertController(title: "Confirm Removal", message: "The will remove the local copy of the backup from this device, but the backup will remain on iCloud. In order to restore from this backup, it will need to be downloaded again.", preferredStyle: .actionSheet)
                confirmation.addAction(UIAlertAction(title: "Remove Local Backup", style: .default) { _ in
                    do {
                        try FileManager.default.evictUbiquitousItem(at: backupInfo.backupDataFilePath)
                        completion(true)
                    } catch {
                        os_log("Error evicting ubiquitous item: %{public}s", type: .error, error.localizedDescription)
                        completion(false)
                    }
                })
                confirmation.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                    completion(false)
                })
                confirmation.popoverPresentationController?.setSourceCell(atIndexPath: indexPath, inTable: tableView)
                self.present(confirmation, animated: true)
            })
        }

        return UISwipeActionsConfiguration(actions: swipeActions)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath == backupNowCellIndexPath {
            didSelectBackupNowCell()
        } else if indexPath.section == 1 {
            guard !self.backupsInfo.isEmpty else { return }
            let backupInfo = self.backupsInfo[indexPath.row]
            let alert = UIAlertController(title: "Restore from Backup?", message: "Restoring from a backup will replace all current data with the data from the backup. Are you sure you wish to continue?", preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Restore", style: .destructive) { _ in
                self.restore(from: backupInfo)
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.popoverPresentationController?.setSourceCell(atIndexPath: indexPath, inTable: tableView)
            present(alert, animated: true)
            tableView.deselectRow(at: indexPath, animated: true)
        } else if indexPath.section == 2 && indexPath.row == 0 {
            // On pre-iOS 13 devices, we don't use background app refresh at all, so never present a warning alert about that.
            guard #available(iOS 13.0, *) else {
                performSegue(withIdentifier: "presentBackupFrequency", sender: self)
                return
            }
            if UIApplication.shared.backgroundRefreshStatus == .available {
                performSegue(withIdentifier: "presentBackupFrequency", sender: self)
            } else {
                // If background app refresh isn't enabled, present an alert explaining how to enable it
                var messageText = "Automatic Backup requires 'Background App Refresh' to be enabled to perform backups periodically in the background."
                if UIApplication.shared.backgroundRefreshStatus == .denied {
                    messageText += "\n\nEnable 'Background App Refresh' in the Settings app under General > Background App Refresh, and ensure that it is enabled for Reading List."
                }
                if AutoBackupManager.shared.backupFrequency != .off {
                    messageText += "\n\nDisable Automatic Backup to hide this notification."
                }
                let alert = UIAlertController(title: "Automatic Backup Not Available", message: messageText, preferredStyle: .alert)
                let openSettingsURL = URL(string: UIApplication.openSettingsURLString)!
                if UIApplication.shared.backgroundRefreshStatus == .denied && UIApplication.shared.canOpenURL(openSettingsURL) {
                    alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
                        UIApplication.shared.open(openSettingsURL, options: [:], completionHandler: nil)
                    })
                }
                if AutoBackupManager.shared.backupFrequency != .off {
                    alert.addAction(UIAlertAction(title: "Disable Automatic Backup", style: .destructive) { _ in
                        AutoBackupManager.shared.setBackupFrequency(.off)
                        self.tableView.reloadSections(IndexSet(arrayLiteral: 2), with: .automatic)
                    })
                }
                alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
                present(alert, animated: true) {
                    self.tableView.deselectRow(at: indexPath, animated: true)
                }
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Attach self to the destination Backup Frequency view controller as a delegate, to update the displayed frequency here
        guard let backupFrequency = segue.destination as? BackupFrequency else { return }
        backupFrequency.delegate = self
    }

    private func didSelectBackupNowCell() {
        guard FileManager.default.ubiquityIdentityToken != nil else { return }
        UserEngagement.logEvent(.createBackup)
        SVProgressHUD.show(withStatus: "Backing Up...")
        tableView.deselectRow(at: backupNowCellIndexPath, animated: true)
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.backupManager.performBackup()
            } catch {
                os_log("Error backing up: %{public}s", type: .error, error.localizedDescription)
                UserEngagement.logError(error)
                DispatchQueue.main.async {
                    let alert = UIAlertController(title: "Error", message: "The backup could not be made. Please try again later.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }

            // Reschedule the next backup; there may currently be a due background backup - we just need to schedule the next one
            // for a day/week from now.
            if #available(iOS 13.0, *) {
                AutoBackupManager.shared.scheduleBackup()
            }

            DispatchQueue.main.async {
                SVProgressHUD.dismiss()
            }
            self.reloadBackupInfo()
        }
    }

    /// Completion, if provided, is run on the main thread
    private func reloadBackupInfo(completion: (() -> Void)? = nil) {
        let backups = self.backupManager.readBackups()

        DispatchQueue.main.async {
            self.backupsInfo = backups
            self.tableView.reloadData()
            completion?()
        }
    }

    private func restore(from backup: BackupInfo) {
        // This is a powerful function. We need to hot-replace the entire persistent store which is holding the app's data, while the app is running!
        // To do this, we use the restoration manager, which reassigns the app's window's root view controller, which will result in the deallocation
        // all loaded view controllers (including this one) and all objects which are using managed objects or managed object contexts.
        UserEngagement.logEvent(.restoreFromBackup)
        BackupRestorationManager.shared.performRestore(from: backup)
    }

    private func restoreTabBarControllers() {
        guard let tabBarController = AppDelegate.shared.tabBarController else { preconditionFailure("No tab bar controller") }
        guard let lastVc = tabBarController.viewControllers?.last else { preconditionFailure("No last tab bar view controller") }

        // Get the new view controllers, but switch out the last one for the previous last one, which is the view controller
        // which holds the navigation stack which contains this view controller!
        var reinstantiatedViewControllers = tabBarController.getRootViewControllers()
        reinstantiatedViewControllers.removeLast()
        reinstantiatedViewControllers.append(lastVc)
        tabBarController.viewControllers = reinstantiatedViewControllers
        tabBarController.configureTabIcons()
    }
}

extension Backup: BackupFrequencyDelegate {
    func backupFrequencyDidChange() {
        // There is no backup frequency row when not logged in to iCloud, so just exit is this is the case.
        // We don't expect this to actually happen, though, as we don't allow access to the Backup Frequency view
        // when not logged in to iCloud.
        guard FileManager.default.ubiquityIdentityToken != nil else { return }

        DispatchQueue.main.async {
            // Ensure we use the latest backup frequency when the backup frequency changes.
            self.tableView.reloadRows(at: [IndexPath(row: 0, section: 2)], with: .none)
        }
    }
}
