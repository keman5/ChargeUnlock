import Foundation

@main
enum AppInformationTests {
    static func main() {
        assert(AppInformation.version(in: ["CFBundleShortVersionString": "1.2", "CFBundleVersion": "7"]) == "1.2（7）")
        assert(AppInformation.version(in: [:]) == "未知（未知）")
        assert(AppInformation.updateURL(in: [:]).absoluteString == "https://auv.macseek.cc/updates/")
        assert(AppInformation.updateURL(in: ["PlugLitAppStoreID": "123456"]).absoluteString == "https://apps.apple.com/app/id123456")
        assert(AppInformation.updateURL(in: ["PlugLitAppStoreID": "123/evil"]).host == "auv.macseek.cc")
        let key = "PlugLitWebsiteURL"
        assert(AppInformation.url(for: key, in: [:]) == nil)
        for invalid in ["", "https://", "http://example.com", "javascript:alert(1)", "file:///tmp/test", "https://user:password@example.com"] {
            assert(AppInformation.url(for: key, in: [key: invalid]) == nil)
        }
        assert(AppInformation.url(for: key, in: [key: "https://example.com/apps"])?.host == "example.com")
        print("App information checks passed")
    }
}
