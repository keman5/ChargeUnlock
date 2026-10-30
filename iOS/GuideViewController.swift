import UIKit
import AppIntents

@MainActor
func instructionCard(symbol: String, title: String, body: String) -> UIView {
    let icon = UIImageView(image: UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)))
    icon.contentMode = .scaleAspectFit
    icon.isAccessibilityElement = false
    icon.widthAnchor.constraint(equalToConstant: 30).isActive = true
    icon.heightAnchor.constraint(equalToConstant: 32).isActive = true
    let heading = UILabel()
    heading.text = title
    heading.font = .preferredFont(forTextStyle: .headline)
    let detail = UILabel()
    detail.text = body
    detail.font = .preferredFont(forTextStyle: .subheadline)
    detail.textColor = .secondaryLabel
    for label in [heading, detail] {
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
    }
    let text = UIStackView(arrangedSubviews: [heading, detail])
    text.axis = .vertical
    text.spacing = 6
    let card = UIStackView(arrangedSubviews: [icon, text])
    card.alignment = .top
    card.spacing = 12
    card.isLayoutMarginsRelativeArrangement = true
    card.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
    card.backgroundColor = .secondarySystemGroupedBackground
    card.layer.cornerRadius = 18
    return card
}

@MainActor
final class GuideViewController: UIViewController {
    private let details = UIStackView()
    private let detailsButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "电亮使用指南"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "完成", style: .done, target: self, action: #selector(close))
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "closeGuide"
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        let shortcuts = ShortcutsUIButton(style: .automatic)
        shortcuts.accessibilityIdentifier = "openShortcuts"
        shortcuts.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        view.addSubview(shortcuts)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: shortcuts.topAnchor, constant: -12),
            shortcuts.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            shortcuts.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            shortcuts.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            shortcuts.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -20),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -40)
        ])
        stack.addArrangedSubview(heading("插上电，让屏幕亮着"))
        let steps = UIStackView()
        steps.distribution = .fillEqually
        steps.spacing = 8
        for (symbol, caption) in [("powerplug.fill", "1 连接电源"), ("pip.enter", "2 开启亮屏"), ("apps.iphone", "3 切换 App")] {
            let icon = UIImageView(image: UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 30, weight: .medium)))
            icon.contentMode = .scaleAspectFit
            icon.heightAnchor.constraint(equalToConstant: 44).isActive = true
            icon.isAccessibilityElement = false
            let label = UILabel()
            label.text = caption
            label.font = .preferredFont(forTextStyle: .caption1)
            label.adjustsFontForContentSizeCategory = true
            label.textAlignment = .center
            label.numberOfLines = 0
            let step = UIStackView(arrangedSubviews: [icon, label])
            step.axis = .vertical
            step.spacing = 8
            steps.addArrangedSubview(step)
        }
        stack.addArrangedSubview(steps)
        stack.addArrangedSubview(instructionCard(symbol: "hand.pinch", title: "捏小一点，少挡一点", body: "双指捏合缩放画中画，拖动调整位置。电亮会沿用 iOS 记住的尺寸。收起到边缘后，请确认手机是否仍保持亮屏。"))
        stack.addArrangedSubview(heading("插拔电源，自动切换"))
        let path = UILabel()
        path.text = "打开「快捷指令」→ 自动化 → ＋ → 充电器\n分别建立下面两条规则，均选择「立即运行」。"
        path.font = .preferredFont(forTextStyle: .subheadline)
        path.adjustsFontForContentSizeCategory = true
        path.textColor = .secondaryLabel
        path.numberOfLines = 0
        stack.addArrangedSubview(path)
        stack.addArrangedSubview(instructionCard(symbol: "bolt.circle.fill", title: "插电 → 开启", body: "已连接 → 立即运行\n添加电亮的「开启充电亮屏」"))
        stack.addArrangedSubview(instructionCard(symbol: "stop.circle", title: "拔电 → 停止", body: "已断开 → 立即运行\n添加电亮的「停止充电亮屏」"))
        stack.addArrangedSubview(instructionCard(symbol: "checkmark.circle", title: "最后，拔插一次试试", body: "解锁手机后测试：插电出现画中画，拔电关闭。随后按原来的时间锁屏，不会立即熄屏。无需 Mac 或测试助手。"))
        detailsButton.configuration = .plain()
        detailsButton.configuration?.title = "常见问题与停用方法"
        detailsButton.configuration?.image = UIImage(systemName: "chevron.down")
        detailsButton.configuration?.imagePadding = 8
        detailsButton.contentHorizontalAlignment = .leading
        detailsButton.accessibilityIdentifier = "guideDetails"
        detailsButton.accessibilityValue = "已折叠"
        detailsButton.addTarget(self, action: #selector(toggleDetails), for: .touchUpInside)
        stack.addArrangedSubview(detailsButton)
        details.axis = .vertical
        details.spacing = 12
        details.isHidden = true
        details.addArrangedSubview(instructionCard(symbol: "magnifyingglass", title: "找不到快捷动作？", body: "先打开一次电亮，再重开快捷指令。新建空白自动化后，搜索「电亮」添加动作；系统入口可能因版本不同而变化。两条规则需分别保存，App 无法代你创建或检查个人自动化。"))
        details.addArrangedSubview(instructionCard(symbol: "lock", title: "亮屏的边界", body: "锁屏插电可能需要先解锁。暂停、关闭画中画或其他媒体打断，会结束亮屏；系统原设置为「永不」时，停止后也不会自动锁屏。iOS 不允许 App 自行调整画中画尺寸或位置。"))
        details.addArrangedSubview(instructionCard(symbol: "battery.100percent", title: "电量与动画", body: "打开 App 立即刷新，前台及播放时每秒补查系统电量；系统读数可能略有延迟。闪电自下而上填满，视频源为 60 fps，实际刷新率由 iOS 决定。"))
        details.addArrangedSubview(instructionCard(symbol: "pause.circle", title: "暂停或卸载", body: "只停本次：点首页同一个按钮停止。\n暂停自动运行：在快捷指令里停用两条自动化。\n卸载前：停止亮屏，删除两条自动化，再删除电亮，避免遗留规则报错。"))
        stack.addArrangedSubview(details)
    }

    private func heading(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .title2)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        return label
    }
    @objc private func toggleDetails() {
        details.isHidden.toggle()
        detailsButton.configuration?.image = UIImage(systemName: details.isHidden ? "chevron.down" : "chevron.up")
        detailsButton.accessibilityValue = details.isHidden ? "已折叠" : "已展开"
    }
    @objc private func close() { dismiss(animated: true) }
}
