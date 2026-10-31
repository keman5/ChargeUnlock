import AppIntents

@available(iOS 17.0, *)
struct StartChargingIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Keep Awake"
    static let description = IntentDescription("Open PlugLit while plugged in and try starting Picture in Picture.")
    static let openAppWhenRun: Bool = true
    @MainActor func perform() async throws -> some IntentResult {
        try await PlaybackController.shared.start()
        return .result()
    }
}

@available(iOS 17.0, *)
struct StopChargingIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Stop Keep Awake"
    static let description = IntentDescription("Stop video and PiP so your usual Auto-Lock settings apply.")
    static let openAppWhenRun: Bool = false
    @MainActor func perform() async throws -> some IntentResult {
        PlaybackController.shared.stop()
        return .result()
    }
}

@available(iOS 17.0, *)
struct ChargingShortcuts: AppShortcutsProvider {
    static let shortcutTileColor: ShortcutTileColor = .orange
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartChargingIntent(), phrases: ["Start Keep Awake with \(.applicationName)"], shortTitle: "Start Keep Awake", systemImageName: "bolt.fill")
        AppShortcut(intent: StopChargingIntent(), phrases: ["Stop Keep Awake with \(.applicationName)"], shortTitle: "Stop Keep Awake", systemImageName: "stop.circle")
    }
}
