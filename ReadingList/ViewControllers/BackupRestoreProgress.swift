import Foundation
import UIKit
import os.log

/// The possible states which a backup restoration may end with.
enum BackupRestoreResult {
    case success
    case failure(BackupManager.RestorationFailure)
    case cancelled
}

/// A view controller which manages a view, intended for full screen use, which displays a spinner and the text "Restoring..."
final class BackupRestoreProgress: FullScreenProgress {
    fileprivate enum Mode {
        case downloading
        case restoring
    }

    convenience init(backupInfo: BackupInfo, completion: @escaping (BackupRestoreResult) -> Void) {
        self.init()
        self.backupInfo = backupInfo
        self.completion = completion
    }

    /// The backup to restore from.
    var backupInfo: BackupInfo!

    /// An action to take when the backup restoration is finished.
    var completion: ((BackupRestoreResult) -> Void)!

    private let startTime = Date()
    private let maximumDownloadDuration: TimeInterval = 30
    private var mode = Mode.restoring

    override func viewDidLoad() {
        startDownloadAndRestoreProcess()
        super.viewDidLoad()
    }

    override func onCancel() {
        stopAndRemoveQuery()
        completion(.cancelled)
    }

    override func labelText() -> String {
        return mode.description
    }

    override func showCancelButton() -> Bool {
        return mode == .downloading
    }

    // Backup download management
    private let downloadQueryDispatchQueue = DispatchQueue(label: "com.andrewbennet.books.BackupDownload", qos: .userInitiated)
    private lazy var downloadOperationQueue: OperationQueue = {
        let operationQueue = OperationQueue()
        operationQueue.underlyingQueue = self.downloadQueryDispatchQueue
        operationQueue.maxConcurrentOperationCount = 1
        return operationQueue
    }()
    private var backupDataFileQuery: NSMetadataQuery?

    private func startDownloadAndRestoreProcess() {
        let isDownloaded: Bool
        do {
            isDownloaded = try backupInfo.backupDataFilePath.isDownloaded()
        } catch {
            os_log("Could not determine whether file is downloaded: %{public}s", type: .error, error.localizedDescription)
            isDownloaded = false
        }
        mode = isDownloaded ? .restoring : .downloading

        if isDownloaded {
            os_log("Backup data is already downloaded: restoring")
            restoreData(using: backupInfo)
        } else {
            os_log("Backup data is not downloaded: downloading then restoring")
            downloadThenRestore(backup: backupInfo)
        }
    }

    private func stopAndRemoveQuery() {
        NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidFinishGathering, object: backupDataFileQuery)
        NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidUpdate, object: backupDataFileQuery)
        NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryGatheringProgress, object: backupDataFileQuery)
        self.backupDataFileQuery?.stop()
        self.backupDataFileQuery = nil
        self.periodicDownloadStatusCheck?.cancel()
        self.periodicDownloadStatusCheck = nil
    }

    @objc private func checkDownloadProgress() {
        guard let backupDataFileQuery = backupDataFileQuery else { return }
        let results = backupDataFileQuery.results
        guard results.count == 1, let metadataItem = results[0] as? NSMetadataItem else {
            os_log("MetadataQuery did not return a NSMetadataItem for the data archive", type: .error)
            completion(.failure(.missingDataArchive))
            return
        }
        guard let downloadingStatus = metadataItem.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String else {
            os_log("Could not get downloading status for metadata item", type: .error)
            return
        }

        os_log("Download status: %{public}s", type: .info, downloadingStatus)
        if downloadingStatus == NSMetadataUbiquitousItemDownloadingStatusCurrent {
            os_log("Backup archive is downloaded; stopping query & restoring data...")
            stopAndRemoveQuery()

            #if DEBUG
            // For development ease, allow us to enter a mode where the downloading screen is held in place for a long time
            if Debug.stayOnBackupRestorationDownloadScreen {
                os_log("Debug setting stayOnBackupRestorationDownloadScreen is true; remaining on download view")
                return
            }
            #endif

            mode = .restoring
            // Update the UI to reflect that we are on the next stage of the restoration process
            DispatchQueue.main.async {
                self.updateView()
            }

            restoreData(using: backupInfo)
        }
    }

    var periodicDownloadStatusCheck: DispatchWorkItem?

    private func downloadThenRestore(backup: BackupInfo) {
        // A metadata query is used to watch the data archive file and detect when the file is locally available
        let downloadProgressQuery = NSMetadataQuery()
        downloadProgressQuery.searchScopes = [NSMetadataQueryUbiquitousDataScope]
        downloadProgressQuery.predicate = NSPredicate(format: "%K == %@", NSMetadataItemPathKey, backup.backupDataFilePath.path)
        NotificationCenter.default.addObserver(self, selector: #selector(checkDownloadProgress), name: .NSMetadataQueryDidFinishGathering, object: downloadProgressQuery)
        NotificationCenter.default.addObserver(self, selector: #selector(checkDownloadProgress), name: .NSMetadataQueryDidUpdate, object: downloadProgressQuery)
        NotificationCenter.default.addObserver(self, selector: #selector(checkDownloadProgress), name: .NSMetadataQueryGatheringProgress, object: downloadProgressQuery)
        downloadProgressQuery.operationQueue = downloadOperationQueue
        downloadProgressQuery.start()

        // Keep a reference to the query on self so that it is not deallocated once this function returns
        backupDataFileQuery = downloadProgressQuery

        // Kick off the download
        do {
            try FileManager.default.startDownloadingUbiquitousItem(at: backup.backupDataFilePath)
        } catch {
            stopAndRemoveQuery()
            self.completion(.failure(.missingDataArchive))
            return
        }

        // We are not meant to poll to check download state, but the notifications sent when a download is compelete seems to be
        // unreliable. Schedule a download status check every 5 seconds, and if enough time passes without the download completing,
        // we will cancel and return a failure.
        scheduleNextPeriodicDownloadCheck()
    }

    private func scheduleNextPeriodicDownloadCheck() {
        let workItem = DispatchWorkItem {
            if Date(timeInterval: self.maximumDownloadDuration, since: self.startTime) < Date() {
                os_log("Maximum download duration has elapsed; returning timeout error", type: .error)
                self.stopAndRemoveQuery()
                self.completion(.failure(.archiveDownloadTimeout))
                return
            }
            os_log("Periodic download status check running", type: .info)
            self.checkDownloadProgress()
            if self.mode == .downloading {
                os_log("Backup archive is still downloading after periodic download status check; scheduling next check", type: .info)
                self.scheduleNextPeriodicDownloadCheck()
            }
        }
        periodicDownloadStatusCheck = workItem
        os_log("Scheduling periodic download check to run 5 seconds from now", type: .info)
        downloadQueryDispatchQueue.asyncAfter(deadline: .now() + 5, execute: workItem)
    }

    private func restoreData(using backup: BackupInfo) {
        // Restore on a background thread
        downloadQueryDispatchQueue.async {
            self.periodicDownloadStatusCheck?.cancel()
            BackupManager().restore(from: backup) { error in
                if let error = error {
                    os_log("Error restoring backup: %{public}s", type: .error, error.localizedDescription)
                    self.completion(.failure(error))
                    return
                }
                self.completion(.success)
            }
        }
    }
}

extension BackupRestoreProgress.Mode: CustomStringConvertible {
    var description: String {
        switch self {
        case .downloading: return "Downloading..."
        case .restoring: return "Restoring..."
        }
    }
}
