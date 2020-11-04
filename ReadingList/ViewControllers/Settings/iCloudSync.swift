import Foundation
import UIKit
import CloudKit
import SVProgressHUD
import Reachability
import CoreData

class CloudSync: UITableViewController {

    @IBOutlet private weak var enabledSwitch: UISwitch!

    override func viewDidLoad() {
        super.viewDidLoad()
        monitorThemeSetting()
        enabledSwitch.isOn = GeneralSettings.iCloudSyncEnabled
        if !GeneralSettings.iCloudSyncEnabled && AppDelegate.shared.syncCoordinator?.reachability.connection == .none {
            enabledSwitch.isEnabled = false
        }
        NotificationCenter.default.addObserver(self, selector: #selector(networkConnectivityDidChange), name: .reachabilityChanged, object: nil)
    }

    @objc private func networkConnectivityDidChange() {
        guard !GeneralSettings.iCloudSyncEnabled else { return }
        enabledSwitch.isEnabled = AppDelegate.shared.syncCoordinator?.reachability.connection != .none
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        if #available(iOS 13.0, *) { } else {
            let theme = GeneralSettings.theme
            cell.defaultInitialise(withTheme: theme)
            cell.contentView.subviews.forEach {
                guard let label = $0 as? UILabel else { return }
                label.textColor = theme.titleTextColor
            }
        }
        return cell
    }

    @IBAction private func iCloudSyncSwitchChanged(_ sender: UISwitch) {
        if sender.isOn {
            syncSwitchTurnedOn()
        } else {
            syncSwitchTurnedOff()
        }
    }

    private func syncSwitchTurnedOn() {
        guard let syncCoordinator = AppDelegate.shared.syncCoordinator else { fatalError("Unexpected nil sync coordinator") }

        SVProgressHUD.show(withStatus: "Enabling iCloud")
        DispatchQueue.main.async {
            syncCoordinator.remote.initialise { error in
                DispatchQueue.main.async {
                    SVProgressHUD.dismiss()
                    if let error = error {
                        self.handleRemoteInitialiseError(error: error)
                        self.enabledSwitch.setOn(false, animated: true)
                    } else if self.nonRemoteBooksExistLocally() {
                        self.requestSyncMergeAction()
                    } else {
                        GeneralSettings.iCloudSyncEnabled = true
                        AppDelegate.shared.syncCoordinator!.start()
                    }
                }
            }
        }
    }

    private func nonRemoteBooksExistLocally() -> Bool {
        let fetch = NSManagedObject.fetchRequest(Book.self)
        fetch.predicate = NSPredicate(format: "%K = nil", #keyPath(Book.remoteIdentifier))
        return try! PersistentStoreManager.container.viewContext.count(for: fetch) != 0
    }

    private func requestSyncMergeAction() {
        // TODO: This is a misleading and incorrect message. Check whether there are books in iCloud already
        let alert = UIAlertController(title: "Data Already Exists", message: """
            iCloud sync has been enabled previously, so there may be books in iCloud already.

            You can either merge the list of books on this \(UIDevice.current.model) with the \
            books in iCloud, or you can choose to replace all the data on this \(UIDevice.current.model) \
            with the books already in iCloud.
            """, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Merge", style: .default) { _ in
            GeneralSettings.iCloudSyncEnabled = true
            AppDelegate.shared.syncCoordinator!.start()
        })
        alert.addAction(UIAlertAction(title: "Replace", style: .destructive) { [unowned self] _ in
            self.presentConfirmReplaceDialog()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [unowned self] _ in
            self.enabledSwitch.setOn(false, animated: true)
        })
        alert.popoverPresentationController?.setSourceCell(atIndexPath: IndexPath(row: 0, section: 0), inTable: tableView)
        present(alert, animated: true)
    }

    private func presentConfirmReplaceDialog() {
        let alert = UIAlertController(title: "Confirm Replace", message: """
            Are you sure you wish to replace the data on this \(UIDevice.current.model) with the data on iCloud?

            You will lose any books which are only stored on this \(UIDevice.current.model).
            """, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Replace", style: .destructive) { _ in
            PersistentStoreManager.delete(type: Book.self)
            GeneralSettings.iCloudSyncEnabled = true
            AppDelegate.shared.syncCoordinator!.start()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [unowned self] _ in
            self.enabledSwitch.setOn(false, animated: true)
        })
        alert.popoverPresentationController?.setSourceCell(atIndexPath: IndexPath(row: 0, section: 0), inTable: tableView)
        present(alert, animated: true)
    }

    private func syncSwitchTurnedOff() {
        guard let syncCoordinator = AppDelegate.shared.syncCoordinator else { fatalError("Unexpected nil sync coordinator") }

        let alert = UIAlertController(title: "Disable Sync?", message: """
            If you disable iCloud sync, changes you make will no longer be \
            synchronised across your devices, or backed up to iCloud.
            """, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Disable", style: .destructive) { _ in
            // TODO: Consider whether change tokens should be discarded, remote identifiers should be deleted, etc
            syncCoordinator.stop()
        })
        alert.addAction(UIAlertAction(title: "Keep Enabled", style: .cancel) { [unowned self] _ in
            self.enabledSwitch.isOn = true
        })
        alert.popoverPresentationController?.setSourceCell(atIndexPath: IndexPath(row: 0, section: 0), inTable: tableView)
        present(alert, animated: true)
    }

    private func handleRemoteInitialiseError(error: Error) {
        let alert: UIAlertController
        if let ckError = error as? CKError {
            switch ckError.code {
            case .networkFailure,
                 .networkUnavailable,
                 .serviceUnavailable:
                alert = UIAlertController(title: "Could not connect", message: "Could not connect to iCloud. Please try again later.", preferredStyle: .alert)
            case .notAuthenticated:
                alert = UIAlertController(title: "Not Signed In", message: "iCloud sync could not be enabled because you are not signed in to iCloud.", preferredStyle: .alert)
            default:
                alert = UIAlertController(title: "Could not enable iCloud sync", message: "An error occurred enabling iCloud sync.", preferredStyle: .alert)
            }
        } else {
            alert = UIAlertController(title: "Could not enable iCloud sync", message: "An unexpected error occurred enabling iCloud sync. Please try again later.", preferredStyle: .alert)
        }

        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true)
    }
}
