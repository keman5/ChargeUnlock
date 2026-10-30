import Foundation

@main
enum DiagnosticTests {
    @MainActor static func main() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("events.json")
        let store = DiagnosticStore(file: file)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let state = DiagnosticState(batteryPercent: nil, power: "0", requested: false, stopping: false, pipActive: false)
        let empty = try store.events(now: now)
        assert(empty.isEmpty)
        for i in 0..<205 { try store.append(DiagnosticEvent(time: now.addingTimeInterval(Double(i)), event: "state", state: state)) }
        let entries = try store.events(now: now.addingTimeInterval(205))
        assert(entries.count == 200 && entries.first?.time == now.addingTimeInterval(5))
        let expired = try store.events(now: now.addingTimeInterval(DiagnosticStore.retention + 206))
        assert(expired.isEmpty)
        let report = DiagnosticReport(generatedAt: now, appVersion: "1.0", build: "6", hardware: "iPhone18,3", osVersion: "27.0", lowPowerMode: false, thermalState: 0, state: state, events: entries)
        let json = try JSONSerialization.jsonObject(with: report.data()) as! [String: Any]
        assert(json["hardware"] as? String == "iPhone18,3")
        assert(json["deviceName"] == nil && json["identifierForVendor"] == nil && json["UDID"] == nil)
        try Data("broken".utf8).write(to: file)
        do { _ = try store.events(now: now); assertionFailure("Corruption must not appear as an empty successful export") } catch {}
        try store.clear()
        let cleared = try store.events(now: now)
        assert(cleared.isEmpty)
        print("Diagnostics: bounded retention, report fields, corruption and deletion passed")
    }
}
