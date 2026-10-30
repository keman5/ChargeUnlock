import UIKit
import AVKit
import os
import CoreImage

@MainActor
final class PlaybackController: NSObject, @preconcurrency AVPictureInPictureControllerDelegate {
    static let shared = PlaybackController()
    let player = AVQueuePlayer()
    let layer = AVPlayerLayer()
    private(set) var message = "连接电源后，开启充电亮屏。"
    private(set) var policy = ChargingPolicy()
    var onChange: (() -> Void)?
    private let batteryOverlay = BatteryOverlay()
    private var preparationID = UUID()
    private var lastBatteryCaption = ""
    private var looper: AVPlayerLooper?
    private var pip: AVPictureInPictureController?
    private var observation: NSKeyValueObservation?
    private var itemObservation: NSKeyValueObservation?
    private var suspensionObservation: NSKeyValueObservation?
    private var powerObservation: Any?
    private var foregroundBatteryTimer: Timer?
    private var stopTask: UIBackgroundTaskIdentifier = .invalid
    private var stopReason = "已停止亮屏，恢复原有自动锁屏行为。"
    private var attempt = false
    private let logger = Logger(subsystem: "local.chargeunlock.ios", category: "playback")

    var powered: Bool { [.charging, .full].contains(UIDevice.current.batteryState) }
    var batteryText: String { BatteryReading.percentageText(UIDevice.current.batteryLevel) }
    var powerText: String { UIDevice.current.batteryState == .full ? "电量已满" : powered ? "正在充电" : "未连接电源" }
    var active: Bool { pip?.isPictureInPictureActive == true }

