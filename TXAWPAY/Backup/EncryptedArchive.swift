import Foundation
import CryptoKit
import CommonCrypto
import UniformTypeIdentifiers

/// Password-protected container for exports (`.txawpaybackup`).
///
/// Layout: "TXWPENC1" (8 bytes) | PBKDF2 iterations (UInt32 LE) | salt (16 bytes) |
/// AES-256-GCM sealed box (nonce ‖ ciphertext ‖ tag).
/// The key is derived from the password with PBKDF2-HMAC-SHA256. Without the
/// password the contents cannot be recovered — not even by TXAWPAY.
enum EncryptedArchive {
    static let magic = Data("TXWPENC1".utf8)
    static let iterations: UInt32 = 310_000
    static let fileExtension = "txawpaybackup"

    enum CryptoError: LocalizedError {
        case notEncryptedArchive
        case wrongPassword
        case keyDerivationFailed

        var errorDescription: String? {
            switch self {
            case .notEncryptedArchive: "This isn't a TXAWPAY encrypted backup."
            case .wrongPassword: "The password is incorrect, or the file is damaged."
            case .keyDerivationFailed: "The encryption key couldn't be created."
            }
        }
    }

    static func encrypt(_ plaintext: Data, password: String) throws -> Data {
        var salt = Data(count: 16)
        let status = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        guard status == errSecSuccess else { throw CryptoError.keyDerivationFailed }
        let key = try deriveKey(password: password, salt: salt, iterations: iterations)
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else { throw CryptoError.keyDerivationFailed }
        var out = magic
        out.append(le32: iterations)
        out.append(salt)
        out.append(combined)
        return out
    }

    static func decrypt(_ data: Data, password: String) throws -> Data {
        guard data.count > magic.count + 4 + 16 + 28, data.prefix(magic.count) == magic else {
            throw CryptoError.notEncryptedArchive
        }
        let iter = data.le32(at: magic.count)
        let saltStart = data.startIndex + magic.count + 4
        let salt = data.subdata(in: saltStart..<(saltStart + 16))
        let box = data.subdata(in: (saltStart + 16)..<data.endIndex)
        let key = try deriveKey(password: password, salt: salt, iterations: iter)
        do {
            return try AES.GCM.open(try AES.GCM.SealedBox(combined: box), using: key)
        } catch {
            throw CryptoError.wrongPassword
        }
    }

    static func isEncrypted(_ url: URL) -> Bool {
        guard let h = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? h.close() }
        return (try? h.read(upToCount: 8)) == magic
    }

    private static func deriveKey(password: String, salt: Data, iterations: UInt32) throws -> SymmetricKey {
        let pw = Array(password.utf8)
        var derived = [UInt8](repeating: 0, count: 32)
        let result = salt.withUnsafeBytes { saltBuf in
            CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2),
                                 pw.map { Int8(bitPattern: $0) }, pw.count,
                                 saltBuf.bindMemory(to: UInt8.self).baseAddress, salt.count,
                                 CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), iterations,
                                 &derived, 32)
        }
        guard result == Int32(kCCSuccess) else { throw CryptoError.keyDerivationFailed }
        return SymmetricKey(data: derived)
    }
}

extension UTType {
    /// Exported type declared in Info.plist for encrypted TXAWPAY backups.
    static let txawpayEncryptedBackup = UTType(exportedAs: "com.txawpay.app.encrypted-backup", conformingTo: .data)
    static let markdownText = UTType(filenameExtension: "md", conformingTo: .plainText) ?? .plainText
}
