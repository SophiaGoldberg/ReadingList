import Foundation
import UIKit
import CoreData
import ReadingList_Foundation
import ZIPFoundation
import os.log

final class BackupManager {
    /**
     Returns the Backups directory within the app's iCloud UbiquityContainer. Do not call on the Main thread, as this may take some time to return a value.
     */
    private var backupsDirectory: URL? {
        return FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Backups", isDirectory: true)
    }

    /**
     Returns the URL of the directory used as the current install's backup destination, within the app's iCloud UbiquityContainer. Do not call on the Main thread, as this may take some time to return a value.
     */
    private var currentInstallBackupDirectory: URL? {
        guard let backupsDirectory = backupsDirectory, let identifierForVendor = UIDevice.current.identifierForVendor else { return nil }
        return URL(fileURLWithPath: identifierForVendor.uuidString, isDirectory: true, relativeTo: backupsDirectory)
    }

    /**
     Do not call from the Main thread. Returns info about all the backups which are visible in the backup directory in the cloud ubiquity container.
     */
    func readBackups() -> [BackupInfo] {
        guard let backupsDirectory = backupsDirectory else { return [] }
        let backupsFolderContents: [URL]
        do {
            backupsFolderContents = try FileManager.default.pathsWithinDirectory(backupsDirectory)
        } catch {
            os_log("Could not read paths within directory %{public}s: %{public}s", type: .error, backupsDirectory.path, error.localizedDescription)
            return []
        }

        var backupInfos = [BackupInfo]()
        for backupFolder in backupsFolderContents {
            // For each backup folder, get the backup marker file path - this file will contain info about the backup
            let backupMarkerFilePath = URL(fileURLWithPath: BackupConstants.backupInfoFileName, relativeTo: backupFolder)
            let backupDataFilePath = URL(fileURLWithPath: BackupConstants.backupDataArchiveName, relativeTo: backupFolder)
            do {
                let markerFileData = try Data(contentsOf: backupMarkerFilePath)
                let markerFile = try JSONDecoder().decode(BackupMarkerFileInfo.self, from: markerFileData)
                let backupInfo = BackupInfo(markerFileInfo: markerFile, backupDirectory: backupFolder, backupDataFilePath: backupDataFilePath)
                backupInfos.append(backupInfo)
            } catch {
                os_log("Error getting backup info from file %{public}s: %{public}s", type: .error, backupFolder.path, error.localizedDescription)
                continue
            }
        }

        return backupInfos.sorted {
            $0.markerFileInfo.isPreferableTo($1.markerFileInfo)
        }
    }

    /// Enumerates the possible failures whicih may occur when performing a restoration.
    enum RestorationFailure: Error, CustomNSError {
        case unsupportedVersion
        case missingDataArchive
        case archiveDownloadTimeout
        case backupCreationFailure(Error)
        case unpackArchiveFailure(Error)
        case replaceStoreFailure(Error)
        case initialisationFailure(Error)
        indirect case errorRecoveryFailure(RestorationFailure)

        // Custom bridging to NSError to make reported errors a bit more intelligible. Just use sequential codes and the contained user infos.
        var errorCode: Int {
            switch self {
            case .unsupportedVersion: return 0
            case .missingDataArchive: return 1
            case .archiveDownloadTimeout: return 2
            case .backupCreationFailure: return 3
            case .unpackArchiveFailure: return 4
            case .replaceStoreFailure: return 5
            case .initialisationFailure: return 6
            case .errorRecoveryFailure: return 7
            }
        }

        var errorUserInfo: [String: Any] {
            switch self {
            case .backupCreationFailure(let error): return (error as NSError).userInfo
            case .unpackArchiveFailure(let error): return (error as NSError).userInfo
            case .replaceStoreFailure(let error): return (error as NSError).userInfo
            case .initialisationFailure(let error): return (error as NSError).userInfo
            case .errorRecoveryFailure(let error): return (error as NSError).userInfo
            default: return [:]
            }
        }
    }

