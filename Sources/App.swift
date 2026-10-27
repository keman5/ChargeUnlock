import AppKit
import Foundation
import os

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let defaults = UserDefaults.standard
    private let log = Logger(subsystem: "local.chargeunlock.mac", category: "lifecycle")
    private var item: NSStatusItem!
    private var timer: Timer?
    private var phones: [Phone] = []
    private var runner: Process?
    private var stopping = false
    private var heartbeat: Process?
    private var session = ""
    private var ready = false
    private var attempted = false
    private var wasConnected = false
    private var lastBeat: TimeInterval = 0
    private var lastPulse: TimeInterval = 0
    private var output = RunnerOutput()
    private var recentLog = ""
    private var status = "正在检查 USB 设备"
    private var enabled: Bool { defaults.object(forKey: "enabled") as? Bool ?? true }
    private var target: String { defaults.string(forKey: "device") ?? "" }
    private var team: String { defaults.string(forKey: "team") ?? "" }
    private var support: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/ChargeUnlock")
    }
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        if NSRunningApplication.runningApplications(withBundleIdentifier: "local.chargeunlock.mac").count > 1 {
            NSApp.terminate(nil)
            return
        }
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "iphone", accessibilityDescription: "ChargeUnlock")
        item.button?.toolTip = "ChargeUnlock · USB 连接时保持 iPhone 亮屏"
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        tick()
        timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
    func menuWillOpen(_ menu: NSMenu) { rebuildMenu(menu) }
    private func rebuildMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        func add(_ title: String, _ action: Selector? = nil) -> NSMenuItem {
            let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
            entry.target = self
            menu.addItem(entry)
            return entry
        }
        _ = add("ChargeUnlock")
        _ = add(status)
        menu.addItem(.separator())
        _ = add(enabled ? "暂停保活" : "启用 USB 保活", #selector(toggle))
        _ = add("重新连接助手", #selector(retry))
        menu.addItem(.separator())
        _ = add("设备（仅识别 USB 连接）")
        if phones.isEmpty { _ = add("请用数据线连接 iPhone") }
        for phone in phones {
            let entry = add(phone.label, #selector(selectPhone(_:)))
            entry.representedObject = phone.id
            entry.state = phone.id == target ? .on : .off
        }
        if !target.isEmpty && !phones.contains(where: { $0.id == target }) {
            _ = add("已绑定 · \(target.suffix(6))（未连接）")
        }
        menu.addItem(.separator())
        _ = add("签名团队…", #selector(editTeam))
        _ = add("查看运行日志", #selector(openLog))
        _ = add("使用说明", #selector(openHelp))
        menu.addItem(.separator())
        _ = add("拔线后停止保活，按原设置自动锁屏")
        _ = add("退出 ChargeUnlock", #selector(quit))
    }
    private func setStatus(_ value: String) {
        guard status != value else { return }
        status = value
        log.notice("\(value, privacy: .public)")
        item?.button?.image = NSImage(systemSymbolName: value == "正在保持 iPhone 亮屏" ? "bolt.fill" : "iphone", accessibilityDescription: value)
        item?.button?.toolTip = "ChargeUnlock · " + value
        let record: [String: Any] = ["status": value, "enabled": enabled, "usbConnected": phones.contains { $0.id == target }, "runnerReady": ready, "updatedAt": Date().timeIntervalSince1970]
        if let data = try? JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: support.appendingPathComponent("status.json"), options: .atomic)
        }
    }
    private func tick() {
        phones = usbPhones()
        if target.isEmpty && phones.count == 1 { defaults.set(phones[0].id, forKey: "device") }
        let connected = phones.contains { $0.id == target }
        if !connected || !enabled {
            if wasConnected && !connected { attempted = false }
            wasConnected = connected
            stop()
            setStatus(!enabled ? "已暂停 · 保活许可将在 8 秒内失效" : "等待指定 iPhone 通过 USB 连接")
            return
        }
        wasConnected = true
        if runner == nil && !attempted { start() }
        guard mayHeartbeat(enabled: enabled, target: target, connected: phones, ready: ready) else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if lastPulse > 0 && now - lastPulse > 15 && status == "正在保持 iPhone 亮屏" {
            setStatus("未收到保活回执 · 请检查手机")
        }
        guard heartbeat == nil, now - lastBeat >= 3 else { return }
        lastBeat = now
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["devicectl", "device", "notification", "post", "--device", target, "--name", "local.chargeunlock.heartbeat." + session, "--timeout", "5", "--quiet"]
        process.standardOutput = FileHandle.nullDevice
        let errors = Pipe()
        process.standardError = errors
        let current = session
        process.terminationHandler = { [weak self] task in
            let errorText = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            Task { @MainActor in
                guard let self, self.session == current else { return }
                self.heartbeat = nil
                if task.terminationStatus != 0 && self.ready {
                    self.receive("Heartbeat error: " + errorText + "\n")
                    self.setStatus("连接中断 · 未续期保活许可")
                }
            }
        }
        heartbeat = process
        do { try process.run() } catch {
            heartbeat = nil
            setStatus("无法发送保活许可 · 请检查 Xcode")
        }
    }
    private func start() {
        attempted = true
        stopping = false
        guard team.range(of: "^[A-Z0-9]{10}$", options: .regularExpression) != nil else {
            setStatus("请先在菜单中设置 Apple 签名团队")
            return
        }
        guard let resources = Bundle.main.resourceURL else { return }
        session = UUID().uuidString
        ready = false
        lastPulse = 0
        output = RunnerOutput()
        recentLog = ""
        let process = Process()
        let pipe = Pipe()
        process.executableURL = resources.appendingPathComponent("build.sh")
        process.arguments = ["run", target, team, session]
        process.standardOutput = pipe
        process.standardError = pipe
        let current = session
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty { handle.readabilityHandler = nil; return }
            Task { @MainActor in
                guard let self, self.session == current else { return }
                self.receive(String(decoding: data, as: UTF8.self))
            }
        }
        process.terminationHandler = { [weak self] task in
            Task { @MainActor in
                guard let self, self.runner === task else { return }
                self.runner = nil
                self.ready = false
                if self.session == current && self.enabled && self.phones.contains(where: { $0.id == self.target }) {
                    self.setStatus("助手已停止 · 解锁手机后点“重新连接助手”")
                }
            }
        }
        runner = process
        setStatus("正在准备助手 · 请保持手机解锁")
        do { try process.run() } catch {
            runner = nil
            setStatus("无法启动构建脚本 · 请查看日志")
            receive(error.localizedDescription)
        }
    }
    private func receive(_ text: String) {
        recentLog = String((recentLog + text).suffix(200_000))
        try? recentLog.write(to: support.appendingPathComponent("runner.log"), atomically: true, encoding: .utf8)
        for state in output.states(in: text) {
            switch state {
            case "ready": ready = true; setStatus("助手已连接 · 等待保活回执")
            case "awake":
                guard enabled, ready, usbPhones().contains(where: { $0.id == target }) else { continue }
                lastPulse = ProcessInfo.processInfo.systemUptime
                setStatus("正在保持 iPhone 亮屏")
            case "locked": setStatus("手机已锁屏 · 请手动解锁")
            case "unplugged": setStatus("手机未充电 · 已停止保活")
            case "waiting": setStatus("等待 Mac 保活许可")
            case "unsupported", "event-failed": ready = false; setStatus("当前系统的自动化接口不可用 · 查看日志")
            case "stopped": ready = false
            default: break
            }
        }
    }
    private func stop() {
        ready = false
        lastPulse = 0
        session = ""
        if let heartbeat, heartbeat.isRunning { heartbeat.terminate() }
        heartbeat = nil
        if let runner, runner.isRunning, !stopping {
            stopping = true
            runner.terminate()
        }
    }
    @objc private func toggle() {
        defaults.set(!enabled, forKey: "enabled")
        if enabled { attempted = false }
        tick()
    }
    @objc private func retry() { stop(); attempted = false; tick() }
    @objc private func selectPhone(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String, id != target else { return }
        stop()
        defaults.set(id, forKey: "device")
        attempted = false
        tick()
    }
    @objc private func editTeam() {
        let alert = NSAlert()
        alert.messageText = "Apple 开发签名团队"
        alert.informativeText = "输入 Xcode 账户的 10 位 Team ID。首次连接需在手机上确认信任、开发者模式和 UI 自动化。"
        let field = NSTextField(string: team)
        field.frame = NSRect(x: 0, y: 0, width: 300, height: 24)
        alert.accessoryView = field
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")
        alert.window.initialFirstResponder = nil
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard value.range(of: "^[A-Z0-9]{10}$", options: .regularExpression) != nil else {
            setStatus("签名团队必须是 10 位大写字母或数字")
            return
        }
        defaults.set(value, forKey: "team")
        retry()
    }
    @objc private func openLog() { NSWorkspace.shared.open(support.appendingPathComponent("runner.log")) }
    @objc private func openHelp() {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("README.md") { NSWorkspace.shared.open(url) }
    }
    @objc private func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        stop()
        setStatus("已退出 · 保活许可将在 8 秒内失效")
    }
}
