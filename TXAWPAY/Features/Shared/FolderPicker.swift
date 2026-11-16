import UIKit
import UniformTypeIdentifiers

/// Presents the system folder picker directly with UIKit.
///
/// SwiftUI's `.fileImporter` silently fails to appear when the same screen (or
/// a full-screen cover above it) also uses `.sheet`, which is the case on the
/// backup and onboarding screens. Presenting `UIDocumentPickerViewController`
/// from the top-most view controller avoids that conflict.
@MainActor
enum FolderPicker {
    enum PickError: LocalizedError {
        case noWindow
        var errorDescription: String? { "The folder picker couldn't be opened. Please try again." }
    }

    private static var activeDelegate: Delegate?

    /// Returns the chosen folder, or `nil` if the person cancelled.
    static func pickFolder() async throws -> URL? {
        guard let presenter = topViewController() else { throw PickError.noWindow }
        return await withCheckedContinuation { continuation in
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
            picker.allowsMultipleSelection = false
            picker.shouldShowFileExtensions = true
            let delegate = Delegate { url in
                activeDelegate = nil
                continuation.resume(returning: url)
            }
            activeDelegate = delegate
            picker.delegate = delegate
            presenter.present(picker, animated: true)
        }
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? scenes.first?.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }

    private final class Delegate: NSObject, UIDocumentPickerDelegate {
        private var finish: ((URL?) -> Void)?
        init(finish: @escaping (URL?) -> Void) { self.finish = finish }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            finish?(urls.first)
            finish = nil
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            finish?(nil)
            finish = nil
        }
    }
}
