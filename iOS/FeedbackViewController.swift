import UIKit

@MainActor
final class FeedbackViewController: UIViewController {
    private let details = UITextView()
    private let contact = UITextField()
    private let includeDiagnostics = UISwitch()
    private let consent = UISwitch()
    private let submit = UIButton(type: .system)
    private var requestID = UUID().uuidString.lowercased()
    private var pendingBody: Data?
    private var pendingForm: [String]?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "问题反馈"
        view.backgroundColor = .systemGroupedBackground
        let scroll = UIScrollView()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor), scroll.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -40)
        ])
        stack.addArrangedSubview(label("请描述问题、操作步骤和发生时间（至少 10 字，最多 4,000 字）。不要填写密码或其他敏感信息。"))
        details.font = .preferredFont(forTextStyle: .body)
        details.adjustsFontForContentSizeCategory = true
        details.backgroundColor = .secondarySystemGroupedBackground
        details.layer.cornerRadius = 12
        details.accessibilityLabel = "问题描述"
        details.heightAnchor.constraint(equalToConstant: 150).isActive = true
        stack.addArrangedSubview(details)
        contact.borderStyle = .roundedRect
        contact.placeholder = "联系邮箱（选填，用于回复）"
        contact.accessibilityLabel = "联系邮箱，选填"
        contact.keyboardType = .emailAddress
        contact.textContentType = .emailAddress
        contact.autocapitalizationType = .none
        contact.autocorrectionType = .no
        stack.addArrangedSubview(contact)
        stack.addArrangedSubview(toggleRow("附带诊断报告（可选）", control: includeDiagnostics))
        stack.addArrangedSubview(label("报告自动读取机型标识、iOS / 应用版本、电量、省电与温度状态及最近 7 天内最多 200 条运行事件。不包含设备名称、唯一设备标识、照片或其他应用内容。默认仅保存在本机。"))
        stack.addArrangedSubview(button("预览与导出诊断报告", action: #selector(preview)))
        stack.addArrangedSubview(button("清空本地诊断日志", action: #selector(clear)))
        stack.addArrangedSubview(button("查看隐私政策", action: #selector(privacy)))
        stack.addArrangedSubview(toggleRow("同意将本次反馈发送至官网", control: consent))
        stack.addArrangedSubview(label("仅点击提交后才发送到 auv.macseek.cc。反馈保留 30 天，到期后在下一次每小时清理任务中删除；服务器可能位于境外，网络服务商会处理连接 IP。若不愿上传，可只导出到本机。修改任何内容后重试将作为新的反馈。"))
        submit.configuration = .filled()
        submit.configuration?.title = "提交反馈"
        submit.addTarget(self, action: #selector(send), for: .touchUpInside)
        submit.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        stack.addArrangedSubview(submit)
        stack.addArrangedSubview(button("在官网反馈", action: #selector(website)))
    }

    private func label(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.numberOfLines = 0
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        return label
    }
    private func toggleRow(_ text: String, control: UISwitch) -> UIStackView {
        let row = UIStackView(arrangedSubviews: [label(text), control])
        row.spacing = 12
        row.alignment = .center
        control.accessibilityLabel = text
        control.setContentHuggingPriority(.required, for: .horizontal)
        return row
    }
    private func button(_ title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.configuration = .tinted()
        button.configuration?.title = title
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
    @objc private func preview() {
        do {
            let data = try Diagnostics.report().data()
            navigationController?.pushViewController(DiagnosticPreviewController(data: data), animated: true)
        } catch { notice("无法读取诊断日志", "日志可能已损坏或暂时无法访问。可以清空后重新复现问题；仍可不附带日志提交反馈。") }
    }
    @objc private func clear() {
        let alert = UIAlertController(title: "清空本地诊断？", message: "这会删除本应用保存的诊断日志，不会修改快捷指令或已提交的反馈。", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "清空", style: .destructive) { [weak self] _ in
            do {
                try Diagnostics.clear()
                self?.pendingBody = nil
                self?.pendingForm = nil
                self?.notice("已清空", "后续运行将重新记录必要事件。")
            }
            catch { self?.notice("清空失败", "请稍后重试。") }
        })
        present(alert, animated: true)
    }
    @objc private func privacy() {
        navigationController?.pushViewController(InformationTextViewController(title: "隐私政策", text: AppInformation.privacy), animated: true)
    }
    @objc private func website() { UIApplication.shared.open(AppInformation.website.appendingPathComponent("feedback/")) }

    @objc private func send() {
        view.endEditing(true)
        let description = details.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = (contact.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard description.count >= 10, description.count <= 4_000, email.count <= 254 else {
            notice("请检查内容", "问题描述需要 10–4,000 字；邮箱不能超过 254 字。")
            return
        }
        guard email.isEmpty || (email.contains("@") && !email.contains(where: { $0.isWhitespace })) else {
            notice("请检查邮箱", "请输入有效的联系邮箱，或留空。")
            return
        }
        guard consent.isOn else { notice("尚未同意上传", "请先阅读隐私政策，并打开本次反馈上传同意开关。"); return }
        do {
            struct Feedback: Encodable {
                let message: String
                let email: String
                let consent: Bool
                let diagnostics: DiagnosticReport?
            }
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .sortedKeys
            // Keep an identical retry idempotent, even when the network lost the receipt.
            let form = [description, email, String(includeDiagnostics.isOn)]
            if pendingForm != form || pendingBody == nil {
                let report = includeDiagnostics.isOn ? try Diagnostics.report() : nil
                pendingBody = try encoder.encode(Feedback(message: description, email: email, consent: true, diagnostics: report))
                pendingForm = form
                requestID = UUID().uuidString.lowercased()
            }
            guard let body = pendingBody else { return }
            var payload = try JSONSerialization.jsonObject(with: body) as! [String: Any]
            payload["id"] = requestID
            var request = URLRequest(url: AppInformation.website.appendingPathComponent("api/feedback"))
            request.httpMethod = "POST"
            request.timeoutInterval = 20
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            submit.isEnabled = false
            details.isEditable = false
            contact.isEnabled = false
            includeDiagnostics.isEnabled = false
            consent.isEnabled = false
            submit.configuration?.showsActivityIndicator = true
            Task {
                defer {
                    submit.isEnabled = true
                    details.isEditable = true
                    contact.isEnabled = true
                    includeDiagnostics.isEnabled = true
                    consent.isEnabled = true
                    submit.configuration?.showsActivityIndicator = false
                }
                do {
                    let (data, response) = try await URLSession.shared.data(for: request)
                    guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
                    guard http.statusCode == 201 else {
                        let reason = http.statusCode == 429 ? "提交过于频繁，请一分钟后重试。" : "官网暂未接收成功（HTTP \(http.statusCode)）。内容已保留，可稍后重试或先导出日志。"
                        notice("反馈未提交", reason)
                        return
                    }
                    struct Receipt: Decodable { let id: String }
                    let receipt = try JSONDecoder().decode(Receipt.self, from: data)
                    guard receipt.id == requestID else { throw URLError(.badServerResponse) }
                    details.text = ""
                    consent.isOn = false
                    pendingBody = nil
                    notice("反馈已收到", "编号：\(receipt.id)\n请保存编号，查询或申请删除反馈时使用。")
                } catch { notice("发送失败", "请检查网络后重试。输入内容已保留，未确认官网是否收到。") }
            }
        } catch { notice("无法生成报告", "可以关闭附带诊断报告后提交，或清空日志并重新复现问题。") }
    }
    private func notice(_ title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        present(alert, animated: true)
    }
}

@MainActor
private final class DiagnosticPreviewController: UIViewController {
    private let data: Data
    init(data: Data) { self.data = data; super.init(nibName: nil, bundle: nil); title = "诊断报告预览" }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func loadView() {
        let text = UITextView()
        text.isEditable = false
        text.font = .preferredFont(forTextStyle: .body)
        text.adjustsFontForContentSizeCategory = true
        text.text = String(decoding: data, as: UTF8.self)
        view = text
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "导出", style: .plain, target: self, action: #selector(exportReport))
    }
    @objc private func exportReport() {
        do {
            let file = try Diagnostics.export(data)
            let share = UIActivityViewController(activityItems: [file], applicationActivities: nil)
            share.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
            present(share, animated: true)
        } catch {
            let alert = UIAlertController(title: "导出失败", message: "无法写入诊断文件，请检查剩余存储空间后重试。", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "知道了", style: .default))
            present(alert, animated: true)
        }
    }
}
