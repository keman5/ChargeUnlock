import Foundation

enum AppInformation {
    static let website = URL(string: "https://auv.macseek.cc")!

    static func updateURL(in info: [String: Any]) -> URL {
        if let id = info["PlugLitAppStoreID"] as? String,
           !id.isEmpty, id.allSatisfy({ $0.isASCII && $0.isNumber }) {
            return URL(string: "https://apps.apple.com/app/id\(id)")!
        }
        return website.appendingPathComponent("updates/")
    }
    static func version(in info: [String: Any]) -> String {
        let version = info["CFBundleShortVersionString"] as? String ?? L("Unknown")
        let build = info["CFBundleVersion"] as? String ?? L("Unknown")
        return "\(version) (\(build))"
    }

    static func url(for key: String, in info: [String: Any]) -> URL? {
        guard let text = info[key] as? String,
              let url = URL(string: text), url.scheme == "https",
              let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil else { return nil }
        return url
    }

    static var privacy: String { L("privacy.document") }

    static var terms: String { L("terms.document") }
}
