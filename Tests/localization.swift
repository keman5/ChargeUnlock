import Foundation

@main
struct LocalizationTests {
    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let locales = ["en", "zh-Hans", "es", "fr", "de", "ja", "ko"]
        for table in ["Localizable", "AppShortcuts", "InfoPlist"] {
            func strings(_ locale: String) throws -> [String: String] {
                let data = try Data(contentsOf: root.appendingPathComponent("\(locale).lproj/\(table).strings"))
                return try PropertyListSerialization.propertyList(from: data, format: nil) as! [String: String]
            }
            let english = try strings("en")
            let format = try NSRegularExpression(pattern: "%([0-9]+\\$)?(?:lld|@)")
            func placeholders(_ text: String) -> [String] {
                format.matches(in: text, range: NSRange(text.startIndex..., in: text)).map {
                    String(text[Range($0.range, in: text)!])
                }.sorted()
            }
            for locale in locales {
                let translated = try strings(locale)
                assert(Set(translated.keys) == Set(english.keys), "Missing keys: \(locale)/\(table)")
                for (key, value) in translated {
                    assert(!value.isEmpty)
                    assert(placeholders(key) == placeholders(value), "Format mismatch: \(locale): \(key)")
                    if table == "AppShortcuts" { assert(value.contains("${applicationName}")) }
                }
                if table == "Localizable" {
                    let bundle = Bundle(path: root.appendingPathComponent("\(locale).lproj").path)!
                    assert(bundle.localizedString(forKey: "Start Keep Awake", value: nil, table: nil) == translated["Start Keep Awake"])
                    assert(translated["privacy.document"]!.contains("feedback.pluglit@macseek.cc"))
                }
            }
        }
        for (requested, expected) in [("fr-CA", "fr"), ("ja-JP", "ja"), ("es-MX", "es"), ("ru", "en"), ("ar", "en")] {
            assert(Bundle.preferredLocalizations(from: locales, forPreferences: [requested]).first == expected)
        }
        print("Localization: seven complete catalogs, formats, legal contact, shortcut phrases and language fallback passed")
    }
}
