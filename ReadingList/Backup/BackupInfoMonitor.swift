import Foundation
import os.log

/// A utility which can watch for cloud changes to backup info files, and requests their download when they are detected.
final class BackupInfoMonitor {

    /// A global instance which is used to monitor for backup info file changes in the background.
    static let shared = BackupInfoMonitor()

    /// Is set to `true` when the initial set of backup info files are all reported to have been downloaded.
    private(set) var hasDownloadedAllInitialInfoFiles = false

    /// A utility dispatch queue upon which work is done.
    private let dispatchQueue = DispatchQueue(label: "com.andrewbennet.books.BackupInfoMonitor", qos: .utility)

    /// The metadata query which watches for backup info files on iCloud.
    private let infoFilesQuery: NSMetadataQuery

    /// The metadata query which watches for data archive files on iCloud.
    private let backupArchiveQuery: NSMetadataQuery

    /// Set to the set of info file paths which are present when the metadata query first completes.
    private var initialInfoFiles: Set<URL>?

    /// Holds the last seen download state of all known backup info files, by their path.
    private var infoFilesDownloadState = [URL: Bool]()

    /// Holds the last seen upload state of the known backup archive files, by their path.
    private var archiveFileUploadState = [URL: Bool]()

    /// For use in the `userInfo` dictionary of backup archive upload state notifications.
    static let backupArchiveUploadStateKey = "backupArchiveUploadStateKey"

    private init() {
        let operationQueue = OperationQueue()
        operationQueue.underlyingQueue = dispatchQueue
        operationQueue.maxConcurrentOperationCount = 1

        // Create a metadata query which will watch for the backup info files - these are small,
        // so quick to download and small enough for us to keep downloaded without worrying about
        // unnecessaily consuming local disk space.
        infoFilesQuery = NSMetadataQuery()
        infoFilesQuery.searchScopes = [NSMetadataQueryUbiquitousDataScope]
        infoFilesQuery.predicate = NSPredicate(format: "%K == %@", NSMetadataItemFSNameKey, BackupConstants.backupInfoFileName)
        infoFilesQuery.operationQueue = operationQueue

        // Create a second metadata query which will watch for changes in the backup archives; we don't
        // automatically download these, but we do want to observe changes in their upload state.
        backupArchiveQuery = NSMetadataQuery()
        backupArchiveQuery.searchScopes = [NSMetadataQueryUbiquitousDataScope]
        backupArchiveQuery.predicate = NSPredicate(format: "%K == %@", NSMetadataItemFSNameKey, BackupConstants.backupDataArchiveName)
        backupArchiveQuery.operationQueue = operationQueue
    }

    deinit {
        stop()
    }

    /**
     Starts the metadata query and registers observers for the notifications it sends.
     */
    func start() {
        os_log("Starting backup info cloud change observations")

        dispatchQueue.async {
            // "In iOS, you must call this method at least once before trying to search for cloud-based files in the ubiquity container."
            FileManager.default.url(forUbiquityContainerIdentifier: nil)

            // Start observing query gathering completion
            NotificationCenter.default.addObserver(self, selector: #selector(self.processInfoQueryDidFinishGathering(_:)), name: .NSMetadataQueryDidFinishGathering, object: self.infoFilesQuery)
            NotificationCenter.default.addObserver(self, selector: #selector(self.processInfoQueryUpdateOrProgress(_:)), name: .NSMetadataQueryDidUpdate, object: self.infoFilesQuery)
            NotificationCenter.default.addObserver(self, selector: #selector(self.processInfoQueryUpdateOrProgress(_:)), name: .NSMetadataQueryGatheringProgress, object: self.infoFilesQuery)

            // Start observing subsequent changes to the backup data archives: this will allow us to detect upload completion
            NotificationCenter.default.addObserver(self, selector: #selector(self.processArchiveQueryUpdate(_:)), name: .NSMetadataQueryDidUpdate, object: self.infoFilesQuery)
            NotificationCenter.default.addObserver(self, selector: #selector(self.processArchiveQueryUpdate(_:)), name: .NSMetadataQueryGatheringProgress, object: self.infoFilesQuery)

            self.infoFilesQuery.start()
            self.backupArchiveQuery.start()
        }
    }

    /**
     Removes notification obsevers and stops the metadata query.
     */
    func stop() {
        os_log("Stopping backup info cloud change observations")

        infoFilesQuery.stop()
        backupArchiveQuery.stop()
        NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidFinishGathering, object: infoFilesQuery)
        NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidUpdate, object: infoFilesQuery)
        NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryGatheringProgress, object: infoFilesQuery)
        NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidUpdate, object: backupArchiveQuery)
        NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryGatheringProgress, object: backupArchiveQuery)
    }

    @objc private func processInfoQueryDidFinishGathering(_ notification: Notification) {
        handleQueryNotification(isInitialGatheringCompletion: true)
    }

    @objc private func processInfoQueryUpdateOrProgress(_ notification: Notification) {
        handleQueryNotification(isInitialGatheringCompletion: false)
    }

