import Foundation

enum BackupDestinationKind: String, CaseIterable, Identifiable, Codable {
    /// TXAWPAY's own Documents folder. Visible in Files → On My iPhone → TXAWPAY,
    /// but deleted together with the app. Never treated as an external backup.
    case onDevice
    /// The app's iCloud Drive folder (iCloud Drive → TXAWPAY). Needs the iCloud
    /// Documents entitlement and a signed-in iCloud account.
    case iCloudDrive
    /// Any folder the user picks in the Files app (iCloud Drive, On My iPhone,
    /// a USB drive, or a cloud provider such as Google Drive or Dropbox).
    case folder

    var id: String { rawValue }

    var label: String {
        switch self {
        case .onDevice: "On this iPhone only"
        case .iCloudDrive: "iCloud Drive"
        case .folder: "Folder in Files"
        }
    }

    var symbol: String {
        switch self {
        case .onDevice: "iphone"
        case .iCloudDrive: "icloud"
        case .folder: "folder"
        }
    }

    var explanation: String {
        switch self {
        case .onDevice:
            "Files are saved inside TXAWPAY's own storage and appear in Files → On My iPhone → TXAWPAY. They are deleted if you delete the app, so this is not a safe backup on its own."
        case .iCloudDrive:
            "Files are saved to iCloud Drive → TXAWPAY and upload automatically. They stay in iCloud Drive if the app is deleted, and you can open them on any device."
        case .folder:
            "Choose any folder in the Files app, such as a folder in iCloud Drive, a USB drive, or another storage provider. TXAWPAY creates a TXAWPAY folder inside it."
        }
    }
}

/// Resolved, ready-to-use location of the `TXAWPAY` folder.
struct ResolvedBackupRoot: Sendable {
    let kind: BackupDestinationKind
    /// …/TXAWPAY
    let rootURL: URL
    /// The security-scoped URL that must be "accessed" while writing (folder destination only).
    let scopedURL: URL?
    /// True when the files live in iCloud Drive (uploads must be confirmed).
    let isUbiquitous: Bool

    var journalURL: URL { rootURL.appendingPathComponent("Journal Backups", isDirectory: true) }
    var mediaURL: URL { journalURL.appendingPathComponent("Media", isDirectory: true) }
    var historyURL: URL { journalURL.appendingPathComponent("Version History", isDirectory: true) }
    var manifestURL: URL { journalURL.appendingPathComponent("manifest.json") }
    var displayPath: String {
        switch kind {
        case .onDevice: "On My iPhone › TXAWPAY › Journal Backups"
        case .iCloudDrive: "iCloud Drive › TXAWPAY › Journal Backups"
        case .folder: "\(scopedURL?.lastPathComponent ?? "Folder") › TXAWPAY › Journal Backups"
        }
    }
}

enum BackupDestinationError: LocalizedError {
    case iCloudUnavailable
    case iCloudNotSignedIn
    case noFolderSelected
    case folderAccessLost
    case permissionDenied(String)

    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable:
            "iCloud Drive isn't available to this build of TXAWPAY. Choose a folder in Files instead (you can pick a folder inside iCloud Drive)."
        case .iCloudNotSignedIn:
            "You're not signed in to iCloud, or iCloud Drive is turned off for TXAWPAY in Settings."
        case .noFolderSelected:
            "No backup folder has been chosen yet."
        case .folderAccessLost:
            "TXAWPAY lost access to the backup folder (it may have been moved or deleted). Please choose it again."
        case .permissionDenied(let detail):
            "TXAWPAY doesn't have permission to write to the backup folder. \(detail)"
        }
    }
}

enum BackupDestinationResolver {
    static let iCloudContainerID = "iCloud.com.txawpay.app"

    /// Must be called off the main thread: `url(forUbiquityContainerIdentifier:)` can block.
    static func resolve(kind: BackupDestinationKind, bookmark: Data?) throws -> ResolvedBackupRoot {
        let fm = FileManager.default
        switch kind {
        case .onDevice:
            let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            return ResolvedBackupRoot(kind: .onDevice, rootURL: docs.appendingPathComponent("TXAWPAY", isDirectory: true),
                                      scopedURL: nil, isUbiquitous: false)
        case .iCloudDrive:
            guard fm.ubiquityIdentityToken != nil else { throw BackupDestinationError.iCloudNotSignedIn }
            guard let container = fm.url(forUbiquityContainerIdentifier: iCloudContainerID) else {
                throw BackupDestinationError.iCloudUnavailable
            }
            // Only the "Documents" sub-folder of the container is shown in iCloud Drive.
            let root = container.appendingPathComponent("Documents", isDirectory: true)
                .appendingPathComponent("TXAWPAY", isDirectory: true)
            return ResolvedBackupRoot(kind: .iCloudDrive, rootURL: root, scopedURL: nil, isUbiquitous: true)
        case .folder:
            guard let bookmark else { throw BackupDestinationError.noFolderSelected }
            var stale = false
            guard let url = try? URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else {
                throw BackupDestinationError.folderAccessLost
            }
            if stale, url.startAccessingSecurityScopedResource() {
                // Refresh a stale bookmark while we still have access.
                if let fresh = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
                    UserDefaults.standard.set(fresh, forKey: AppSettings.Keys.backupFolderBookmark)
                }
                url.stopAccessingSecurityScopedResource()
            }
            // If the user picked a folder already named TXAWPAY, use it directly.
            let root = url.lastPathComponent == "TXAWPAY" ? url : url.appendingPathComponent("TXAWPAY", isDirectory: true)
            let ubiquitous = fm.isUbiquitousItem(at: url)
            return ResolvedBackupRoot(kind: .folder, rootURL: root, scopedURL: url, isUbiquitous: ubiquitous)
        }
    }
}
