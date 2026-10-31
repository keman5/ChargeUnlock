import Foundation

func L(_ key: String, _ arguments: CVarArg...) -> String {
    let text = NSLocalizedString(key, comment: "")
    return arguments.isEmpty ? text : String(format: text, locale: Locale.current, arguments: arguments)
}
