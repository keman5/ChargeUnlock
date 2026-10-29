import UIKit
import AVKit
import os

@MainActor
final class PlaybackController: NSObject, @preconcurrency AVPictureInPictureControllerDelegate {
    static let shared = PlaybackController()
    let player = AVQueuePlayer()
    let layer = AVPlayerLayer()
    private(set) var message = "连接电源后，开启画中画保活。"
    private(set) var policy = ChargingPolicy()
    var onChange: (() -> Void)?
    private var looper: AVPlayerLooper?
    private var pip: AVPictureInPictureController?
    private var observation: NSKeyValueObservation?
    private var itemObservation: NSKeyValueObservation?
    private var suspensionObservation: NSKeyValueObservation?
    private var powerObservation: Any?
    private var stopTask: UIBackgroundTaskIdentifier = .invalid
    private var stopReason = "已停止保活，恢复原有自动锁屏行为。"
    private var attempt = false
    private let logger = Logger(subsystem: "local.chargeunlock.ios", category: "playback")

    var powered: Bool { [.charging, .full].contains(UIDevice.current.batteryState) }
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
        center.addObserver(self, selector: #selector(didActivate), name: UIApplication.didBecomeActiveNotification, object: nil)
        center.addObserver(self, selector: #selector(powerChanged), name: UIApplication.willResignActiveNotification, object: nil)
        center.addObserver(self, selector: #selector(powerChanged), name: UIApplication.protectedDataWillBecomeUnavailableNotification, object: nil)
        center.addObserver(self, selector: #selector(interrupted(_:)), name: AVAudioSession.interruptionNotification, object: nil)
        center.addObserver(self, selector: #selector(playbackFailed), name: .AVPlayerItemFailedToPlayToEndTime, object: nil)
    }

    func attach() {
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

    func start() throws {
        guard !policy.stopping else { throw PlaybackError.stopping }
        guard powered else {
            stop(reason: "未检测到充电，请先连接电源。")
            throw PlaybackError.notPowered
        }
        if active && policy.requested { return }
        guard Bundle.main.url(forResource: "KeepAwake", withExtension: "mp4") != nil else { throw PlaybackError.missingVideo }
        let audio = AVAudioSession.sharedInstance()
        try audio.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
        try audio.setActive(true)
        _ = policy.start(powered: true)
        pip?.canStartPictureInPictureAutomaticallyFromInline = true
        attempt = false
        if looper == nil, let url = Bundle.main.url(forResource: "KeepAwake", withExtension: "mp4") {
            let item = AVPlayerItem(url: url)
            looper = AVPlayerLooper(player: player, templateItem: item)
            itemObservation = player.observe(\.status, options: [.new]) { [weak self] _, _ in
                Task { @MainActor in
                    guard let self, self.player.status == .failed else { return }
                    self.stop(reason: "视频播放失败，请重试。")
                }
            }
        }
        player.preventsDisplaySleepDuringVideoPlayback = true
        if powerObservation == nil {
            powerObservation = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 600), queue: .main) { [weak self] _ in
                Task { @MainActor in self?.powerChanged() }
            }
        }
        player.play()
        status("正在准备画中画…若未弹出，请点“开启画中画”。")
        attemptStart()
    }

    private func attemptStart() {
        guard policy.requested, powered, !attempt, !active,
              UIApplication.shared.applicationState == .active,
              layer.superlayer != nil, pip?.isPictureInPicturePossible == true else { return }
        attempt = true
        pip?.startPictureInPicture()
    }

    func stop(reason: String = "已停止保活，恢复原有自动锁屏行为。") {
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
        let record: [String: Any] = ["message": text, "requested": policy.requested, "stopping": policy.stopping, "pipActive": active, "powered": powered, "playbackRate": player.rate, "time": Date().timeIntervalSince1970]
        if let data = try? JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys]),
           let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            try? data.write(to: documents.appendingPathComponent("status.json"), options: .atomic)
        }
        onChange?()
    }

    @objc private func powerChanged() {
        if !powered && (policy.requested || active || attempt) && !policy.stopping {
            stop(reason: "电源已断开，画中画保活已停止。")
        }
        onChange?()
    }
    @objc private func didActivate() {
        if policy.stopping {
            if !active && !attempt { finishStopping() }
            else { stop(reason: stopReason) }
        }
        powerChanged()
        attemptStart()
    }
    @objc private func playbackFailed() { stop(reason: "视频播放中断，保活已停止。") }
    @objc private func interrupted(_ note: Notification) {
        if (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber)?.uintValue == AVAudioSession.InterruptionType.began.rawValue {
            stop(reason: "播放被系统打断，保活已停止。")
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
        if policy.requested { stopReason = "画中画已关闭，保活已停止。" }
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
        case .notPowered: "请先连接电源，再开启充电保活。"
        case .missingVideo: "本地视频资源缺失，请重新安装。"
        case .stopping: "画中画正在关闭，请稍后再开启。"
        }
    }
}
