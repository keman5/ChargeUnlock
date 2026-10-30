import UIKit

@MainActor
final class AboutViewController: UITableViewController {
    private enum Item: Int, CaseIterable {
        case update, website, apps, privacy, terms

        var title: String {
            switch self {
            case .update: "检查更新"
            case .website: "官方网站"
            case .apps: "更多应用"
            case .privacy: "隐私政策"
            case .terms: "使用条款"
            }
        }
        var symbol: String {
            switch self {
            case .update: "arrow.triangle.2.circlepath"
            case .website: "globe"
            case .apps: "square.grid.2x2"
            case .privacy: "hand.raised"
            case .terms: "doc.text"
            }
        }
        var linkKey: String? {
            switch self {
            case .update: "PlugLitUpdateURL"
            case .website: "PlugLitWebsiteURL"
            case .apps: "PlugLitMoreAppsURL"
            case .privacy, .terms: nil
            }
        }
    }
    private let sections: [[Item]] = [[.update], [.website, .apps], [.privacy, .terms]]
    private var info: [String: Any] { Bundle.main.infoDictionary ?? [:] }

    init() { super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "关于电亮"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "完成", style: .done, target: self, action: #selector(close))
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 64
        tableView.sectionHeaderHeight = UITableView.automaticDimension
    }

    override func numberOfSections(in tableView: UITableView) -> Int { sections.count }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { sections[section].count }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        ["电亮 PlugLit", "发现", "隐私与条款"][section]
    }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0: "版本 \(AppInformation.version(in: info))\n插上电，让屏幕亮着。\n通过发布页面获取新版本，不会自动安装更新。"
        case 2: "充电状态在本机处理，无需注册账号。"
        default: nil
        }
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = sections[indexPath.section][indexPath.row]
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        var content = cell.defaultContentConfiguration()
        content.text = item.title
        content.image = UIImage(systemName: item.symbol)
        content.imageProperties.tintColor = view.tintColor
        content.textProperties.numberOfLines = 0
        content.secondaryTextProperties.numberOfLines = 0
        content.directionalLayoutMargins.top = 16
        content.directionalLayoutMargins.bottom = 16
        if let key = item.linkKey {
            let available = AppInformation.url(for: key, in: info) != nil
            content.secondaryText = available ? (item == .update ? "前往发布页面查看最新版本" : "在浏览器中打开") : (item == .update ? "尚未接入发布渠道" : "暂未提供")
        }
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        cell.accessibilityIdentifier = "about_\(item)"
        cell.accessibilityTraits.insert(.button)
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = sections[indexPath.section][indexPath.row]
        if let key = item.linkKey {
            guard let url = AppInformation.url(for: key, in: info) else {
                notice(item.title, message: item == .update
                    ? "当前版本为 \(AppInformation.version(in: info))。尚未接入更新渠道，暂时无法检查新版本，请通过原安装渠道获取更新。"
                    : "暂未提供\(item.title)地址。")
                return
            }
            UIApplication.shared.open(url, options: [:]) { [weak self] success in
                guard !success else { return }
                Task { @MainActor in self?.notice("无法打开页面", message: "请稍后重试，或检查设备是否允许打开外部链接。") }
            }
        } else {
            navigationController?.pushViewController(InformationTextViewController(title: item.title, text: item == .privacy ? AppInformation.privacy : AppInformation.terms), animated: true)
        }
    }
    private func notice(_ title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }
    @objc private func close() { dismiss(animated: true) }
}

@MainActor
private final class InformationTextViewController: UIViewController {
    private let text: String
    init(title: String, text: String) {
        self.text = text
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let textView = UITextView()
        textView.isEditable = false
        textView.backgroundColor = .systemBackground
        textView.textColor = .label
        textView.font = .preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.text = text
        textView.textContainerInset = UIEdgeInsets(top: 20, left: 20, bottom: 28, right: 20)
        textView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
}
