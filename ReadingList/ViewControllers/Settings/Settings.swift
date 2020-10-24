import UIKit
import MessageUI
import ReadingList_Foundation
import FirebaseCrashlytics

final class Settings: UITableViewController {

    static let appStoreAddress = "itunes.apple.com/gb/app/reading-list-book-tracker/id1217139955"
    static let feedbackEmailAddress = "feedback@readinglist.app"
    static let importExportIndexPath = IndexPath(row: 2, section: 1)

    @IBOutlet private var headerLabels: [UILabel]!
    @IBOutlet private weak var versionLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        versionLabel.text = "v\(BuildInfo.thisBuild.versionAndConfiguration)"
        monitorThemeSetting()

        #if DEBUG
        tableView.tableHeaderView!.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(onLongPressHeader(_:))))
        #endif

        DispatchQueue.main.async {
            // isSplit does not work correctly before the view is loaded; run this later
            if self.splitViewController!.isSplit {
                self.tableView.selectRow(at: IndexPath(row: 0, section: 0), animated: false, scrollPosition: .none)
            }
        }
    }

    #if DEBUG
    @objc func onLongPressHeader(_ recognizer: UILongPressGestureRecognizer) {
        present(DebugForm().inThemedNavController(), animated: true, completion: nil)
    }
    #endif

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        guard motion == .motionShake else { return }
        guard BuildInfo.thisBuild.type != .appStore else { return }
        let alert = UIAlertController(title: "Perform Test Crash?", message: """
            For testing purposes, you can trigger a crash. This can be used to verify \
            that the crash reporting tools are working correctly.

            Note: you are only seeing this because you are running a beta version of this app.
            """, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Crash", style: .destructive) { _ in
            fatalError("Test Crash")
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let selectedIndex = tableView.indexPathForSelectedRow, !splitViewController!.isSplit {
            tableView.deselectRow(at: selectedIndex, animated: true)
        }
    }

    override func initialise(withTheme theme: Theme) {
        if #available(iOS 13.0, *) { return }
        super.initialise(withTheme: theme)
        headerLabels.forEach { $0.textColor = theme.titleTextColor }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        if #available(iOS 13.0, *) { } else {
            cell.defaultInitialise(withTheme: GeneralSettings.theme)
        }
        if splitViewController?.isSplit == true {
            // In split mode, change the cells a little to look more like the standard iOS settings app
            cell.selectedBackgroundView = UIView(backgroundColor: UIColor(.splitViewCellSelection))
            cell.textLabel!.highlightedTextColor = .white
            cell.accessoryType = .none
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch (indexPath.section, indexPath.row) {
        case (0, 1):
            UIApplication.shared.open(URL(string: "itms-apps://\(Settings.appStoreAddress)?action=write-review")!, options: [:])
        default:
            return
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension Settings: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        dismiss(animated: true)
    }
}
