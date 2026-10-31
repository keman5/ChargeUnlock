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
        title = L("Feedback")
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
        stack.addArrangedSubview(label(L("Describe the issue, steps and time (10–4,000 characters). Do not include passwords or sensitive information.")))
        details.font = .preferredFont(forTextStyle: .body)
        details.adjustsFontForContentSizeCategory = true
        details.backgroundColor = .secondarySystemGroupedBackground
        details.layer.cornerRadius = 12
        details.accessibilityLabel = L("Describe the issue")
        details.heightAnchor.constraint(equalToConstant: 150).isActive = true
        stack.addArrangedSubview(details)
        contact.borderStyle = .roundedRect
        contact.placeholder = L("Email for replies (optional)")
        contact.accessibilityLabel = L("Contact email, optional")
        contact.keyboardType = .emailAddress
        contact.textContentType = .emailAddress
        contact.autocapitalizationType = .none
        contact.autocorrectionType = .no
        stack.addArrangedSubview(contact)
        stack.addArrangedSubview(toggleRow(L("Include diagnostics (optional)"), control: includeDiagnostics))
        stack.addArrangedSubview(label(L("The report includes model identifier, iOS/app version, battery, low-power and thermal state, and up to 200 events from the last 7 days. It excludes device name, unique identifiers, photos and other apps’ content. Stored only on this device by default.")))
        stack.addArrangedSubview(button(L("Preview & export diagnostics"), action: #selector(preview)))
        stack.addArrangedSubview(button(L("Clear local diagnostics"), action: #selector(clear)))
        stack.addArrangedSubview(button(L("Read Privacy Policy"), action: #selector(privacy)))
        stack.addArrangedSubview(toggleRow(L("I agree to send this feedback to the website"), control: consent))
        stack.addArrangedSubview(label(L("Sent to auv.macseek.cc only when you submit. Feedback is kept for 30 days, then deleted by the next hourly cleanup. Servers may be abroad; the network provider processes your connection IP. You can export locally instead. Editing any content before retrying creates new feedback.")))
        submit.configuration = .filled()
        submit.configuration?.title = L("Send feedback")
        submit.addTarget(self, action: #selector(send), for: .touchUpInside)
        submit.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        stack.addArrangedSubview(submit)
        stack.addArrangedSubview(button(L("Feedback on the website"), action: #selector(website)))
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
        } catch { notice(L("Unable to read diagnostics"), L("Logs may be damaged or unavailable. Clear them and reproduce the issue, or send feedback without logs.")) }
    }
    @objc private func clear() {
        let alert = UIAlertController(title: L("Clear local diagnostics?"), message: L("This deletes this app’s local diagnostics. Shortcuts and submitted feedback are unchanged."), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L("Cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: L("Clear"), style: .destructive) { [weak self] _ in
            do {
                try Diagnostics.clear()
                self?.pendingBody = nil
                self?.pendingForm = nil
                self?.notice(L("Cleared"), L("Necessary events will be recorded again as you use the app."))
            }
            catch { self?.notice(L("Unable to clear"), L("Please try again later.")) }
        })
        present(alert, animated: true)
    }
    @objc private func privacy() {
        navigationController?.pushViewController(InformationTextViewController(title: L("Privacy Policy"), text: AppInformation.privacy), animated: true)
    }
    @objc private func website() { UIApplication.shared.open(AppInformation.website.appendingPathComponent("feedback/")) }

    @objc private func send() {
        view.endEditing(true)
        let description = details.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = (contact.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard description.count >= 10, description.count <= 4_000, email.count <= 254 else {
            notice(L("Check your message"), L("Use 10–4,000 characters for the issue and no more than 254 for email."))
            return
        }
        guard email.isEmpty || (email.contains("@") && !email.contains(where: { $0.isWhitespace })) else {
            notice(L("Check your email"), L("Enter a valid email address or leave it blank."))
            return
        }
        guard consent.isOn else { notice(L("Consent required"), L("Read the Privacy Policy and enable consent for this submission.")); return }
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
                        let reason = http.statusCode == 429 ? L("Too many requests. Try again in one minute.") : L("Website did not accept the request (HTTP %lld). Your text is saved. Retry later or export logs first.", Int64(http.statusCode))
                        notice(L("Feedback not sent"), reason)
                        return
                    }
                    struct Receipt: Decodable { let id: String }
                    let receipt = try JSONDecoder().decode(Receipt.self, from: data)
                    guard receipt.id == requestID else { throw URLError(.badServerResponse) }
                    details.text = ""
                    consent.isOn = false
                    pendingBody = nil
                    notice(L("Feedback received"), L("Reference: %@\nSave this reference to ask about or delete your feedback.", receipt.id))
                } catch { notice(L("Send failed"), L("Check your connection and retry. Your text is saved; receipt by the website is unconfirmed.")) }
            }
        } catch { notice(L("Unable to create report"), L("Send without diagnostics, or clear logs and reproduce the issue.")) }
    }
    private func notice(_ title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L("OK"), style: .default))
        present(alert, animated: true)
    }
}

@MainActor
private final class DiagnosticPreviewController: UIViewController {
    private let data: Data
    init(data: Data) { self.data = data; super.init(nibName: nil, bundle: nil); title = L("Diagnostic report") }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func loadView() {
        let text = UITextView()
        text.isEditable = false
        text.font = .preferredFont(forTextStyle: .body)
        text.adjustsFontForContentSizeCategory = true
        text.text = String(decoding: data, as: UTF8.self)
        view = text
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: L("Export"), style: .plain, target: self, action: #selector(exportReport))
    }
    @objc private func exportReport() {
        do {
            let file = try Diagnostics.export(data)
            let share = UIActivityViewController(activityItems: [file], applicationActivities: nil)
            share.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
            present(share, animated: true)
        } catch {
            let alert = UIAlertController(title: L("Export failed"), message: L("Unable to write the diagnostic file. Check free storage and retry."), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L("OK"), style: .default))
            present(alert, animated: true)
        }
    }
}