    override private init() {
        super.init()
        UIDevice.current.isBatteryMonitoringEnabled = true
        layer.player = player
        layer.videoGravity = .resizeAspect
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(powerChanged), name: UIDevice.batteryStateDidChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(powerChanged), name: UIDevice.batteryLevelDidChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(didActivate), name: UIApplication.didBecomeActiveNotification, object: nil)
        center.addObserver(self, selector: #selector(didDeactivate), name: UIApplication.willResignActiveNotification, object: nil)
        center.addObserver(self, selector: #selector(powerChanged), name: UIApplication.protectedDataWillBecomeUnavailableNotification, object: nil)
        center.addObserver(self, selector: #selector(interrupted(_:)), name: AVAudioSession.interruptionNotification, object: nil)
        center.addObserver(self, selector: #selector(playbackFailed), name: .AVPlayerItemFailedToPlayToEndTime, object: nil)
    }

    func attach() {
        refreshForegroundBattery()
        guard pip == nil else { attemptStart(); return }
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            status("此设备不支持画中画。")
            return
        }
        pip = AVPictureInPictureController(playerLayer: layer)
        pip?.delegate = self
        pip?.canStartPictureInPictureAutomaticallyFromInline = true
        pip?.requiresLinearPlayback = true
        observation = pip?.observe(\.isPictureInPicturePossible, options: [.initial, .new]) { [weak self] _, _ in
            Task { @MainActor in self?.attemptStart() }
        }
        suspensionObservation = pip?.observe(\.isPictureInPictureSuspended, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.powerChanged() }
        }
        attemptStart()
    }

    func start() async throws {
        guard !policy.stopping else { throw PlaybackError.stopping }
        guard powered else {
            stop(reason: "未检测到充电，请先连接电源。")
            throw PlaybackError.notPowered
        }
        guard !policy.requested else { return }
        guard let url = Bundle.main.url(forResource: "KeepAwake", withExtension: "mp4") else { throw PlaybackError.missingVideo }
        let requestID = UUID()
        preparationID = requestID
        _ = policy.start(powered: true)
        status("正在准备充电画面…")
        updateBatteryOverlay()
        do {
            let item = AVPlayerItem(url: url)
            let overlay = batteryOverlay
            let composition = try await AVVideoComposition.videoComposition(with: item.asset, applyingCIFiltersWithHandler: { request in
                request.finish(with: overlay.composite(over: request.sourceImage), context: nil)
            })
            // A stop or unplug during asynchronous preparation must never restart playback.
            guard preparationID == requestID, policy.requested, powered else { return }
            item.videoComposition = composition
            let audio = AVAudioSession.sharedInstance()
            try audio.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
            try audio.setActive(true)
            pip?.canStartPictureInPictureAutomaticallyFromInline = true
            attempt = false
            looper = AVPlayerLooper(player: player, templateItem: item)
            itemObservation = player.observe(\.status, options: [.new]) { [weak self] _, _ in
                Task { @MainActor in
                    guard let self, self.player.status == .failed else { return }
                    self.stop(reason: "充电画面播放失败，请重试。")
                }
            }
            player.preventsDisplaySleepDuringVideoPlayback = true
            powerObservation = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 600), queue: .main) { [weak self] _ in
                Task { @MainActor in self?.powerChanged() }
            }
            player.play()
            status("正在开启画中画…请稍候。")
            attemptStart()
        } catch {
            if preparationID == requestID { stop(reason: "充电画面准备失败，请重试。") }
            throw error
        }
    }

    private func attemptStart() {
        guard policy.requested, powered, !attempt, !active,
              UIApplication.shared.applicationState == .active,
              layer.superlayer != nil, pip?.isPictureInPicturePossible == true else { return }
        attempt = true
        pip?.startPictureInPicture()
    }

    func stop(reason: String = "已停止亮屏，恢复原有自动锁屏行为。") {
        preparationID = UUID()
        stopReason = reason
        policy.stop(pictureInPicturePending: policy.stopping || active || attempt)
        pip?.canStartPictureInPictureAutomaticallyFromInline = false
        player.preventsDisplaySleepDuringVideoPlayback = false
        if let powerObservation {
            player.removeTimeObserver(powerObservation)
            self.powerObservation = nil
        }
        guard policy.stopping else { finishStopping(); return }
        // PiP dismissal is asynchronous; retain background execution until its delegate confirms closure.
        if stopTask == .invalid {
            stopTask = UIApplication.shared.beginBackgroundTask(withName: "Close Picture in Picture") { [weak self] in
                Task { @MainActor in
                    guard let self else { return }
                    self.player.pause()
                    self.endStopTask()
                    self.status("画中画关闭未完成，已暂停播放；请解锁后重试停止。")
                }
            }
        }
        status("正在关闭画中画…")
        pip?.stopPictureInPicture()
    }

    private func finishStopping() {
        policy.didStopPictureInPicture()
        attempt = false
        player.pause()
        looper?.disableLooping()
        looper = nil
        itemObservation = nil
        player.removeAllItems()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        status(stopReason)
        endStopTask()
    }

    private func endStopTask() {
        guard stopTask != .invalid else { return }
        let task = stopTask
        stopTask = .invalid
        UIApplication.shared.endBackgroundTask(task)
    }

    private func status(_ text: String) {
        message = text
        logger.notice("\(text, privacy: .public)")
        let record: [String: Any] = ["message": text, "requested": policy.requested, "stopping": policy.stopping, "pipActive": active, "powered": powered, "playbackRate": player.rate, "battery": batteryText, "time": Date().timeIntervalSince1970]
        if let data = try? JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys]),
           let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            try? data.write(to: documents.appendingPathComponent("status.json"), options: .atomic)
        }
        onChange?()
    }

    private func updateBatteryOverlay() {
        let caption = "\(powerText) · \(batteryText)"
        guard caption != lastBatteryCaption else { return }
        lastBatteryCaption = caption
        batteryOverlay.update(caption: caption)
    }

    @objc private func powerChanged() {
        updateBatteryOverlay()
        if !powered && (policy.requested || active || attempt) && !policy.stopping {
            stop(reason: "电源已断开，充电亮屏已停止。")
        }
        onChange?()
    }
    @objc private func didActivate() {
        if policy.stopping {
            if !active && !attempt { finishStopping() }
            else { stop(reason: stopReason) }
        }
        refreshForegroundBattery()
        attemptStart()
    }
    func refreshForegroundBattery() {
        powerChanged()
        guard UIApplication.shared.applicationState == .active, foregroundBatteryTimer == nil else { return }
        let timer = Timer(timeInterval: 1, target: self, selector: #selector(powerChanged), userInfo: nil, repeats: true)
        timer.tolerance = 0.2
        foregroundBatteryTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    @objc private func didDeactivate() {
        foregroundBatteryTimer?.invalidate()
        foregroundBatteryTimer = nil
        powerChanged()
    }
    @objc private func playbackFailed() { stop(reason: "视频播放中断，亮屏已停止。") }
    @objc private func interrupted(_ note: Notification) {
        if (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber)?.uintValue == AVAudioSession.InterruptionType.began.rawValue {
            stop(reason: "播放被系统打断，亮屏已停止。")
        }
    }

    func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
        attempt = false
        guard powered, policy.requested else { stop(); return }
        status("画中画已开启，正在返回桌面。")
        // This developer-installed app uses a private API; iOS has no public Home Screen action.
        // Defer until the PiP delegate callback completes, and recheck for a stop or unplug.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.powered, self.policy.requested, self.active,
                  UIApplication.shared.applicationState == .active else { return }
            let application = UIApplication.shared
            let suspend = NSSelectorFromString("suspend")
            guard application.responds(to: suspend) else {
                self.status("画中画已开启，请上滑返回桌面。")
                return
            }
            application.perform(suspend)
        }
    }
    func pictureInPictureController(_ controller: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        attempt = false
        policy.didStopPictureInPicture()
        stop(reason: "画中画未能启动，请留在本页后重试。")
        logger.error("PiP failed: \(error.localizedDescription, privacy: .public)")
    }
    func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        if policy.requested { stopReason = "画中画已关闭，亮屏已停止。" }
        policy.stop()
        if let powerObservation {
            player.removeTimeObserver(powerObservation)
            self.powerObservation = nil
        }
        player.preventsDisplaySleepDuringVideoPlayback = false
        pip?.canStartPictureInPictureAutomaticallyFromInline = false
        finishStopping()
    }
    func pictureInPictureController(_ controller: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        completionHandler(true)
    }
}

enum PlaybackError: LocalizedError {
    case notPowered, missingVideo, stopping
    var errorDescription: String? {
        switch self {
        case .notPowered: "请先连接电源，再开启充电亮屏。"
        case .missingVideo: "本地视频资源缺失，请重新安装。"
        case .stopping: "画中画正在关闭，请稍后再开启。"
        }
    }
}
