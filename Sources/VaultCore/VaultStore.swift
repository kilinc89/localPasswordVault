import Foundation
import CryptoKit

/// On-disk envelope. Only the ciphertext holds user data; header is authenticated as AAD.
struct VaultFile: Codable {
    var format: String = "LocalVault"
    var version: Int = 1
    var kdf: String = "PBKDF2-HMAC-SHA256"
    var iterations: UInt32
    var salt: Data
    var ciphertext: Data

    var aad: Data { Data("\(format)|\(version)|\(kdf)|\(iterations)|\(salt.base64EncodedString())".utf8) }
}

/// An unlocked vault: holds the derived key in memory until `lock()`.
public final class UnlockedVault: @unchecked Sendable {
    fileprivate var key: SymmetricKey?
    fileprivate let salt: Data
    fileprivate let iterations: UInt32

    fileprivate init(key: SymmetricKey, salt: Data, iterations: UInt32) {
        self.key = key
        self.salt = salt
        self.iterations = iterations
    }

    public var isLocked: Bool { key == nil }
    public func lock() { key = nil }
}

public struct VaultStore: Sendable {
    public let fileURL: URL
    public let iterations: UInt32

    public static var defaultURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("LocalVault", isDirectory: true)
            .appendingPathComponent("vault.lvault")
    }

    public init(fileURL: URL = VaultStore.defaultURL, iterations: UInt32 = Crypto.defaultIterations) {
        self.fileURL = fileURL
        self.iterations = iterations
    }

    public var exists: Bool { FileManager.default.fileExists(atPath: fileURL.path) }

    public static let minimumPasswordLength = 8
    static let allowedIterations: ClosedRange<UInt32> = 1_000...5_000_000

    public func create(password: String) throws -> UnlockedVault {
        guard !exists else { throw VaultError.vaultExists }
        guard password.count >= Self.minimumPasswordLength else { throw VaultError.passwordTooShort }
        let salt = try Crypto.randomBytes(Crypto.saltLength)
        let key = try Crypto.deriveKey(password: password, salt: salt, iterations: iterations)
        let vault = UnlockedVault(key: key, salt: salt, iterations: iterations)
        try save(VaultPayload(), with: vault)
        return vault
    }

    public func unlock(password: String) throws -> (UnlockedVault, VaultPayload) {
        let file = try readFile()
        let key = try Crypto.deriveKey(password: password, salt: file.salt, iterations: file.iterations)
        let plain = try Crypto.open(file.ciphertext, key: key, aad: file.aad)
        guard let payload = try? Self.decoder.decode(VaultPayload.self, from: plain) else {
            throw VaultError.corruptFile
        }
        return (UnlockedVault(key: key, salt: file.salt, iterations: file.iterations), payload)
    }

    public func save(_ payload: VaultPayload, with vault: UnlockedVault) throws {
        guard let key = vault.key else { throw VaultError.wrongPassword }
        var file = VaultFile(iterations: vault.iterations, salt: vault.salt, ciphertext: Data())
        let plain = try Self.encoder.encode(payload)
        file.ciphertext = try Crypto.seal(plain, key: key, aad: file.aad)
        let data = try JSONEncoder().encode(file)
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        try data.write(to: fileURL, options: [.atomic])
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    /// Re-encrypts the vault under a new password with a fresh salt.
    public func changePassword(current: String, new: String) throws -> (UnlockedVault, VaultPayload) {
        guard new.count >= Self.minimumPasswordLength else { throw VaultError.passwordTooShort }
        let (_, payload) = try unlock(password: current)
        let salt = try Crypto.randomBytes(Crypto.saltLength)
        let key = try Crypto.deriveKey(password: new, salt: salt, iterations: iterations)
        let vault = UnlockedVault(key: key, salt: salt, iterations: iterations)
        try save(payload, with: vault)
        return (vault, payload)
    }

    /// Copies the (still encrypted) vault file to `destination`.
    public func exportBackup(to destination: URL) throws {
        guard exists else { throw VaultError.vaultMissing }
        let fm = FileManager.default
        // Copy next to the destination first so an existing backup is only replaced on success.
        let temp = destination.deletingLastPathComponent()
            .appendingPathComponent(".\(destination.lastPathComponent).\(UUID().uuidString).tmp")
        try fm.copyItem(at: fileURL, to: temp)
        do {
            if fm.fileExists(atPath: destination.path) {
                _ = try fm.replaceItemAt(destination, withItemAt: temp)
            } else {
                try fm.moveItem(at: temp, to: destination)
            }
        } catch {
            try? fm.removeItem(at: temp)
            throw error
        }
    }

    /// Decrypts a backup file with the password it was exported under. The backup is never modified.
    public func readBackup(at source: URL, password: String) throws -> VaultPayload {
        try VaultStore(fileURL: source, iterations: iterations).unlock(password: password).1
    }

    private func readFile() throws -> VaultFile {
        guard exists else { throw VaultError.vaultMissing }
        let data = try Data(contentsOf: fileURL)
        // The header is only authenticated after key derivation, so bound its parameters first:
        // an attacker-supplied iteration count must not be able to hang the app.
        guard let file = try? JSONDecoder().decode(VaultFile.self, from: data),
              file.format == "LocalVault", file.version == 1, file.kdf == "PBKDF2-HMAC-SHA256",
              file.salt.count == Crypto.saltLength,
              Self.allowedIterations.contains(file.iterations) else { throw VaultError.corruptFile }
        return file
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
    }()
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }()
}