    /**
     Replaces the current app's persistent store with that identified by the backup.
     Caution: calling this method required that no ManagedObjectContexts or ManagedObjects are in use throughout the app.
     */
    func restore(from backup: BackupInfo, completion: @escaping (RestorationFailure?) -> Void) {
        // First, check that we recognise the backup's model version. It must not be a later version that
        // what this version of the app supports.
        guard let modelVersion = BooksModelVersion(rawValue: backup.markerFileInfo.modelVersion) else {
            completion(.unsupportedVersion)
            return
        }
        guard FileManager.default.fileExists(atPath: backup.backupDataFilePath.path) else {
            completion(.missingDataArchive)
            return
        }

        // Unzip the backup data archive into a temporary directory
        let backupDataArchiveUnzipped = FileManager.default.createTemporaryDirectory()
        do {
            try FileManager.default.unzipItem(at: backup.backupDataFilePath, to: backupDataArchiveUnzipped)
        } catch {
            os_log("Error unzipping archive %{public}s: %{public}s", type: .error, backup.backupDataFilePath.path, error.localizedDescription)
            completion(.unpackArchiveFailure(error))
            return
        }
        let storeBackup = URL(fileURLWithPath: PersistentStoreManager.storeFileName, relativeTo: backupDataArchiveUnzipped)

        // Build a new persistent store coordinator to perform the move
        let storeCoordinator = NSPersistentStoreCoordinator(managedObjectModel: modelVersion.managedObjectModel())

        // To be safe, we want to backup the current store to a temporary directory. If we can't, then don't go ahead with the restore.
        let currentStoreBackupDir = FileManager.default.createTemporaryDirectory()
        let currentStoreBackup = currentStoreBackupDir.appendingPathComponent(PersistentStoreManager.storeFileName)
        do {
            try PersistentStoreManager.container.copyPersistentStores(to: currentStoreBackup)
        } catch {
            os_log("Error creating current store backup: %{public}s", type: .error, error.localizedDescription)

            // No need to keep the unzipped archive: delete it
            try? FileManager.default.removeItem(at: backupDataArchiveUnzipped)
            completion(.backupCreationFailure(error))
            return
        }

        var hasReplacedStore = false
        do {
            // Replace the current store with that from our cloud backup
            try storeCoordinator.replacePersistentStore(
                at: PersistentStoreManager.storeLocation,
                destinationOptions: nil,
                withPersistentStoreFrom: storeBackup,
                sourceOptions: nil,
                ofType: NSSQLiteStoreType
            )
            hasReplacedStore = true

            // We now need to reinitialise the persistent store. This will replace the persistent container in use in the app,
            // and migrate the store (if necessary) to the current version.
            try PersistentStoreManager.initalisePersistentStore {
                // Clear out temporary files - the current-store backup, and the backup unzip directory
                try? FileManager.default.removeItem(at: currentStoreBackupDir)
                try? FileManager.default.removeItem(at: backupDataArchiveUnzipped)

                // If we get here, then we have successully restored!
                completion(nil)
            }
        } catch {
            let restorationFailure: RestorationFailure = hasReplacedStore ? .initialisationFailure(error) : .replaceStoreFailure(error)
            // If we failed during the replacement of the store, then let's try to put the backup back in place, using the current (latest) managed object model.
            let restorationStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: BooksModelVersion.latest.managedObjectModel())
            do {
                try restorationStoreCoordinator.replacePersistentStore(
                    at: PersistentStoreManager.storeLocation,
                    destinationOptions: nil,
                    withPersistentStoreFrom: currentStoreBackup,
                    sourceOptions: nil,
                    ofType: NSSQLiteStoreType
                )

                try PersistentStoreManager.initalisePersistentStore {
                    // Clear out temporary files - the current-store backup, and the backup unzip directory
                    try? FileManager.default.removeItem(at: currentStoreBackupDir)
                    try? FileManager.default.removeItem(at: backupDataArchiveUnzipped)

                    // Remember that this does not represent success - we have succeeded in putting the backup back, but failed overall.
                    completion(restorationFailure)
                }
            } catch {
                // This is a serious failure, and it's not clear what this means. The existing store may be OK, or it may be broken.
                // We can try to hope that the app remains functional.
                os_log("Error while attempting store recovery during backup restoration. The persistent store is now in an unknown state. %{public}s", type: .error, error.localizedDescription)

                // Clear out temporary files - the current-store backup, and the backup unzip directory
                try? FileManager.default.removeItem(at: currentStoreBackupDir)
                try? FileManager.default.removeItem(at: backupDataArchiveUnzipped)

                completion(.errorRecoveryFailure(restorationFailure))
            }
        }
    }

    /// Enumerates some errors which may occur when performing a backup.
    enum BackupError: Int, Error {
        #if DEBUG
        case simulatedError = -1
        #endif
        case noContainerUrl = 0
        case noDeviceIdentifierAvailable = 1
    }

    /**
     Performs a backup of the current store into the Backups iCloud directory.
     Do not call from the Main thread.
     */
    @discardableResult
    func performBackup() throws -> BackupInfo {
        guard let currentInstallBackupDirectory = currentInstallBackupDirectory else { throw BackupError.noContainerUrl }
        guard UIDevice.current.identifierForVendor != nil else { throw BackupError.noDeviceIdentifierAvailable }
        #if DEBUG
        guard !Debug.simulateBackupFailure else { throw BackupError.simulatedError }
        #endif

        // Get the target data directory
        let dataArchivePath = URL(fileURLWithPath: BackupConstants.backupDataArchiveName, isDirectory: false, relativeTo: currentInstallBackupDirectory)
        os_log("Writing backup to %{public}s", dataArchivePath.path)

        // Ensure the backup directory exists
        try? FileManager.default.createDirectory(at: currentInstallBackupDirectory, withIntermediateDirectories: true, attributes: nil)

        // Perform the backup
        let backupTemporaryLocation = FileManager.default.createTemporaryDirectory()
        try PersistentStoreManager.container.copyPersistentStores(to: backupTemporaryLocation, overwriting: false)
        try? FileManager.default.removeItem(at: dataArchivePath)
        try FileManager.default.zipItem(at: backupTemporaryLocation, to: dataArchivePath, shouldKeepParent: false)
        try? FileManager.default.removeItem(at: backupTemporaryLocation)

        // Now gather the data for the backup marker file
        let backupInfoURL = URL(fileURLWithPath: BackupConstants.backupInfoFileName, relativeTo: currentInstallBackupDirectory)

        // Remove any existant item (if there is one)
        try? FileManager.default.removeItem(at: backupInfoURL)

        // Calculate the backup's size. We keep this infomation in the backup info file, for quick and easy retrieval of the data
        // when the backup is not held on the local device.
        let backupSize: UInt64
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: dataArchivePath.path)
            if let sizeAttribute = attributes[.size] as? UInt64 {
                backupSize = sizeAttribute
            } else {
                os_log("Unexpected missing or non UInt64 size attribute", type: .error)
                backupSize = 0
            }
        } catch {
            os_log("Error calculating backup size on disk: %{public}s", type: .error, error.localizedDescription)
            backupSize = 0
        }

        // JSON encode the marker file info and write to the suitable file path
        guard let markerFileInfo = BackupMarkerFileInfo(size: backupSize) else {
            // We already checked that UIDevice.current.identifierForVendor is non-nil at the top of this function; it should
            // not go from being non-nil to being nil. The only reason BackupMarkerFileInfo.init() may return nil is if
            // identifierForVendor is nil.
            preconditionFailure("BackupMarkerFileInfo.init() unexpectedly returned nil")
        }
        let markerFileData = try JSONEncoder().encode(markerFileInfo)
        try markerFileData.write(to: backupInfoURL)
        return BackupInfo(markerFileInfo: markerFileInfo, backupDirectory: currentInstallBackupDirectory, backupDataFilePath: dataArchivePath)
    }
}
