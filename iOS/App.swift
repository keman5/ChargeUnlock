import UIKit
import AppIntents

@main
@MainActor
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        _ = PlaybackController.shared
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
        window.rootViewController = MainViewController()
        window.makeKeyAndVisible()
        self.window = window
        for context in connectionOptions.urlContexts { handle(context.url) }
    }
    func scene(_ scene: UIScene, openURLContexts contexts: Set<UIOpenURLContext>) {
        for context in contexts { handle(context.url) }
    }
    private func handle(_ url: URL) {
        guard url.scheme == "chargeunlock", ["start", "stop"].contains(url.host ?? "") else { return }
        if url.host == "stop" { PlaybackController.shared.stop() }
        else { try? PlaybackController.shared.start() }
    }
}

@MainActor
final class MainViewController: UIViewController {
    private let controller = PlaybackController.shared
    private let preview = UIView()
    private let status = UILabel()
    private let power = UILabel()
    private let start = UIButton(type: .system)
    private let stop = UIButton(type: .system)

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
        title.text = "ChargeUnlock"
        title.font = .preferredFont(forTextStyle: .largeTitle)
        title.adjustsFontForContentSizeCategory = true
        stack.addArrangedSubview(title)
        power.font = .preferredFont(forTextStyle: .headline)
        stack.addArrangedSubview(power)
        preview.backgroundColor = .secondarySystemGroupedBackground
        preview.layer.cornerRadius = 20
        preview.clipsToBounds = true
        preview.layer.addSublayer(controller.layer)
        preview.heightAnchor.constraint(equalTo: preview.widthAnchor, multiplier: 9.0 / 16.0).isActive = true
        stack.addArrangedSubview(preview)
        status.font = .preferredFont(forTextStyle: .body)
        status.numberOfLines = 0
        status.accessibilityIdentifier = "playbackStatus"
        stack.addArrangedSubview(status)
        start.configuration = .filled()
        start.configuration?.title = "开启画中画"
        start.configuration?.image = UIImage(systemName: "pip.enter")
        start.configuration?.imagePadding = 8
        start.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        start.addTarget(self, action: #selector(begin), for: .touchUpInside)
        start.accessibilityIdentifier = "startPiP"
        stack.addArrangedSubview(start)
        stop.configuration = .tinted()
        stop.configuration?.title = "停止保活"
        stop.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        stop.addTarget(self, action: #selector(end), for: .touchUpInside)
        stack.addArrangedSubview(stop)
        let help = UILabel()
        help.font = .preferredFont(forTextStyle: .footnote)
        help.textColor = .secondaryLabel
        help.numberOfLines = 0
        help.text = "自动化设置\n\n在快捷指令 → 自动化中创建：\n① 充电器已连接 → 立即运行 → 开始充电保活\n② 充电器已断开 → 立即运行 → 停止充电保活\n\n两个动作都在 ChargeUnlock 分类下。首次需手动配置；启动时会打开本 App。\n\n画中画大小由系统控制，可用双指缩小。断电后自动停止，不更改原来的自动锁定时间，也不会自动解锁手机。\n\n这是实验性保活方式：画中画播放、被遮到屏幕边缘或受到其他媒体打断时，实际防锁屏效果须以本机测试为准。"
        stack.addArrangedSubview(help)
        controller.onChange = { [weak self] in self?.refresh() }
        refresh()
    }
    override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); controller.layer.frame = preview.bounds }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); controller.attach() }
    private func refresh() {
        status.text = controller.message
        power.text = controller.powered ? "⚡ 已连接电源" : "未连接电源"
        start.isEnabled = controller.powered
        stop.isEnabled = controller.policy.requested || controller.active
    }
    @objc private func begin() {
        do { try controller.start() } catch { status.text = error.localizedDescription }
    }
    @objc private func end() { controller.stop() }
}
