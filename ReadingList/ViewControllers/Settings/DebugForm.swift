#if DEBUG

import Foundation
import Eureka
import SVProgressHUD

final class DebugForm: FormViewController {

    @objc func dismissSelf() {
        dismiss(animated: true, completion: nil)
    }

    private func writeToTempFile(data: [SharedBookData]) -> URL {
        let encoded = try! JSONEncoder().encode(data)
        let temporaryFilePath = URL.temporary(fileWithName: "shared_current-books.json")
        try! encoded.write(to: temporaryFilePath)
        return temporaryFilePath
    }

    override func viewDidLoad() {
        if #available(iOS 13.0, *) {
            initialiseInsetGroupedTable()
        }

        super.viewDidLoad()

        navigationItem.title = "Debug"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Dismiss", style: .plain, target: self, action: #selector(dismissSelf))

        form +++ Section(header: "Test data", footer: "Import a set of data for both testing and screenshots")
            <<< ButtonRow {
                $0.title = "Import Test Data"
                $0.onCellSelection { _, _ in
                    SVProgressHUD.show(withStatus: "Loading Data...")
                    Debug.loadData(downloadImages: true) {
                        SVProgressHUD.dismiss()
                    }
                }
            }
            <<< ButtonRow {
                $0.title = "Export Shared Data (Current Books)"
                $0.onCellSelection { [weak self] cell, _ in
                    guard let `self` = self else { return }
                    let temporaryFilePath = self.writeToTempFile(data: SharedBookData.currentBooks)
                    let activityViewController = UIActivityViewController(activityItems: [temporaryFilePath], applicationActivities: [])
                    if let popover = activityViewController.popoverPresentationController {
                        popover.sourceView = cell
                        popover.sourceRect = cell.frame
                    }
                    self.present(activityViewController, animated: true, completion: nil)
                }
            }
            <<< ButtonRow {
                $0.title = "Export Shared Data (Finished Books)"
                $0.onCellSelection { [weak self] cell, _ in
                    guard let `self` = self else { return }
                    let temporaryFilePath = self.writeToTempFile(data: SharedBookData.finishedBooks)
                    let activityViewController = UIActivityViewController(activityItems: [temporaryFilePath], applicationActivities: [])
                    if let popover = activityViewController.popoverPresentationController {
                        popover.sourceView = cell
                        popover.sourceRect = cell.frame
                    }
                    self.present(activityViewController, animated: true, completion: nil)
                }
            }

        +++ Section("Debug Controls")
            <<< SwitchRow {
                $0.title = "Show sort number"
                $0.value = Debug.showSortNumber
                $0.onChange {
                    Debug.showSortNumber = $0.value ?? false
                }
            }

        +++ Section("Error reporting")
            <<< ButtonRow {
                $0.title = "Crash"
                $0.cellUpdate { cell, _ in
                    cell.textLabel?.textColor = .red
                }
                $0.onCellSelection { _, _ in
                    fatalError("Test Crash")
                }
            }

        monitorThemeSetting()
    }
}

#endif
