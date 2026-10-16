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
        case .wrongPassword: return "Ana parola yanlış."
        case .corruptFile: return "Kasa dosyası okunamadı veya bozuk."
        case .keyDerivationFailed: return "Anahtar türetilemedi."
        case .randomFailed: return "Güvenli rastgele sayı üretilemedi."
        case .passwordTooShort: return "Ana parola en az 8 karakter olmalı."
        case .vaultExists: return "Kasa zaten mevcut."
        case .vaultMissing: return "Kasa bulunamadı."
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
