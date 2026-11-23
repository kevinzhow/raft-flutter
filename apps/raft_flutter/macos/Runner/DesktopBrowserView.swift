import Cocoa
import FlutterMacOS
import WebKit

final class DesktopBrowserViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  private let dataStore = WKWebsiteDataStore.nonPersistent()

  static func register(with registry: FlutterPluginRegistry) {
    let registrar = registry.registrar(forPlugin: "RaftDesktopBrowser")
    registrar.register(
      DesktopBrowserViewFactory(messenger: registrar.messenger),
      withId: "app.raft/desktop_browser"
    )
  }

  private init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
  }

  func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol)? {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = dataStore
    configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
    let channel = FlutterMethodChannel(
      name: "app.raft/desktop_browser/\(viewId)",
      binaryMessenger: messenger
    )
    return DesktopBrowserWebView(
      configuration: configuration,
      blockedHosts: Set((args as? [String] ?? []).map { $0.lowercased() }),
      channel: channel
    )
  }
}

private final class DesktopBrowserWebView: WKWebView, WKNavigationDelegate, WKUIDelegate {
  private let channel: FlutterMethodChannel
  private let blockedHosts: Set<String>
  private var observations: [NSKeyValueObservation] = []

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
        self.reload()
      default:
        result(FlutterMethodNotImplemented)
        return
      }
      result(nil)
    }
  }

  required init?(coder: NSCoder) { return nil }

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
    decisionHandler(allows(action.request.url) ? .allow : .cancel)
  }

  func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
               for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
    if action.targetFrame == nil,
       action.navigationType == .linkActivated,
       let url = action.request.url,
       allows(url) {
      channel.invokeMethod("event", arguments: ["type": "openExternal", "url": url.absoluteString])
    }
    return nil
  }

  func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    channel.invokeMethod("event", arguments: ["type": "failed"])
  }

  func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    if (error as NSError).code != NSURLErrorCancelled {
      channel.invokeMethod("event", arguments: ["type": "failed"])
    }
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
