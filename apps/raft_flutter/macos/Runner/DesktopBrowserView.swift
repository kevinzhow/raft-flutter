import Cocoa
import FlutterMacOS
import WebKit

final class DesktopBrowserViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  private var sessions: [Int64: BrowserSession] = [:]

  private final class BrowserSession {
    let dataStore = WKWebsiteDataStore.nonPersistent()
    let views = NSHashTable<DesktopBrowserWebView>.weakObjects()
  }

  static func register(with registry: FlutterPluginRegistry) {
    let registrar = registry.registrar(forPlugin: "RaftDesktopBrowser")
    let factory = DesktopBrowserViewFactory(messenger: registrar.messenger)
    registrar.register(
      factory,
      withId: "app.raft/desktop_browser"
    )
    let channel = FlutterMethodChannel(
      name: "app.raft/desktop_browser",
      binaryMessenger: registrar.messenger
    )
    channel.setMethodCallHandler { [weak factory] call, result in
      guard call.method == "retireBrowserSession",
            let session = call.arguments as? NSNumber else {
        result(FlutterMethodNotImplemented)
        return
      }
      factory?.sessions.removeValue(forKey: session.int64Value)?.views.allObjects
        .forEach { $0.retire() }
      result(nil)
    }
  }

  private init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
  }

  func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol)? {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
    guard let args = args as? [String: Any],
          let id = (args["session"] as? NSNumber)?.int64Value,
          let blockedHosts = args["blockedHosts"] as? [String] else { return NSView() }
    let session = sessions[id] ?? BrowserSession()
    sessions[id] = session
    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = session.dataStore
    configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
    let channel = FlutterMethodChannel(
      name: "app.raft/desktop_browser/\(viewId)",
      binaryMessenger: messenger
    )
    let view = DesktopBrowserWebView(
      configuration: configuration,
      blockedHosts: Set(blockedHosts.map { $0.lowercased() }),
      channel: channel
    )
    session.views.add(view)
    return view
  }
}

private final class DesktopBrowserWebView: WKWebView, WKNavigationDelegate, WKUIDelegate {
  private let channel: FlutterMethodChannel
  private let blockedHosts: Set<String>
  private var observations: [NSKeyValueObservation] = []
  private var retryURL: URL?

  init(configuration: WKWebViewConfiguration, blockedHosts: Set<String>, channel: FlutterMethodChannel) {
    self.channel = channel
    self.blockedHosts = blockedHosts
    super.init(frame: .zero, configuration: configuration)
    navigationDelegate = self
    uiDelegate = self
    observations = [
      observe(\.url) { [weak self] _, _ in self?.report() },
      observe(\.title) { [weak self] _, _ in self?.report() },
      observe(\.isLoading) { [weak self] _, _ in self?.report() },
      observe(\.canGoBack) { [weak self] _, _ in self?.report() },
      observe(\.canGoForward) { [weak self] _, _ in self?.report() },
    ]
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(FlutterMethodNotImplemented); return }
      switch call.method {
      case "load":
        guard let raw = call.arguments as? String,
              let url = URL(string: raw),
              self.allows(url) else {
          result(FlutterError(code: "invalid_url", message: nil, details: nil))
          return
        }
        self.load(URLRequest(url: url))
      case "back":
        self.goBack()
      case "forward":
        self.goForward()
      case "reload":
        if let retryURL = self.retryURL {
          self.load(URLRequest(url: retryURL))
        } else {
          self.reload()
        }
      default:
        result(FlutterMethodNotImplemented)
        return
      }
      result(nil)
    }
  }

  required init?(coder: NSCoder) { return nil }

  func retire() {
    observations.removeAll()
    navigationDelegate = nil
    uiDelegate = nil
    channel.setMethodCallHandler(nil)
    stopLoading()
    isHidden = true
  }

  deinit {
    channel.setMethodCallHandler(nil)
  }

  private func allows(_ url: URL?) -> Bool {
    guard let url = url,
          let scheme = url.scheme?.lowercased(),
          scheme == "https" || scheme == "http",
          let host = url.host?.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")),
          !host.isEmpty,
          url.user == nil,
          url.password == nil else { return false }
    return !blockedHosts.contains(host)
  }

  private func report() {
    var fields: [String: Any] = [
      "type": "browserState",
      "title": title ?? "",
      "back": canGoBack,
      "forward": canGoForward,
      "loading": isLoading,
    ]
    if allows(url) { fields["url"] = url?.absoluteString }
    channel.invokeMethod("event", arguments: fields)
  }

  func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
               decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    if action.shouldPerformDownload {
      openExternal(action.request.url)
      decisionHandler(.cancel)
      return
    }
    decisionHandler(action.targetFrame?.isMainFrame == false || allows(action.request.url)
      ? .allow : .cancel)
  }

  func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse,
               decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
    guard response.isForMainFrame else { decisionHandler(.allow); return }
    let url = response.response.url
    let disposition = (response.response as? HTTPURLResponse)?
      .value(forHTTPHeaderField: "Content-Disposition")?.split(separator: ";").first?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard response.canShowMIMEType, disposition?.lowercased() != "attachment" else {
      openExternal(url)
      decisionHandler(.cancel)
      return
    }
    decisionHandler(allows(url) ? .allow : .cancel)
  }

  func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
               for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
    if action.targetFrame == nil {
      openExternal(action.request.url)
    }
    return nil
  }

  private func openExternal(_ url: URL?) {
    if let url, allows(url) {
      channel.invokeMethod("event", arguments: ["type": "openExternal", "url": url.absoluteString])
    }
  }

  func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    retryURL = nil
    channel.invokeMethod("event", arguments: ["type": "navigationStarted"])
  }

  func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    channel.invokeMethod("event", arguments: ["type": "failed"])
  }

  func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    reportFailure(error)
  }

  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    reportFailure(error)
  }

  private func reportFailure(_ error: Error) {
    let failure = error as NSError
    if (failure.domain == NSURLErrorDomain && failure.code == NSURLErrorCancelled) ||
       (failure.domain == "WebKitErrorDomain" && failure.code == 102) { return }
    let failedURL = failure.userInfo[NSURLErrorFailingURLErrorKey] as? URL
    retryURL = allows(failedURL) ? failedURL : nil
    var event = ["type": "failed"]
    if let retryURL { event["url"] = retryURL.absoluteString }
    channel.invokeMethod("event", arguments: event)
  }

  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    let modifiers = event.modifierFlags.intersection([.command, .control, .shift, .option])
    if modifiers == .command,
       event.charactersIgnoringModifiers?.lowercased() == "w",
       let responder = window?.firstResponder as? NSView,
       responder === self || responder.isDescendant(of: self) {
      if !event.isARepeat {
        channel.invokeMethod("event", arguments: ["type": "closeTab"])
      }
      return true
    }
    return super.performKeyEquivalent(with: event)
  }
}
