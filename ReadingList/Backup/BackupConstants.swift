import Foundation

/// Some shared constant values relating to the backup process.
struct BackupConstants {
    /// The name of the file used to record information relating to a backup.
    static let backupInfoFileName = "backup.info"

    /// The name of the archive which contains the backed up data.
    static let backupDataArchiveName = "data.zip"

    /// The directory within the ubiquity container which holds all the backups.
    static let backupsUbiquityContainerDirectoryName = "Backups"

    private init() { }
}
