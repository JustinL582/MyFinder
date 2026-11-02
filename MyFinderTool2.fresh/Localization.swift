import Foundation

/// Localised string lookup for text that SwiftUI doesn't localise by itself
/// (plain `String` values such as menu labels held in enums, error messages,
/// default file names). The Chinese source text is the key; `en.lproj`
/// provides the English translation. When no translation is bundled (e.g.
/// `swift run`) the key itself is shown, i.e. Chinese.
func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

/// Localised `String(format:)` for strings that carry placeholders.
func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), arguments: args)
}
