import UIKit
import os

@MainActor
enum Diagnostics {
    private static let logger = Logger(subsystem: "local.chargeunlock.ios", category: "diagnostics")
    private static let store = DiagnosticStore(file: URL.applicationSupportDirectory.appendingPathComponent("Diagnostics/events.json"))
    private static var lastState: DiagnosticState?

    static func state() -> DiagnosticState {
        let device = UIDevice.current
        let playback = PlaybackController.shared
        let level = device.batteryLevel
        return DiagnosticState(batteryPercent: level.isFinite && level >= 0 && level <= 1 ? Int((level * 100).rounded()) : nil,
                               power: String(device.batteryState.rawValue), requested: playback.policy.requested,
                               stopping: playback.policy.stopping, pipActive: playback.active)
    }

    static func record(_ event: String, onlyIfChanged: Bool = false) {
        let snapshot = state()
        guard !onlyIfChanged || snapshot != lastState else { return }
        lastState = snapshot
        do { try store.append(DiagnosticEvent(time: Date(), event: event, state: snapshot)) }
        catch { logger.error("Unable to save local diagnostics") }
    }

    static func report() throws -> DiagnosticReport {
        var machine = utsname()
        uname(&machine)
        let hardware = withUnsafeBytes(of: &machine.machine) { bytes in
            String(decoding: bytes.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
        let info = Bundle.main.infoDictionary ?? [:]
        return DiagnosticReport(generatedAt: Date(), appVersion: info["CFBundleShortVersionString"] as? String ?? "unknown",
                                build: info["CFBundleVersion"] as? String ?? "unknown", hardware: hardware,
                                osVersion: UIDevice.current.systemVersion, lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
                                thermalState: ProcessInfo.processInfo.thermalState.rawValue, state: state(), events: try store.events())
    }

    static func clear() throws {
        try store.clear()
        let legacy = URL.documentsDirectory.appendingPathComponent("status.json")
        if FileManager.default.fileExists(atPath: legacy.path) { try FileManager.default.removeItem(at: legacy) }
        let exports = URL.temporaryDirectory.appendingPathComponent("PlugLitDiagnostics")
        if FileManager.default.fileExists(atPath: exports.path) { try FileManager.default.removeItem(at: exports) }
        lastState = nil
    }

    static func export(_ data: Data) throws -> URL {
        let directory = URL.temporaryDirectory.appendingPathComponent("PlugLitDiagnostics")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("PlugLit-diagnostics.json")
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }
}
