import Foundation

/// German when macOS's first language is German, English otherwise (also for languages the app has no
/// translation for, where macOS would fall back to the next language in the list, maybe German).
/// English is the app's own language; German comes from Resources/de.lproj/Localizable.strings.
/// The English text is its own key, so a missing translation still shows English.
func L(_ english: String) -> String { NSLocalizedString(english, bundle: Texts.bundle, comment: "") }

enum Texts {
    static let bundle: Bundle = {
        let german = Locale.preferredLanguages.first?.hasPrefix("de") == true
        return Bundle.main.path(forResource: german ? "de" : "en", ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
    }()
}
