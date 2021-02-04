import Foundation
import UIKit
import os.log

// To make BackupMarkerFileInfo conform to Codable.
extension UIUserInterfaceIdiom: Codable { }

/// A collection of data relating to a backup, which is to be JSON encoded and stored on disk alongside a backup data archive.
/// Warning: be very careful about changing this struct definition: any changes are likely to cause the app to fail to deserialise
/// existing backup info files. If changes are needed, some kind of versioning system will likely be needed.
struct BackupMarkerFileInfo: Codable, Equatable {
    /** An identifier which is persistent for this device, but which changes when the app is deleted and reinstalled. See:
        ```The value in this property remains the same while the app (or another app from the same vendor)
           is installed on the iOS device. The value changes when the user deletes all of that vendor’s apps
           from the device and subsequently reinstalls one or more of them.```
    */
    let deviceVendorIdentifier: UUID
    let deviceName: String
    let created: Date
    let deviceIdiom: UIUserInterfaceIdiom
    /// The managed object model version associated with this backup.
    let modelVersion: String
    /// The size of the backup data archive, in bytes.
    let sizeBytes: UInt64

    /// Returns nil if `UIDevice.current.identifierForVendor` returns nil. This may be the case if the device has been restarted and not yet unlocked.
    init?(size: UInt64) {
        guard let identifierForVendor = UIDevice.current.identifierForVendor else { return nil }
        deviceVendorIdentifier = identifierForVendor
        sizeBytes = size
        created = Date()
        deviceName = UIDevice.current.name
        modelVersion = BooksModelVersion.latest.rawValue
        deviceIdiom = UIDevice.current.userInterfaceIdiom
    }

    /**
     Returns wheter this backup should be considered a "better" backup to use than the other backup provided.
     Backups from the same device, then same  are preferred,
     */
    func isPreferableTo(_ other: BackupMarkerFileInfo) -> Bool {
        let thisIsFromCurrentDevice = (deviceVendorIdentifier == UIDevice.current.identifierForVendor)
        let otherIsFromCurrentDevice = (other.deviceVendorIdentifier == UIDevice.current.identifierForVendor)
        if thisIsFromCurrentDevice && !otherIsFromCurrentDevice { return true }
        if !thisIsFromCurrentDevice && otherIsFromCurrentDevice { return false }
        return created < other.created
    }
}

/// Information relating to a backup: data from the info file, along with the paths to the folder and data archive on disk.
struct BackupInfo: Equatable {
    let markerFileInfo: BackupMarkerFileInfo
    let backupDirectory: URL
    let backupDataFilePath: URL
}
