import Foundation

/// UI language. Strings live in code as Turkish/English pairs (see `L`), so the
/// app needs no resource bundle and can switch language at runtime.
public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case turkish = "tr"
    case english = "en"

    public var id: String { rawValue }

    /// Shown in the language picker in its own language.
    public var displayName: String {
        switch self {
        case .turkish: return "Türkçe"
        case .english: return "English"
        }
    }

    public var locale: Locale { Locale(identifier: rawValue) }

    static let defaultsKey = "LocalVault.language"

    /// The saved choice, or the system language on first launch (English unless the system is Turkish).
    public static var current: AppLanguage {
        get {
            if let raw = UserDefaults.standard.string(forKey: defaultsKey), let lang = AppLanguage(rawValue: raw) {
                return lang
            }
            return Locale.preferredLanguages.first?.hasPrefix("tr") == true ? .turkish : .english
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey) }
    }
}

/// Returns the string for the current UI language.
public func L(_ turkish: String, _ english: String) -> String {
    AppLanguage.current == .turkish ? turkish : english
}
