import Foundation
import CryptoKit
import CommonCrypto

public enum VaultError: Error, Equatable, LocalizedError {
    case wrongPassword
    case corruptFile
    case keyDerivationFailed
    case randomFailed
    case passwordTooShort
    case vaultExists
    case vaultMissing

    public var errorDescription: String? {
        switch self {
        case .wrongPassword: return L("Ana parola yanlış.", "Incorrect master password.")
        case .corruptFile: return L("Kasa dosyası okunamadı veya bozuk.", "The vault file could not be read or is corrupt.")
        case .keyDerivationFailed: return L("Anahtar türetilemedi.", "Key derivation failed.")
        case .randomFailed: return L("Güvenli rastgele sayı üretilemedi.", "Could not generate secure random bytes.")
        case .passwordTooShort: return L("Ana parola en az 8 karakter olmalı.", "The master password must be at least 8 characters.")
        case .vaultExists: return L("Kasa zaten mevcut.", "A vault already exists.")
        case .vaultMissing: return L("Kasa bulunamadı.", "Vault not found.")
        }
    }
}

public enum Crypto {
    public static let defaultIterations: UInt32 = 600_000
    public static let saltLength = 16

    public static func randomBytes(_ count: Int) throws -> Data {
        var data = Data(count: count)
        let status = data.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!)
        }
        guard status == errSecSuccess else { throw VaultError.randomFailed }
        return data
    }

    /// PBKDF2-HMAC-SHA256 → 256-bit symmetric key.
    public static func deriveKey(password: String, salt: Data, iterations: UInt32) throws -> SymmetricKey {
        let pwd = Array(password.utf8)
        var out = [UInt8](repeating: 0, count: 32)
        let status = salt.withUnsafeBytes { saltPtr in
            pwd.withUnsafeBufferPointer { pwdPtr in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    pwdPtr.baseAddress.map { UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self) },
                    pwd.count,
                    saltPtr.bindMemory(to: UInt8.self).baseAddress,
                    salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    iterations,
                    &out,
                    out.count
                )
            }
        }
        guard status == kCCSuccess else { throw VaultError.keyDerivationFailed }
        defer { out.withUnsafeMutableBufferPointer { _ = memset_s($0.baseAddress, 32, 0, 32) } }
        return SymmetricKey(data: out)
    }

    public static func seal(_ plaintext: Data, key: SymmetricKey, aad: Data) throws -> Data {
        let box = try AES.GCM.seal(plaintext, using: key, authenticating: aad)
        guard let combined = box.combined else { throw VaultError.corruptFile }
        return combined
    }

    public static func open(_ combined: Data, key: SymmetricKey, aad: Data) throws -> Data {
        do {
            let box = try AES.GCM.SealedBox(combined: combined)
            return try AES.GCM.open(box, using: key, authenticating: aad)
        } catch {
            throw VaultError.wrongPassword
        }
    }
}
