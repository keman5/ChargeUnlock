import AppIntents

struct StartChargingIntent: AppIntent {
    static let title: LocalizedStringResource = "开启充电亮屏"
    static let description = IntentDescription("连接电源后打开 电亮 PlugLit 并尝试启动画中画。")
    static let openAppWhenRun: Bool = true
    @MainActor func perform() async throws -> some IntentResult {
        try await PlaybackController.shared.start()
        return .result()
    }
}

struct StopChargingIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "停止充电亮屏"
    static let description = IntentDescription("停止视频并关闭画中画，恢复原有自动锁屏行为。")
    static let openAppWhenRun: Bool = false
    @MainActor func perform() async throws -> some IntentResult {
        PlaybackController.shared.stop()
        return .result()
    }
}

struct ChargingShortcuts: AppShortcutsProvider {
    static let shortcutTileColor: ShortcutTileColor = .orange
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartChargingIntent(), phrases: ["用\(.applicationName)开启充电亮屏"], shortTitle: "开启充电亮屏", systemImageName: "bolt.fill")
        AppShortcut(intent: StopChargingIntent(), phrases: ["用\(.applicationName)停止充电亮屏"], shortTitle: "停止充电亮屏", systemImageName: "stop.circle")
    }
}
