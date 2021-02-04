import Foundation
import UIKit
import SVProgressHUD
import CoreData
import ReadingList_Foundation

final class ImportExport: UITableViewController {

    private let deleteAllDataIndex = IndexPath(row: 0, section: 1)

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath {
        case IndexPath(row: 0, section: 0): exportData(presentingIndexPath: indexPath)
        case IndexPath(row: 1, section: 0): break
        case deleteAllDataIndex: deleteAllData()
        default: assertionFailure()
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func exportData(presentingIndexPath: IndexPath) {
        UserEngagement.logEvent(.csvExport)
        SVProgressHUD.show(withStatus: "Generating...")

        // Although CharacterSet.urlPathAllowed exists, it seems that the set of allowed characters in a
        // filename is much less retrictive than .urlPathAllowed suggests. The URL is escaping the disallowed
        // characters, which are then unescaped when the file is created. The only character which is definitely
        // not allowed is a forward slash, since it is the directory separator.
        let sanitisedDeviceName = UIDevice.current.name.replacingOccurrences(of: "/", with: "")
        let temporaryFilePath = URL.temporary(fileWithName: "Reading List - \((sanitisedDeviceName)) - \(Date().string(withDateFormat: "yyyy-MM-dd hh-mm")).csv")
        let exporter = CsvExporter(filePath: temporaryFilePath, csvExport: BookCSVColumn.export)

        let exportAll = NSManagedObject.fetchRequest(Book.self)
        exportAll.sortDescriptors = [
            NSSortDescriptor(\Book.readState),
            NSSortDescriptor(\Book.sort),
            NSSortDescriptor(\Book.startedReading),
            NSSortDescriptor(\Book.finishedReading)]
        exportAll.relationshipKeyPathsForPrefetching = [#keyPath(Book.subjects), #keyPath(Book.authors), #keyPath(Book.listItems)]
        exportAll.returnsObjectsAsFaults = false
        exportAll.fetchBatchSize = 50

        let context = PersistentStoreManager.container.viewContext.childContext(concurrencyType: .privateQueueConcurrencyType, autoMerge: false)
        context.perform {
            let results = try! context.fetch(exportAll)
            exporter.addData(results)
            DispatchQueue.main.async {
                self.serveCsvExport(filePath: temporaryFilePath, presentingIndexPath: presentingIndexPath)
            }
        }
    }

    func serveCsvExport(filePath: URL, presentingIndexPath: IndexPath) {
        // Present a dialog with the resulting file
        let activityViewController = UIActivityViewController(activityItems: [filePath], applicationActivities: [])
        activityViewController.excludedActivityTypes = UIActivity.ActivityType.documentUnsuitableTypes
        activityViewController.popoverPresentationController?.setSourceCell(atIndexPath: presentingIndexPath, inTable: self.tableView)

        SVProgressHUD.dismiss()
        self.present(activityViewController, animated: true, completion: nil)
    }

    func deleteAllData() {
        // The CONFIRM DELETE action:
        let confirmDelete = UIAlertController(title: "Final Warning", message: "This action is irreversible. Are you sure you want to continue?", preferredStyle: .alert)
        confirmDelete.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            DeleteAllManager.shared.deleteAll()
            UserEngagement.logEvent(.deleteAllData)
        })
        confirmDelete.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // The initial WARNING action
        let areYouSure = UIAlertController(title: "Warning", message: "This will delete all books saved in the application. Are you sure you want to continue?", preferredStyle: .alert)
        areYouSure.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            self.present(confirmDelete, animated: true)
        })
        areYouSure.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        present(areYouSure, animated: true)
    }
}
