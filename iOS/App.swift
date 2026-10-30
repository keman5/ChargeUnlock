import UIKit
import AppIntents

@main
@MainActor
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        _ = PlaybackController.shared
        Diagnostics.record("app_launched")
        ChargingShortcuts.updateAppShortcutParameters()
        return true
    }
}

@MainActor
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        window.tintColor = UIColor(named: "AccentColor")
        window.rootViewController = MainViewController()
        window.makeKeyAndVisible()
        self.window = window
        for context in connectionOptions.urlContexts { handle(context.url) }
    }
    func scene(_ scene: UIScene, openURLContexts contexts: Set<UIOpenURLContext>) {
        for context in contexts { handle(context.url) }
    }
    private func handle(_ url: URL) {
        guard ["chargeunlock", "pluglit"].contains(url.scheme ?? ""), ["start", "stop"].contains(url.host ?? "") else { return }
        if url.host == "stop" { PlaybackController.shared.stop() }
        else { Task { try? await PlaybackController.shared.start() } }
    }
}

@MainActor
final class MainViewController: UIViewController {
    #if DEBUG
    private var didPreview = false
    #endif
    private let controller = PlaybackController.shared
    private let preview = UIView()
    private let cardContent = UIStackView()
    private let cardTitle = UILabel()
    private let cardDetail = UILabel()
    private let status = UILabel()
    private let power = UILabel()
    private let toggle = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor), scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -48)
        ])
        let title = UILabel()
        title.text = "电亮"
        title.font = .preferredFont(forTextStyle: .largeTitle)
        title.adjustsFontForContentSizeCategory = true
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let header = UIStackView(arrangedSubviews: [title,
            headerButton(symbol: "info", label: "关于电亮", identifier: "openAbout", action: #selector(showAbout)),
            headerButton(symbol: "book.closed", label: "自动化设置与使用指南", identifier: "openGuide", action: #selector(showGuide))])
        header.alignment = .center
        header.spacing = 8
        stack.addArrangedSubview(header)
        stack.setCustomSpacing(6, after: header)
        let subtitle = UILabel()
        subtitle.text = "PlugLit · 插上电，让屏幕亮着"
        subtitle.font = .preferredFont(forTextStyle: .subheadline)
        subtitle.adjustsFontForContentSizeCategory = true
        subtitle.numberOfLines = 0
        subtitle.textColor = .secondaryLabel
        stack.addArrangedSubview(subtitle)
        power.font = .preferredFont(forTextStyle: .headline)
        power.adjustsFontForContentSizeCategory = true
        power.numberOfLines = 0
        stack.addArrangedSubview(power)
        preview.backgroundColor = .secondarySystemGroupedBackground
        preview.layer.cornerRadius = 20
        preview.clipsToBounds = true
        preview.layer.addSublayer(controller.layer)
        preview.heightAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true
        cardContent.axis = .vertical
        cardContent.alignment = .center
        cardContent.spacing = 12
        cardContent.translatesAutoresizingMaskIntoConstraints = false
        let symbol = UIImageView(image: UIImage(systemName: "bolt.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 38, weight: .semibold)))
        symbol.contentMode = .scaleAspectFit
        symbol.isAccessibilityElement = false
        cardContent.addArrangedSubview(symbol)
        cardTitle.font = .preferredFont(forTextStyle: .title2)
        cardDetail.font = .preferredFont(forTextStyle: .subheadline)
        cardDetail.textColor = .secondaryLabel
        for label in [cardTitle, cardDetail] {
            label.numberOfLines = 0
            label.textAlignment = .center
            label.adjustsFontForContentSizeCategory = true
            cardContent.addArrangedSubview(label)
        }
        cardTitle.accessibilityIdentifier = "chargingCardTitle"
        preview.addSubview(cardContent)
        NSLayoutConstraint.activate([
            cardContent.leadingAnchor.constraint(equalTo: preview.leadingAnchor, constant: 20),
            cardContent.trailingAnchor.constraint(equalTo: preview.trailingAnchor, constant: -20),
            cardContent.topAnchor.constraint(equalTo: preview.topAnchor, constant: 24),
            cardContent.bottomAnchor.constraint(equalTo: preview.bottomAnchor, constant: -24)
        ])
        stack.addArrangedSubview(preview)
        status.font = .preferredFont(forTextStyle: .body)
        status.numberOfLines = 0
        status.adjustsFontForContentSizeCategory = true
        status.accessibilityIdentifier = "playbackStatus"
        stack.addArrangedSubview(status)
        toggle.configuration = .filled()
        toggle.configuration?.cornerStyle = .fixed
        toggle.configuration?.background.cornerRadius = 16
        toggle.configuration?.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFont.preferredFont(forTextStyle: .headline)
            return attributes
        }
        toggle.configuration?.baseForegroundColor = UIColor { $0.userInterfaceStyle == .dark ? .black : .white }
        toggle.configuration?.imagePadding = 8
        toggle.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
        toggle.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
        toggle.addTarget(self, action: #selector(toggleCharging), for: .touchUpInside)
        toggle.accessibilityIdentifier = "toggleCharging"
        stack.addArrangedSubview(toggle)
        stack.addArrangedSubview(instructionCard(symbol: "hand.pinch", title: "画中画太大？", body: "双指捏合即可缩放，再拖到合适角落。电亮会沿用 iOS 记住的窗口尺寸。"))
        stack.addArrangedSubview(instructionCard(symbol: "info.circle", title: "关于亮屏与锁屏", body: "iOS 不允许应用自行调整画中画的位置和大小。播放视频可在系统允许时保持亮屏；收起到边缘后，请确认本机是否仍亮屏。拔电或停止后，按原有设置自动锁屏。"))
        controller.onChange = { [weak self] in self?.refresh() }
        refresh()
    }
    override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); controller.layer.frame = preview.bounds }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        controller.attach()
        #if DEBUG
        // Deterministic simulator captures without installing a UI-test helper.
        if !didPreview, let index = ProcessInfo.processInfo.arguments.firstIndex(of: "--preview-page"),
           ProcessInfo.processInfo.arguments.indices.contains(index + 1) {
            didPreview = true
            switch ProcessInfo.processInfo.arguments[index + 1] {
            case "about": showAbout()
            case "feedback": present(UINavigationController(rootViewController: FeedbackViewController()), animated: false)
            case "guide": showGuide()
            default: break
            }
            return
        }
        #endif
        if !UserDefaults.standard.bool(forKey: "pluglitGuideSeen"), !controller.policy.requested {
            showGuide()
        }
    }
    private func refresh() {
        status.text = controller.message
        power.text = "\(controller.powerText) · \(controller.batteryText)"
        let playingInline = controller.policy.requested && !controller.active && !controller.policy.stopping && controller.player.rate > 0
        controller.layer.isHidden = !playingInline
        cardContent.isHidden = playingInline
        if controller.policy.stopping {
            cardTitle.text = "正在结束亮屏"
            cardDetail.text = "正在关闭画中画，请稍候。"
        } else if controller.active {
            cardTitle.text = "充电亮屏中"
            cardDetail.text = "\(controller.batteryText) · 可切换到其他 App\n拔掉电源后自动结束"
        } else if controller.policy.requested {
            cardTitle.text = "正在准备充电画面"
            cardDetail.text = "\(controller.batteryText) · 画中画即将开启"
        } else {
            cardTitle.text = controller.powered ? "已就绪，随时点亮" : "等待连接电源"
            cardDetail.text = "\(controller.batteryText) · 当前按系统设置自动锁屏\n\(controller.powered ? "点下方按钮开启充电亮屏" : "连接电源后即可开启充电亮屏")"
        }
        let canStop = controller.policy.requested || controller.active
        toggle.configuration?.title = controller.policy.stopping ? "正在停止…" : canStop ? "停止充电亮屏" : "开启充电亮屏"
        toggle.configuration?.image = UIImage(systemName: canStop ? "stop.fill" : "bolt.fill")
        toggle.configuration?.showsActivityIndicator = controller.policy.stopping
        toggle.isEnabled = !controller.policy.stopping && (canStop || controller.powered)
        toggle.accessibilityValue = controller.policy.stopping ? "正在停止" : canStop ? "已开启" : "已关闭"
    }
    @objc private func toggleCharging() {
        guard !controller.policy.stopping else { return }
        if controller.policy.requested || controller.active { controller.stop(); return }
        Task {
            do { try await controller.start() } catch { status.text = error.localizedDescription }
        }
    }
    @objc private func showGuide() {
        guard presentedViewController == nil else { return }
        UserDefaults.standard.set(true, forKey: "pluglitGuideSeen")
        present(UINavigationController(rootViewController: GuideViewController()), animated: true)
    }
    private func headerButton(symbol: String, label: String, identifier: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.configuration = .tinted()
        button.configuration?.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium))
        button.configuration?.cornerStyle = .capsule
        button.accessibilityLabel = label
        button.accessibilityIdentifier = identifier
        button.widthAnchor.constraint(equalToConstant: 44).isActive = true
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
    @objc private func showAbout() {
        guard presentedViewController == nil else { return }
        present(UINavigationController(rootViewController: AboutViewController()), animated: true)
    }
}
