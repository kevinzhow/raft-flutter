import UIKit
import UniformTypeIdentifiers

/// Both extension entry points only copy content and hand it to the main app.
/// The main app owns destination selection, credentials, drafts and sending.
final class ShareViewController: UIViewController {
  private var writer: ShareInboxWriter?
  private var text: [String] = []
  private var providers: [NSItemProvider] = []
  private var cancelled = false
  private var prepared = false, appeared = false, publishing = false, opening = false
  private var handoffToken: String?
  private var openAttempt = 0
  private var openTimeout: DispatchWorkItem?
  private let progress = UIActivityIndicatorView(style: .medium)
  private let status = UILabel()
  private let retry = UIButton(type: .system)
  private let close = UIButton(type: .system)

  override func viewDidLoad() {
    super.viewDidLoad()
    // No system social-compose card, text editor or destination picker.
    view.backgroundColor = .systemBackground
    status.text = NSLocalizedString("Preparing share…", comment: "Copying incoming content")
    status.numberOfLines = 0
    status.textAlignment = .center
    retry.setTitle(NSLocalizedString("Open Raft", comment: "Retry main-app handoff"), for: .normal)
    retry.addTarget(self, action: #selector(retryOpen), for: .touchUpInside)
    retry.isHidden = true
    close.setTitle(NSLocalizedString("Cancel", comment: "Cancel incoming copy"), for: .normal)
    close.addTarget(self, action: #selector(closeShare), for: .touchUpInside)
    let stack = UIStackView(arrangedSubviews: [progress, status, retry, close])
    stack.axis = .vertical
    stack.spacing = 16
    stack.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
      stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
      stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor)
    ])
    progress.startAnimating()
    guard let items = extensionContext?.inputItems as? [NSExtensionItem],
          let group = Bundle.main.object(forInfoDictionaryKey: "RaftAppGroup") as? String else {
      fail(); return
    }
    providers = items.flatMap { $0.attachments ?? [] }
    guard providers.count <= 10 else { fail(); return }
    if providers.isEmpty {
      text = items.compactMap { $0.attributedContentText?.string }
    }
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let prepared = try ShareInboxWriter(root: ShareInboxWriter.directory(group: group))
        DispatchQueue.main.async {
          guard !self.cancelled else { prepared.cancel(); return }
          self.writer = prepared
          self.load(0)
        }
      } catch { DispatchQueue.main.async { if !self.cancelled { self.fail() } } }
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    appeared = true
    publishIfReady()
  }

  private func load(_ index: Int) {
    guard !cancelled else { return }
    guard index < providers.count else {
      prepared = true
      publishIfReady()
      return
    }
    let provider = providers[index]
    // URL/text providers are values, whereas media is copied before the
    // NSItemProvider temporary-file callback returns.
    if provider.hasItemConformingToTypeIdentifier(UTType.propertyList.identifier) {
      provider.loadItem(forTypeIdentifier: UTType.propertyList.identifier, options: nil) { [weak self] value, error in
        guard let self else { return }
        let payload = (value as? [String: Any])?[NSExtensionJavaScriptPreprocessingResultsKey] as? [String: Any]
        DispatchQueue.main.async {
          guard !self.cancelled else { return }
          guard error == nil, let url = payload?["url"] as? String, url.utf16.count <= 65536 else { self.fail(); return }
          if let title = payload?["title"] as? String, title.utf16.count <= 1000, !title.isEmpty { self.text.append(title) }
          if !self.text.contains(url) { self.text.append(url) }
          self.load(index + 1)
        }
      }
    } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
       !provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
      provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] value, error in
        guard let self else { return }
        let value = (value as? URL)?.absoluteString ?? (value as? String)
        DispatchQueue.main.async {
          guard !self.cancelled else { return }
          guard error == nil, let value, value.utf16.count <= 65536 else { self.fail(); return }
          self.text.append(value); self.load(index + 1)
        }
      }
    } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
      let writer = self.writer
      provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] value, error in
        guard let self else { return }
        guard error == nil, let url = value as? URL, let writer else {
          DispatchQueue.main.async { if !self.cancelled { self.fail() } }; return
        }
        let scoped = url.startAccessingSecurityScopedResource()
        do {
          let input = try ShareInboxWriter.Input(url)
          self.copy(input, writer: writer, filename: provider.suggestedName ?? url.lastPathComponent,
            mimeType: UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream",
            index: index, after: { if scoped { url.stopAccessingSecurityScopedResource() } })
        } catch {
          if scoped { url.stopAccessingSecurityScopedResource() }
          DispatchQueue.main.async { if !self.cancelled { self.fail() } }
        }
      }
    } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
      provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] value, error in
        guard let self else { return }
        let value = value as? String ?? (value as? NSAttributedString)?.string ??
          ((value as? Data).flatMap { $0.count <= 256 * 1024 ? String(data: $0, encoding: .utf8) : nil })
        DispatchQueue.main.async {
          guard !self.cancelled else { return }
          guard error == nil, let value, value.utf16.count <= 65536 else { self.fail(); return }
          self.text.append(value); self.load(index + 1)
        }
      }
    } else if let identifier = provider.registeredTypeIdentifiers.first(where: {
      guard let type = UTType($0) else { return false }
      return type.conforms(to: .data) && !type.conforms(to: .text) && type != .fileURL
    }) {
      let writer = self.writer
      provider.loadFileRepresentation(forTypeIdentifier: identifier) { [weak self] url, error in
        guard let self else { return }
        guard error == nil, let url, let writer else {
          DispatchQueue.main.async { if !self.cancelled { self.fail() } }; return
        }
        do {
          let input = try ShareInboxWriter.Input(url)
          self.copy(input, writer: writer, filename: self.filename(provider: provider, url: url, type: UTType(identifier)),
            mimeType: UTType(identifier)?.preferredMIMEType ?? UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream", index: index)
        } catch {
          DispatchQueue.main.async { if !self.cancelled { self.fail() } }
        }
      }
    } else { fail() }
  }

  private func filename(provider: NSItemProvider, url: URL, type: UTType?) -> String {
    var name = provider.suggestedName ?? url.lastPathComponent
    if (name as NSString).pathExtension.isEmpty,
       let suffix = type?.preferredFilenameExtension ?? (url.pathExtension.isEmpty ? nil : url.pathExtension) {
      name += "." + suffix
    }
    return name
  }

  private func copy(_ input: ShareInboxWriter.Input, writer: ShareInboxWriter,
                    filename: String, mimeType: String, index: Int, after: @escaping () -> Void = {}) {
    DispatchQueue.global(qos: .userInitiated).async {
      defer { after() }
      var success = false
      do { try writer.addFile(input, filename: filename, mimeType: mimeType); success = true }
      catch { }
      DispatchQueue.main.async {
        guard !self.cancelled else { return }
        if success { self.load(index + 1) } else { self.fail() }
      }
    }
  }

  private func publishIfReady() {
    guard appeared, prepared, !publishing, !cancelled, let writer else { return }
    publishing = true
    close.isEnabled = false
    let value = text.joined(separator: "\n")
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        // One atomic rename publishes the envelope only after every file is copied.
        let token = try writer.commit(text: value.isEmpty ? nil : value)
        DispatchQueue.main.async {
          guard !self.cancelled else { return }
          self.handoffToken = token
          self.close.isEnabled = true
          self.close.setTitle(NSLocalizedString("Close", comment: "Close saved share"), for: .normal)
          self.openMainApp()
        }
      } catch { DispatchQueue.main.async { if !self.cancelled { self.fail() } } }
    }
  }

  @objc private func retryOpen() { openMainApp() }

  private func openMainApp() {
    guard !cancelled, !opening, let token = handoffToken,
          let url = URL(string: "raft://share/" + token) else { return }
    opening = true
    openAttempt += 1
    let attempt = openAttempt
    retry.isHidden = true
    progress.startAnimating()
    status.text = NSLocalizedString("Opening Raft…", comment: "Incoming handoff")
    let completion: (Bool) -> Void = { [weak self] opened in
      DispatchQueue.main.async {
        guard let self, !self.cancelled, self.openAttempt == attempt else { return }
        self.openTimeout?.cancel()
        self.opening = false
        if opened {
          self.cancelled = true
          self.extensionContext?.completeRequest(returningItems: nil)
        } else {
          self.showOpenFailure()
        }
      }
    }
    let timeout = DispatchWorkItem { [weak self] in
      guard let self, !self.cancelled, self.openAttempt == attempt, self.opening else { return }
      self.opening = false
      self.showOpenFailure()
    }
    openTimeout = timeout
    DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: timeout)

    // Compatibility technique used by receive_sharing_intent and similar
    // libraries: use the modern public open API on the responder-chain app.
    // Apple does not guarantee this entry point from Share/Action extensions.
    // Keep extension API checking enabled; do not call sharedApplication or
    // private runtime selectors. The callback, not finding a responder, decides
    // whether opening succeeded. Saved content survives a rejected handoff.
    var responder: UIResponder? = self
    var visited = Set<ObjectIdentifier>()
    while let current = responder, visited.insert(ObjectIdentifier(current)).inserted {
      if let application = current as? UIApplication {
        application.open(url, options: [:], completionHandler: completion)
        return
      }
      responder = current.next
    }
    // Some hosts may honor the context request even without an app responder.
    extensionContext?.open(url, completionHandler: completion)
  }

  private func showOpenFailure() {
    progress.stopAnimating()
    status.text = NSLocalizedString("Your share is saved. Open Raft to continue.", comment: "Main-app handoff rejected")
    retry.isHidden = false
  }

  private func fail() {
    prepared = false
    writer?.cancel()
    progress.stopAnimating()
    status.text = NSLocalizedString("This content could not be prepared for sharing.", comment: "Incoming copy failed")
    close.isEnabled = true
  }

  @objc private func closeShare() {
    cancelled = true
    openAttempt += 1
    openTimeout?.cancel()
    writer?.cancel()
    if handoffToken != nil {
      // The content has already been accepted; closing leaves it for the app.
      extensionContext?.completeRequest(returningItems: nil)
    } else {
      extensionContext?.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
    }
  }

  deinit { openTimeout?.cancel(); writer?.cancel() }
}
