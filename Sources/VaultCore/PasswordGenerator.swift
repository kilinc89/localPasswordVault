import Foundation
import Security

public struct GeneratorOptions: Equatable, Sendable {
    public var length: Int
    public var uppercase: Bool
    public var lowercase: Bool
    public var digits: Bool
    public var symbols: Bool
    public var excludeAmbiguous: Bool

    public static let lengthRange = 8...64

    public init(length: Int = 20, uppercase: Bool = true, lowercase: Bool = true,
                digits: Bool = true, symbols: Bool = true, excludeAmbiguous: Bool = false) {
        self.length = length
        self.uppercase = uppercase
        self.lowercase = lowercase
        self.digits = digits
        self.symbols = symbols
        self.excludeAmbiguous = excludeAmbiguous
    }
}

public enum PasswordGenerator {
    static let upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    static let lower = "abcdefghijklmnopqrstuvwxyz"
    static let digitChars = "0123456789"
    static let symbolChars = "!@#$%^&*()-_=+[]{};:,.<>?/~"
    static let ambiguous: Set<Character> = ["0", "O", "o", "1", "l", "I", "|"]

    public static func classes(for o: GeneratorOptions) -> [[Character]] {
        var sets: [String] = []
        if o.uppercase { sets.append(upper) }
        if o.lowercase { sets.append(lower) }
        if o.digits { sets.append(digitChars) }
        if o.symbols { sets.append(symbolChars) }
        if sets.isEmpty { sets.append(lower) }
        return sets.map { s in Array(s).filter { !o.excludeAmbiguous || !ambiguous.contains($0) } }
    }

    /// Generates a password containing at least one character from every selected class.
    public static func generate(_ options: GeneratorOptions) -> String {
        let length = min(max(options.length, GeneratorOptions.lengthRange.lowerBound),
                         GeneratorOptions.lengthRange.upperBound)
        let sets = classes(for: options)
        let all = sets.flatMap { $0 }
        var chars = sets.map { $0[secureIndex($0.count)] }
        while chars.count < length { chars.append(all[secureIndex(all.count)]) }
        // Fisher–Yates shuffle with secure randomness.
        for i in stride(from: chars.count - 1, to: 0, by: -1) {
            chars.swapAt(i, secureIndex(i + 1))
        }
        return String(chars)
    }

    /// Uniform index in 0..<upperBound using SecRandomCopyBytes with rejection sampling.
    static func secureIndex(_ upperBound: Int) -> Int {
        precondition(upperBound > 0)
        let bound = UInt32(upperBound)
        let limit = UInt32.max - (UInt32.max % bound)
        while true {
            var r: UInt32 = 0
            let status = withUnsafeMutableBytes(of: &r) {
                SecRandomCopyBytes(kSecRandomDefault, 4, $0.baseAddress!)
            }
            precondition(status == errSecSuccess, "SecRandomCopyBytes failed")
            if r < limit { return Int(r % bound) }
        }
    }
}

public enum Strength: Int, Comparable, Sendable {
    case weak, fair, strong, veryStrong

    public static func < (a: Strength, b: Strength) -> Bool { a.rawValue < b.rawValue }

    public var label: String {
        switch self {
        case .weak: return L("Zayıf", "Weak")
        case .fair: return L("Orta", "Fair")
        case .strong: return L("Güçlü", "Strong")
        case .veryStrong: return L("Çok güçlü", "Very strong")
        }
    }
}

public enum PasswordStrength {
    /// Estimated entropy in bits based on character pool size × length.
    public static func entropy(_ password: String) -> Double {
        guard !password.isEmpty else { return 0 }
        var pool = 0
        if password.contains(where: { $0.isLowercase }) { pool += 26 }
        if password.contains(where: { $0.isUppercase }) { pool += 26 }
        if password.contains(where: { $0.isNumber }) { pool += 10 }
        if password.contains(where: { !$0.isLetter && !$0.isNumber }) { pool += 33 }
        let unique = Set(password).count
        // Penalize heavy repetition: use the smaller of length and 2×unique characters.
        let effectiveLength = min(password.count, unique * 2)
        return Double(effectiveLength) * log2(Double(max(pool, 1)))
    }

    public static func evaluate(_ password: String) -> Strength {
        switch entropy(password) {
        case ..<40: return .weak
        case ..<60: return .fair
        case ..<90: return .strong
        default: return .veryStrong
        }
    }
}
