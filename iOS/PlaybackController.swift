import UIKit
import AVKit
import os
import CoreImage

@MainActor
final class PlaybackController: NSObject, @preconcurrency AVPictureInPictureControllerDelegate {
    static let shared = PlaybackController()
    let player = AVQueuePlayer()
    let layer = AVPlayerLayer()
    private(set) var message = L("Connect power, then start Keep Awake.")
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
    private var stopReason = L("Stopped. Your usual Auto-Lock settings apply.")
    private var attempt = false
    private let logger = Logger(subsystem: "local.chargeunlock.ios", category: "playback")

    var powered: Bool { [.charging, .full].contains(UIDevice.current.batteryState) }
    var batteryText: String { BatteryReading.percentageText(UIDevice.current.batteryLevel) }
    var powerText: String { UIDevice.current.batteryState == .full ? L("Fully charged") : powered ? L("Charging") : L("Not plugged in") }
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
            status(L("Picture in Picture is unavailable on this device."))
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
        Diagnostics.record("start_requested")
        guard !policy.stopping else { throw PlaybackError.stopping }
        guard powered else {
            stop(reason: L("No power detected. Please plug in first."))
            throw PlaybackError.notPowered
        }
        guard !policy.requested else { return }
        guard let url = Bundle.main.url(forResource: "KeepAwake", withExtension: "mp4") else { throw PlaybackError.missingVideo }
        let requestID = UUID()
        preparationID = requestID
        _ = policy.start(powered: true)
        status(L("Preparing charging display…"))
        updateBatteryOverlay()
        do {
            let item = AVPlayerItem(url: url)
            let overlay = batteryOverlay
            let composition: AVVideoComposition
            if #available(iOS 16.0, *) {
                composition = try await AVVideoComposition.videoComposition(with: item.asset, applyingCIFiltersWithHandler: { request in
                    request.finish(with: overlay.composite(over: request.sourceImage), context: nil)
                })
            } else {
                // Preload metadata so the iOS 15 composition initializer does not block on file loading.
                _ = try await item.asset.load(.duration, .tracks)
                composition = AVVideoComposition(asset: item.asset, applyingCIFiltersWithHandler: { request in
                    request.finish(with: overlay.composite(over: request.sourceImage), context: nil)
                })
            }
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
                    self.stop(reason: L("Charging playback failed. Please try again."))
                }
            }
            player.preventsDisplaySleepDuringVideoPlayback = true
            powerObservation = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 600), queue: .main) { [weak self] _ in
                Task { @MainActor in self?.powerChanged() }
            }
            player.play()
            status(L("Starting Picture in Picture… Please wait."))
            attemptStart()
        } catch {
            if preparationID == requestID { stop(reason: L("Unable to prepare charging display. Try again.")) }
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

    func stop(reason: String = L("Stopped. Your usual Auto-Lock settings apply.")) {
        Diagnostics.record("stop_requested")
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
                    self.status(L("Playback paused, but PiP has not closed. Unlock and try stopping again."))
                }
            }
        }
        status(L("Closing Picture in Picture…"))
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
        Diagnostics.record("playback_status")
        onChange?()
    }

    private func updateBatteryOverlay() {
        let caption = "\(powerText) · \(batteryText)"
        guard caption != lastBatteryCaption else { return }
        lastBatteryCaption = caption
        batteryOverlay.update(caption: caption)
    }

    @objc private func powerChanged() {
        Diagnostics.record("power_or_playback_changed", onlyIfChanged: true)
        updateBatteryOverlay()
        if !powered && (policy.requested || active || attempt) && !policy.stopping {
            stop(reason: L("Unplugged. Keep Awake stopped."))
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
    @objc private func playbackFailed() { stop(reason: L("Video interrupted. Keep Awake stopped.")) }
    @objc private func interrupted(_ note: Notification) {
        if (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber)?.uintValue == AVAudioSession.InterruptionType.began.rawValue {
            stop(reason: L("System interrupted playback. Keep Awake stopped."))
        }
    }

    func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
        attempt = false
        guard powered, policy.requested else { stop(); return }
        status(L("PiP is on. Swipe up to go Home or switch apps."))
        Diagnostics.record("pip_started")
    }
    func pictureInPictureController(_ controller: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        attempt = false
        policy.didStopPictureInPicture()
        stop(reason: L("PiP could not start. Stay on this page and try again."))
        Diagnostics.record("pip_error_\((error as NSError).code)")
        logger.error("PiP failed with code \((error as NSError).code)")
    }
    func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        if policy.requested { stopReason = L("PiP closed. Keep Awake stopped.") }
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
        case .notPowered: L("Plug in before starting Keep Awake.")
        case .missingVideo: L("Bundled video is missing. Please reinstall the app.")
        case .stopping: L("PiP is closing. Wait before starting again.")
        }
    }
}
