import Carbon
import Cocoa
import FlutterMacOS
import WebKit

func desktopBrowserAllowsNavigation(_ url: URL?, blockedHosts: Set<String>,
                                    mainFrame: Bool) -> Bool {
  guard let url, let scheme = url.scheme?.lowercased() else { return false }
  if !mainFrame && (scheme == "blob" || scheme == "data" ||
      ["about:blank", "about:srcdoc"].contains(url.absoluteString.lowercased())) {
    return true
  }
  guard scheme == "https" || scheme == "http",
        let host = url.host?.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")),
        !host.isEmpty, url.user == nil, url.password == nil else { return false }
  return !blockedHosts.contains(host)
}

func desktopBrowserCloseShortcut(_ character: String?, latinFallback: () -> String?) -> Bool {
  guard let character = character?.lowercased() else { return false }
  if character.utf8.allSatisfy({ $0 < 128 }) {
    return character == "w"
  }
  return latinFallback()?.lowercased() == "w"
}

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
  private var inputMonitor: Any?
  private var downloadInput: TimeInterval?
  private var downloadTarget: URL?
  private var muted = true

  init(configuration: WKWebViewConfiguration, blockedHosts: Set<String>, channel: FlutterMethodChannel) {
    self.channel = channel
    self.blockedHosts = blockedHosts
    super.init(frame: .zero, configuration: configuration)
    navigationDelegate = self
    uiDelegate = self
    setAllMediaPlaybackSuspended(true, completionHandler: nil)
    inputMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp, .keyDown]) {
      [weak self] event in
      self?.observeDownloadInput(event)
      return event
    }
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
        self.clearDownloadInput()
        self.load(URLRequest(url: url))
      case "back":
        self.clearDownloadInput()
        self.goBack()
      case "forward":
        self.clearDownloadInput()
        self.goForward()
      case "reload":
        self.clearDownloadInput()
        if let retryURL = self.retryURL {
          self.load(URLRequest(url: retryURL))
        } else {
          self.reload()
        }
      case "setMuted":
        guard let muted = call.arguments as? Bool else {
          result(FlutterError(code: "invalid_mute", message: nil, details: nil))
          return
        }
        self.muted = muted
        if muted { self.clearDownloadInput() }
        self.setAllMediaPlaybackSuspended(muted, completionHandler: nil)
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
    setAllMediaPlaybackSuspended(true, completionHandler: nil)
    if let inputMonitor { NSEvent.removeMonitor(inputMonitor) }
    inputMonitor = nil
    isHidden = true
  }

  deinit {
    if let inputMonitor { NSEvent.removeMonitor(inputMonitor) }
    channel.setMethodCallHandler(nil)
  }

  private func allows(_ url: URL?) -> Bool {
    desktopBrowserAllowsNavigation(url, blockedHosts: blockedHosts, mainFrame: true)
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
    let mainFrame = action.targetFrame?.isMainFrame != false
    let url = action.request.url
    let recentClick = downloadInput.map { ProcessInfo.processInfo.systemUptime - $0 < 1 } ?? false
    if mainFrame {
      downloadTarget = recentClick && action.navigationType == .linkActivated ? url : nil
    }
    if action.shouldPerformDownload {
      if recentClick && action.navigationType == .linkActivated { openDownload(url) }
      decisionHandler(.cancel)
      return
    }
    decisionHandler(desktopBrowserAllowsNavigation(url, blockedHosts: blockedHosts,
                                                   mainFrame: mainFrame) ? .allow : .cancel)
  }

  func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse,
               decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
    let url = response.response.url
    guard desktopBrowserAllowsNavigation(url, blockedHosts: blockedHosts,
                                         mainFrame: response.isForMainFrame) else {
      decisionHandler(.cancel)
      return
    }
    guard response.isForMainFrame else { decisionHandler(.allow); return }
    let disposition = (response.response as? HTTPURLResponse)?
      .value(forHTTPHeaderField: "Content-Disposition")?.split(separator: ";").first?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard response.canShowMIMEType, disposition?.lowercased() != "attachment" else {
      if url == downloadTarget { openDownload(url) }
      decisionHandler(.cancel)
      return
    }
    clearDownloadInput()
    decisionHandler(.allow)
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

  private func clearDownloadInput() {
    downloadInput = nil
    downloadTarget = nil
  }

  private func openDownload(_ url: URL?) {
    guard !muted, downloadInput != nil, allows(url) else { return }
    clearDownloadInput()
    openExternal(url)
  }

  private var ownsKeyboard: Bool {
    guard let responder = window?.firstResponder as? NSView else { return false }
    return responder === self || responder.isDescendant(of: self)
  }

  private func observeDownloadInput(_ event: NSEvent) {
    guard !muted, let window, event.window === window else { return }
    if event.type == .leftMouseUp {
      guard bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
    } else {
      guard ownsKeyboard, !event.isARepeat,
            ["\r", "\u{3}", " "].contains(event.charactersIgnoringModifiers ?? "") else { return }
    }
    downloadInput = ProcessInfo.processInfo.systemUptime
    downloadTarget = nil
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
       ownsKeyboard,
       desktopBrowserCloseShortcut(event.charactersIgnoringModifiers,
                                  latinFallback: { self.latinKey(event.keyCode) }) {
      if !event.isARepeat {
        channel.invokeMethod("event", arguments: ["type": "closeTab"])
      }
      return true
    }
    return super.performKeyEquivalent(with: event)
  }

  private func latinKey(_ keyCode: UInt16) -> String? {
    guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
          let data = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData),
          let bytes = CFDataGetBytePtr(Unmanaged<CFData>.fromOpaque(data).takeUnretainedValue())
    else { return nil }
    let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
    var deadKey: UInt32 = 0
    var count = 0
    var characters = [UniChar](repeating: 0, count: 4)
    let result = UCKeyTranslate(layout, keyCode, UInt16(kUCKeyActionDown), 0,
                                UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysMask),
                                &deadKey, characters.count, &count, &characters)
    return result == noErr ? String(decoding: characters.prefix(count), as: UTF16.self) : nil
  }
}