    @objc private func processArchiveQueryUpdate(_ notification: Notification) {
        // By running the response on the dispatchQueue, we don't need to worry about concurrent changes to the results
        // causing index access errors.
        dispatchQueue.async {
            os_log("Backup Archive metadata query returned %d items", type: .info, self.backupArchiveQuery.resultCount)

            // Run through the indices of the results, checking for the upload state of each archive
            var seenUploadStates = [URL: Bool]()
            for resultIndex in 0..<self.backupArchiveQuery.resultCount {
                guard let resultItemMetadata = self.backupArchiveQuery.result(at: resultIndex) as? NSMetadataItem,
                      let fileItemURL = resultItemMetadata.value(forAttribute: NSMetadataItemURLKey) as? URL else {
                    os_log("Unexpected query result type, or missing item URL", type: .error)
                    continue
                }

                if let uploadStatus = resultItemMetadata.value(forAttribute: NSMetadataUbiquitousItemIsUploadedKey) as? NSNumber {
                    seenUploadStates[fileItemURL] = uploadStatus.boolValue
                } else {
                    os_log("Unexpected lack of upload state for %{public}s", type: .error, fileItemURL.path)
                }
            }

            // If the upload state has changed, post a notification with the new uplaod states in the user info.
            if self.archiveFileUploadState != seenUploadStates {
                self.archiveFileUploadState = seenUploadStates
                let notification = Notification(
                    name: .backupArchiveUploadStateChanges,
                    object: nil,
                    userInfo: [BackupInfoMonitor.backupArchiveUploadStateKey: seenUploadStates]
                )
                NotificationCenter.default.post(notification)
            }
        }
    }

    private func handleQueryNotification(isInitialGatheringCompletion: Bool) {
        // By running the response on the dispatchQueue, we don't need to worry about concurrent changes to the results
        // causing index access errors.
        dispatchQueue.async {
            os_log("Backup Info metadata query returned %d items", type: .info, self.infoFilesQuery.resultCount)

            // Run through the indices of the results, firing off download of any non-downlaoded
            var seenDownloadStates = [URL: Bool]()
            for resultIndex in 0..<self.infoFilesQuery.resultCount {
                guard let resultItemMetadata = self.infoFilesQuery.result(at: resultIndex) as? NSMetadataItem,
                      let fileItemURL = resultItemMetadata.value(forAttribute: NSMetadataItemURLKey) as? URL else {
                    os_log("Unexpected query result type, or missing item URL", type: .error)
                    continue
                }

                if let downloadStatus = resultItemMetadata.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String,
                   downloadStatus == NSMetadataUbiquitousItemDownloadingStatusCurrent {
                    seenDownloadStates[fileItemURL] = true
                    continue
                }
                seenDownloadStates[fileItemURL] = false

                do {
                    os_log("Requesting download of query result %{public}s", type: .info, fileItemURL.path)
                    try FileManager.default.startDownloadingUbiquitousItem(at: fileItemURL)
                } catch {
                    os_log("Error starting download of iCloud item %{public}s", type: .error, fileItemURL.path)
                }
            }

            // Remember the set of file paths which were initially present, if this is the initial gather completion. This will be
            // used to track when all of the initial present files are downloaded, upon which event a notification will be pushed.
            if isInitialGatheringCompletion {
                assert(self.initialInfoFiles == nil)
                self.initialInfoFiles = Set(seenDownloadStates.map(\.key))
                os_log("Initial metadata query completed with %d results", self.infoFilesQuery.resultCount)
            }

            // Check for differences in the set of files which are downloaded.
            let downloadedFiles = Set(seenDownloadStates.filter { $0.value }.map(\.key))
            let previousDownloadedFiles = Set(self.infoFilesDownloadState.filter { $0.value }.map(\.key))
            if downloadedFiles != previousDownloadedFiles {
                self.infoFilesDownloadState = seenDownloadStates
                os_log("Set of downloaded backup info files changed; posting notification", type: .info)
                NotificationCenter.default.post(name: .backupInfoFilesChanged, object: nil)
            }
            self.infoFilesDownloadState = seenDownloadStates

            // If we've got a record of the initial set of files, and we haven't yet recorded that we've downloaded the initial
            // set of files, but we can see now that they are all downloaded, then flip the toggle and post a notification saying so.
            if let initialInfoFiles = self.initialInfoFiles,
               !self.hasDownloadedAllInitialInfoFiles,
               initialInfoFiles.allSatisfy({ self.infoFilesDownloadState[$0] ?? false }) {
                os_log("Initial set of info files are all downloaded; posting didDownloadInitialBackupInfoFiles notification")
                self.hasDownloadedAllInitialInfoFiles = true
                NotificationCenter.default.post(name: .initialBackupInfoFilesDownloaded, object: nil)
            }
        }
    }
}

extension Notification.Name {
    /// Posted when the initially present backup.info files are all downloaded.
    static let initialBackupInfoFilesDownloaded = Notification.Name(rawValue: "initialBackupInfoFilesDownloaded")

    /// Posted when the set of downloaded backup.info files has downloaded.
    static let backupInfoFilesChanged = Notification.Name(rawValue: "backupInfoFilesChanged")

    /// Posted when an upload state of a backup archive is changed.
    static let backupArchiveUploadStateChanges = Notification.Name(rawValue: "backupArchiveUploadStateChanges")
}
