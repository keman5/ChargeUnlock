import Foundation

struct DiagnosticState: Codable, Equatable {
    var batteryPercent: Int?
    var power: String
    var requested: Bool
    var stopping: Bool
    var pipActive: Bool
}

struct DiagnosticEvent: Codable, Equatable {
    var time: Date
    var event: String
    var state: DiagnosticState
}

struct DiagnosticReport: Codable {
    var schemaVersion = 1
    var generatedAt: Date
    var appVersion: String
    var build: String
    var hardware: String
    var osVersion: String
    var lowPowerMode: Bool
    var thermalState: Int
    var state: DiagnosticState
    var events: [DiagnosticEvent]

    func data() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}

@MainActor
final class DiagnosticStore {
    static let maximumEvents = 200
    static let retention: TimeInterval = 7 * 24 * 60 * 60
    private let file: URL

    init(file: URL) { self.file = file }

    func events(now: Date = Date()) throws -> [DiagnosticEvent] {
        guard FileManager.default.fileExists(atPath: file.path) else { return [] }
        let data = try Data(contentsOf: file)
        guard data.count <= 256_000 else { throw CocoaError(.fileReadTooLarge) }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([DiagnosticEvent].self, from: data)
            .filter { $0.time <= now && now.timeIntervalSince($0.time) <= Self.retention }
            .suffix(Self.maximumEvents).map { $0 }
    }

    func append(_ event: DiagnosticEvent) throws {
        var entries = try events(now: event.time)
        entries.append(event)
        try save(Array(entries.suffix(Self.maximumEvents)))
    }

    func clear() throws {
        if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
    }

    private func save(_ events: [DiagnosticEvent]) throws {
        var directory = file.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(events).write(to: file, options: .atomic)
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: file.path)
        #endif
    }
}
