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
        title = L("PlugLit guide")
        view.backgroundColor = .systemGroupedBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: L("Done"), style: .done, target: self, action: #selector(close))
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "closeGuide"
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        let shortcuts: UIButton
        if #available(iOS 17.0, *) {
            shortcuts = ShortcutsUIButton(style: .automatic)
        } else {
            shortcuts = UIButton(type: .system)
            shortcuts.configuration = .filled()
            shortcuts.configuration?.title = L("Back to start Keep Awake")
            shortcuts.addTarget(self, action: #selector(close), for: .touchUpInside)
        }
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
        stack.addArrangedSubview(heading(L("Plug in. Stay awake.")))
        let steps = UIStackView()
        steps.distribution = .fillEqually
        steps.spacing = 8
        for (symbol, caption) in [("powerplug.fill", L("1 Plug in")), ("pip.enter", L("2 Start")), ("apps.iphone", L("3 Switch apps"))] {
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
        stack.addArrangedSubview(instructionCard(symbol: "hand.pinch", title: L("Smaller window, more space"), body: L("Pinch to resize PiP and drag to move it. PlugLit uses the size remembered by iOS. If you hide it at the edge, check that your screen stays awake.")))
        if #available(iOS 17.0, *) {
            stack.addArrangedSubview(heading(L("Automate when power changes")))
            let path = UILabel()
            path.text = L("Open Shortcuts → Automation → + → Charger.\nCreate both rules below and choose Run Immediately for each.")
            path.font = .preferredFont(forTextStyle: .subheadline)
            path.adjustsFontForContentSizeCategory = true
            path.textColor = .secondaryLabel
            path.numberOfLines = 0
            stack.addArrangedSubview(path)
            stack.addArrangedSubview(instructionCard(symbol: "bolt.circle.fill", title: L("Plug in → Start"), body: L("Is Connected → Run Immediately\nAdd PlugLit’s “Start Keep Awake”.")))
            stack.addArrangedSubview(instructionCard(symbol: "stop.circle", title: L("Unplug → Stop"), body: L("Is Disconnected → Run Immediately\nAdd PlugLit’s “Stop Keep Awake”.")))
            stack.addArrangedSubview(instructionCard(symbol: "checkmark.circle", title: L("Finally, test both rules"), body: L("Test with the phone unlocked: plug in to start PiP, unplug to stop. Auto-Lock follows your usual delay, not immediately. No Mac or testing helper needed.")))
        } else {
            stack.addArrangedSubview(instructionCard(symbol: "hand.tap", title: L("Start manually from Home"), body: L("Plug in, tap Start Keep Awake on Home, then return to the Home Screen. Unplug or tap Stop to end playback. Shortcut actions require iOS 17 or later.")))
        }
        detailsButton.configuration = .plain()
        detailsButton.configuration?.title = L("FAQ & turning off")
        detailsButton.configuration?.image = UIImage(systemName: "chevron.down")
        detailsButton.configuration?.imagePadding = 8
        detailsButton.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 4, bottom: 12, trailing: 4)
        detailsButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        detailsButton.contentHorizontalAlignment = .leading
        detailsButton.accessibilityIdentifier = "guideDetails"
        detailsButton.accessibilityValue = L("Collapsed")
        detailsButton.addTarget(self, action: #selector(toggleDetails), for: .touchUpInside)
        stack.addArrangedSubview(detailsButton)
        details.axis = .vertical
        details.spacing = 12
        details.isHidden = true
        if #available(iOS 17.0, *) {
            details.addArrangedSubview(instructionCard(symbol: "magnifyingglass", title: L("Can’t find the actions?"), body: L("Open PlugLit once, then reopen Shortcuts. Create a blank automation and search for PlugLit to add an action. Menus may vary by iOS version. Save each rule separately; the app cannot create or inspect personal automations for you.")))
        }
        details.addArrangedSubview(instructionCard(symbol: "lock", title: L("Keep Awake limitations"), body: L("Plugging in while locked may require unlocking first. Pausing, closing PiP or other media interruptions can end Keep Awake. If Auto-Lock is set to Never, stopping will not enable it. iOS does not let apps set PiP size or position.")))
        details.addArrangedSubview(instructionCard(symbol: "battery.100percent", title: L("Battery & animation"), body: L("Battery refreshes on opening and is checked every second while foregrounded or playing. System readings may lag. The bolt fills upward; the video source is 60 fps, with actual refresh controlled by iOS.")))
        details.addArrangedSubview(instructionCard(symbol: "pause.circle", title: L("Pause or uninstall"), body: L("Stop this session: tap the same button on Home.\nPause automatic starts: disable both automations in Shortcuts.\nBefore uninstalling: stop Keep Awake, delete both automations, then delete PlugLit to avoid broken rules.")))
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
        detailsButton.accessibilityValue = details.isHidden ? L("Collapsed") : L("Expanded")
    }
    @objc private func close() { dismiss(animated: true) }
}
