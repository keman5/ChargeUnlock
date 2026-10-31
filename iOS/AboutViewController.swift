import UIKit

@MainActor
final class AboutViewController: UITableViewController {
    private enum Item: Int, CaseIterable {
        case version, update, feedback, website, apps, privacy, terms

        var title: String {
            switch self {
            case .version: L("Version")
            case .update: L("Check for updates")
            case .feedback: L("Feedback & diagnostics")
            case .website: L("Website")
            case .apps: L("More apps")
            case .privacy: L("Privacy Policy")
            case .terms: L("Terms of Use")
            }
        }
        var symbol: String {
            switch self {
            case .version: "info.circle"
            case .update: "arrow.triangle.2.circlepath"
            case .feedback: "bubble.left.and.exclamationmark.bubble.right"
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
            case .version, .feedback, .privacy, .terms: nil
            }
        }
    }
    private let sections: [[Item]] = [[.version, .update, .feedback], [.website, .apps], [.privacy, .terms]]
    private var info: [String: Any] { Bundle.main.infoDictionary ?? [:] }

    init() { super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L("About PlugLit")
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: L("Done"), style: .done, target: self, action: #selector(close))
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 64
        tableView.sectionHeaderHeight = UITableView.automaticDimension
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let inset = max(20, (view.safeAreaLayoutGuide.layoutFrame.width - 375) / 2)
        tableView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: inset, bottom: 0, trailing: inset)
    }

    override func numberOfSections(in tableView: UITableView) -> Int { sections.count }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { sections[section].count }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        [L("about.brand"), L("Discover"), L("Privacy & terms")][section]
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
        if item == .version {
            content.secondaryText = AppInformation.version(in: info)
        } else if let key = item.linkKey {
            if item != .update && AppInformation.url(for: key, in: info) == nil {
                content.secondaryText = L("Not available")
            }
        }
        cell.contentConfiguration = content
        cell.accessoryType = item == .version ? .none : .disclosureIndicator
        cell.selectionStyle = item == .version ? .none : .default
        cell.accessibilityIdentifier = "about_\(item)"
        if item != .version { cell.accessibilityTraits.insert(.button) }
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = sections[indexPath.section][indexPath.row]
        guard item != .version else { return }
        if item == .feedback {
            navigationController?.pushViewController(FeedbackViewController(), animated: true)
            return
        }
        if item == .update {
            UIApplication.shared.open(AppInformation.updateURL(in: info))
            return
        }
        if let key = item.linkKey {
            guard let url = AppInformation.url(for: key, in: info) else {
                notice(item.title, message: L("No address is available for %@.", item.title))
                return
            }
            UIApplication.shared.open(url, options: [:]) { [weak self] success in
                guard !success else { return }
                Task { @MainActor in self?.notice(L("Unable to open page"), message: L("Try again later, or check whether your device allows external links.")) }
            }
        } else {
            navigationController?.pushViewController(InformationTextViewController(title: item.title, text: item == .privacy ? AppInformation.privacy : AppInformation.terms), animated: true)
        }
    }
    private func notice(_ title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L("OK"), style: .default))
        present(alert, animated: true)
    }
    @objc private func close() { dismiss(animated: true) }
}

@MainActor
final class InformationTextViewController: UIViewController {
    private let text: String
    private let textView = UITextView()
    init(title: String, text: String) {
        self.text = text
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        textView.isEditable = false
        textView.backgroundColor = .systemBackground
        textView.dataDetectorTypes = [.link]
        textView.linkTextAttributes = [.foregroundColor: UIColor.label, .underlineStyle: NSUnderlineStyle.single.rawValue]
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = UIEdgeInsets(top: 24, left: 0, bottom: 40, right: 0)
        textView.accessibilityIdentifier = "informationDocument"
        renderText()
        textView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textView)
        let preferredWidth = textView.widthAnchor.constraint(equalTo: view.readableContentGuide.widthAnchor)
        preferredWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            preferredWidth,
            textView.centerXAnchor.constraint(equalTo: view.readableContentGuide.centerXAnchor),
            textView.widthAnchor.constraint(lessThanOrEqualTo: view.readableContentGuide.widthAnchor),
            textView.widthAnchor.constraint(lessThanOrEqualToConstant: 375),
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            renderText()
        }
    }

    private func renderText() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 6
        paragraph.paragraphSpacing = 8
        let body = UIFont.preferredFont(forTextStyle: .body, compatibleWith: traitCollection)
        let displayText = text.replacingOccurrences(of: "\n\n", with: "\n")
        let formatted = NSMutableAttributedString(string: displayText, attributes: [
            .font: body, .foregroundColor: UIColor.label, .paragraphStyle: paragraph
        ])
        var offset = 0
        for (index, section) in text.components(separatedBy: "\n\n").enumerated() {
            let firstLine = section.components(separatedBy: "\n")[0]
            let range = NSRange(location: offset, length: (firstLine as NSString).length)
            let spacing = paragraph.mutableCopy() as! NSMutableParagraphStyle
            spacing.paragraphSpacingBefore = index == 0 ? 0 : 24
            spacing.paragraphSpacing = index == 0 ? 12 : 10
            formatted.addAttributes([
                .font: index == 0
                    ? UIFont.preferredFont(forTextStyle: .subheadline, compatibleWith: traitCollection)
                    : UIFontMetrics(forTextStyle: .title3).scaledFont(for: .systemFont(ofSize: 20, weight: .semibold), compatibleWith: traitCollection),
                .foregroundColor: index == 0 ? UIColor.secondaryLabel : UIColor.label,
                .paragraphStyle: spacing
            ], range: range)
            offset += (section as NSString).length + 1
        }
        assert(formatted.string == displayText, "Legal formatting must preserve the complete policy text")
        textView.attributedText = formatted
    }
}
