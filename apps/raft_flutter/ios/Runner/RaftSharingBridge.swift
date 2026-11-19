import Flutter
import UIKit
import Photos
import AVFoundation
import ImageIO
import CFNetwork
import UniformTypeIdentifiers

final class RaftSharingBridge: NSObject, FlutterPlugin {
  private let sessionQueue = DispatchQueue(label: "app.raft.share-access")
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "app.raft/sharing", binaryMessenger: registrar.messenger())
    let bridge = RaftSharingBridge()
    registrar.addMethodCallDelegate(bridge, channel: channel)
    // Attachment files: only the photo-library save is native on iOS (the other
    // saves go through the document picker plugin).
    let files = FlutterMethodChannel(name: "app.raft/attachment-files", binaryMessenger: registrar.messenger())
    files.setMethodCallHandler { call, result in bridge.handleFiles(call, result: result) }
    let frames = FlutterMethodChannel(name: "app.raft/video-frame", binaryMessenger: registrar.messenger())
    let clipboardChannel = FlutterMethodChannel(name: "app.raft/clipboard-attachments", binaryMessenger: registrar.messenger())
    let clipboard = RaftClipboardAttachments(channel: clipboardChannel)
    clipboardChannel.setMethodCallHandler { call, result in clipboard.handle(call, result) }
    let video = RaftVideoFrame()
    frames.setMethodCallHandler { call, result in video.handle(call, result) }
  }

  /// `saveToGallery`: adds an image to Photos (add-only access). The file is a
  /// private copy staged by Dart under Library/Caches; it keeps its name.
  func handleFiles(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "saveToGallery" else { result(FlutterMethodNotImplemented); return }
    guard let arguments = call.arguments as? [String: Any],
          let path = arguments["path"] as? String,
          let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first,
          URL(fileURLWithPath: path).resolvingSymlinksInPath().path
            .hasPrefix(cache.resolvingSymlinksInPath().path + "/") else {
      result(FlutterError(code: "invalid", message: "Invalid temporary image file.", details: nil)); return
    }
    let url = URL(fileURLWithPath: path)
    let name = (arguments["filename"] as? String) ?? url.lastPathComponent
    PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
      guard status == .authorized || status == .limited else {
        DispatchQueue.main.async {
          result(FlutterError(code: "permission", message: "Photo library access was declined.", details: nil))
        }
        return
      }
      PHPhotoLibrary.shared().performChanges({
        let options = PHAssetResourceCreationOptions()
        options.originalFilename = name
        PHAssetCreationRequest.forAsset().addResource(with: .photo, fileURL: url, options: options)
      }) { saved, _ in
        DispatchQueue.main.async {
          if saved { result("photos") }
          else { result(FlutterError(code: "save_failed", message: "The image could not be saved.", details: nil)) }
        }
      }
    }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "updateShareSession":
      guard let accessGroup = Bundle.main.object(forInfoDictionaryKey: "RaftShareKeychainGroup") as? String,
            !accessGroup.isEmpty, !accessGroup.contains("$(") else {
        result(FlutterError(code: "sharing_unavailable", message: "Share account is unavailable.", details: nil)); return
      }
      sessionQueue.async {
        do {
          let session = try (call.arguments as? [String: Any]).map { try ShareAccessSession.parse($0) }
          try ShareSessionVault(accessGroup: accessGroup).replace(session)
          DispatchQueue.main.async { result(nil) }
        } catch {
          DispatchQueue.main.async { result(FlutterError(code: "sharing_unavailable", message: "Share account is unavailable.", details: nil)) }
        }
      }
    case "incomingDirectory":
      guard let group = Bundle.main.object(forInfoDictionaryKey: "RaftAppGroup") as? String else {
        result(FlutterError(code: "sharing_unavailable", message: "The shared inbox is unavailable.", details: nil)); return
      }
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let path = try ShareInboxWriter.directory(group: group).path
          DispatchQueue.main.async { result(path) }
        } catch {
          DispatchQueue.main.async { result(FlutterError(code: "sharing_unavailable", message: "The shared inbox is unavailable.", details: nil)) }
        }
      }
    case "share":
      guard let arguments = call.arguments as? [String: Any],
            let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
            var controller = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
        result(FlutterError(code: "sharing_unavailable", message: "Open Raft before sharing.", details: nil)); return
      }
      while let presented = controller.presentedViewController { controller = presented }
      var items: [Any] = []
      if let text = arguments["text"] as? String, !text.isEmpty { items.append(text) }
      let paths = arguments["paths"] as? [String] ?? (arguments["path"] as? String).map { [$0] } ?? []
      for path in paths {
        // getTemporaryDirectory on iOS maps to Library/Caches, not /tmp.
        guard let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first,
              let file = ShareInboxWriter.exportFile(path: path, caches: cache) else {
          result(FlutterError(code: "invalid", message: "Invalid shared file.", details: nil)); return
        }
        items.append(file)
      }
      guard !items.isEmpty else { result(FlutterError(code: "invalid", message: "Nothing to share.", details: nil)); return }
      let sheet = UIActivityViewController(activityItems: items, applicationActivities: nil)
      sheet.popoverPresentationController?.sourceView = controller.view
      sheet.popoverPresentationController?.sourceRect = CGRect(x: controller.view.bounds.midX,
        y: controller.view.bounds.midY, width: 1, height: 1)
      sheet.popoverPresentationController?.permittedArrowDirections = []
      sheet.completionWithItemsHandler = { _, _, _, error in
        if error != nil { result(FlutterError(code: "sharing_failed", message: "System sharing failed.", details: nil)) }
        else { result(nil) }
      }
      controller.present(sheet, animated: true)
    default: result(FlutterMethodNotImplemented)
    }
  }
}

/// Copied images and files for the message composer. Detection reads only
/// metadata, so it never triggers the iOS paste prompt. iOS lets an app read
/// another app's copy without a prompt only inside the system Paste action, and
/// the engine's text view offers that action only for strings. So the Paste of
/// that view is extended: with attachments on the clipboard it reads them and
/// asks Dart to take them (`paste`); Dart then calls `read` for the result.
final class RaftClipboardAttachments {
  private static weak var shared: RaftClipboardAttachments?
  private let channel: FlutterMethodChannel
  private var observers: [NSObjectProtocol] = []
  private var changeCount = -1
  private var lastAvailable = false
  private var pending: (id: Int, load: (@escaping ([[String: Any]]) -> Void) -> Void)?
  private var pastes = 0
  /// Dart has a handler for `paste` (its watcher asks `available` first).
  /// Before that a `paste` would wait in the channel buffer with no answer,
  /// and a later overflow would run the text paste at a random moment.
  private(set) var dartReady = false

  init(channel: FlutterMethodChannel) {
    self.channel = channel
    for name in [UIPasteboard.changedNotification, UIApplication.didBecomeActiveNotification] {
      observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        self?.changed()
      })
    }
    Self.shared = self
    Self.installPasteHook()
    changed()
  }

  deinit {
    for observer in observers { NotificationCenter.default.removeObserver(observer) }
  }

  /// The type to attach from one clipboard item, or nil when the item is text.
  /// Copied text often carries a web archive or RTFD beside its string; those
  /// items paste as text. Images and copied files attach even with a string.
  static func attachmentType(_ identifiers: [String]) -> String? {
    let types = identifiers.compactMap { id in UTType(id).map { (id, $0) } }
    if let image = types.first(where: { $0.1.conforms(to: .image) }) { return image.0 }
    let file = identifiers.contains(UTType.fileURL.identifier)
    if !file && types.contains(where: { $0.1.conforms(to: .text) }) { return nil }
    if let data = types.first(where: {
      $0.1.conforms(to: .data) && !$0.1.conforms(to: .url) && (file || !$0.1.conforms(to: .text))
    }) { return data.0 }
    return file ? UTType.fileURL.identifier : nil
  }

  private func available() -> Bool {
    let board = UIPasteboard.general
    guard board.numberOfItems > 0 else { return false }
    return board.hasImages
      || (board.types(forItemSet: nil) ?? []).contains { Self.attachmentType($0) != nil }
  }

  private func changed() {
    let count = UIPasteboard.general.changeCount
    let value = available()
    guard count != changeCount || value != lastAvailable else { return }
    changeCount = count
    lastAvailable = value
    channel.invokeMethod("changed", arguments: value)
  }

  func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    switch call.method {
    case "available":
      dartReady = true
      result(available())
    case "read":
      // The files of the last system Paste, else a direct read (Cmd+V on an
      // iPad keyboard; iOS may ask the user first).
      let load = pending?.load ?? Self.load(UIPasteboard.general.itemProviders)
      pending = nil
      load { result($0) }
    default: result(FlutterMethodNotImplemented)
    }
  }

  // MARK: Paste hook

  private static var hooked = false

  /// Extends `canPerformAction(paste:)` and `paste:` of the engine's
  /// FlutterTextInputView. Only methods the class defines itself are changed,
  /// never an inherited UIKit one.
  private static func installPasteHook() {
    guard !hooked, let view = NSClassFromString("FlutterTextInputView") else { return }
    hooked = true
    func own(_ selector: Selector) -> Method? {
      guard let method = class_getInstanceMethod(view, selector) else { return nil }
      let inherited = class_getSuperclass(view).flatMap { class_getInstanceMethod($0, selector) }
      return inherited.map { method_getImplementation($0) } == method_getImplementation(method) ? nil : method
    }
    let canPerform = #selector(UIResponder.canPerformAction(_:withSender:))
    if let method = own(canPerform) {
      typealias Original = @convention(c) (AnyObject, Selector, Selector, Any?) -> Bool
      let original = unsafeBitCast(method_getImplementation(method), to: Original.self)
      let block: @convention(block) (AnyObject, Selector, Any?) -> Bool = { this, action, sender in
        if action == #selector(UIResponderStandardEditActions.paste(_:)),
           let bridge = shared, bridge.dartReady, bridge.available() { return true }
        return original(this, canPerform, action, sender)
      }
      method_setImplementation(method, imp_implementationWithBlock(block))
    }
    let paste = #selector(UIResponderStandardEditActions.paste(_:))
    if let method = own(paste) {
      typealias Original = @convention(c) (AnyObject, Selector, Any?) -> Void
      let original = unsafeBitCast(method_getImplementation(method), to: Original.self)
      let block: @convention(block) (AnyObject, Any?) -> Void = { this, sender in
        let text = { original(this, paste, sender) }
        if shared?.systemPaste(orElse: text) != true { text() }
      }
      method_setImplementation(method, imp_implementationWithBlock(block))
    }
  }

  /// Starts reading inside the trusted Paste action; false leaves the text
  /// paste. A focused field that takes no attachments gets [orElse].
  func systemPaste(orElse: @escaping () -> Void) -> Bool {
    guard dartReady, available() else { return false }
    let providers = UIPasteboard.general.itemProviders
    guard providers.contains(where: { Self.attachmentType($0.registeredTypeIdentifiers) != nil }) else {
      return false
    }
    pastes += 1
    let id = pastes
    pending = (id, Self.load(providers))
    channel.invokeMethod("paste", arguments: nil) { [weak self] taken in
      // Dart answers after the composer read the files, or did not read them.
      if self?.pending?.id == id { self?.pending = nil }
      if taken as? Bool != true { orElse() }
    }
    return true
  }

  // MARK: Reading

  /// Starts loading now and returns a function that delivers the entries once
  /// (on the main thread, in clipboard order).
  private static func load(_ providers: [NSItemProvider]) -> (@escaping ([[String: Any]]) -> Void) -> Void {
    let group = DispatchGroup()
    let lock = NSLock()
    var entries = Array<[String: Any]?>(repeating: nil, count: providers.count)
    for (index, provider) in providers.enumerated() {
      guard let identifier = attachmentType(provider.registeredTypeIdentifiers) else { continue }
      group.enter()
      // File representations are temporary: read before the provider callback returns.
      let consume: (URL?) -> Void = { url in
        defer { group.leave() }
        guard let url = url, url.isFileURL else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        // No size limit here: the upload selection applies the server's limit
        // and tells the user, as for picked files.
        guard let bytes = try? Data(contentsOf: url), !bytes.isEmpty else { return }
        let type = identifier == UTType.fileURL.identifier
          ? UTType(filenameExtension: url.pathExtension) : UTType(identifier)
        // A copied bitmap has no name; Web and desktop call it `image.png`. Its
        // file representation has a random temporary name, so do not use that.
        var name = provider.suggestedName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if name.isEmpty, identifier == UTType.fileURL.identifier { name = url.lastPathComponent }
        if name.isEmpty || name == "." {
          name = type?.conforms(to: .image) == true ? "image" : "attachment"
        }
        if (name as NSString).pathExtension.isEmpty,
           let ext = type?.preferredFilenameExtension { name += "." + ext }
        lock.lock()
        entries[index] = ["name": name, "bytes": FlutterStandardTypedData(bytes: bytes)]
        lock.unlock()
      }
      if identifier == UTType.fileURL.identifier {
        provider.loadObject(ofClass: NSURL.self) { object, _ in consume(object as? URL) }
      } else {
        provider.loadFileRepresentation(forTypeIdentifier: identifier) { url, _ in consume(url) }
      }
    }
    return { deliver in group.notify(queue: .main) { deliver(entries.compactMap { $0 }) } }
  }
}

// MARK: - System proxy (shared by iOS and macOS; keep both copies identical)

/// Reads the system HTTP proxy configuration with CFNetwork and answers
/// per-URL proxy lookups, running PAC scripts (`CFNetworkExecuteProxyAutoConfigurationURL`)
/// when the system uses one. Dart caches every answer; nothing here blocks a
/// request. WPAD auto-discovery is not executed (CFNetwork exposes no API for it
/// without the script text), so it is reported as `autoDetect` only.
final class RaftSystemProxy {
  private final class PacRun {
    var source: CFRunLoopSource?
    var finished = false
    let done: ([String]) -> Void
    init(done: @escaping ([String]) -> Void) { self.done = done }
    func finish(_ answer: [String]) {
      if finished { return }
      finished = true
      if let source = source {
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        CFRunLoopSourceInvalidate(source)
      }
      done(answer)
    }
  }

  static func settings() -> [String: Any] {
    (CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any]) ?? [:]
  }

  /// The static part of the configuration, independent of any URL.
  static func snapshot() -> [String: Any] {
    let s = settings()
    func flag(_ key: String) -> Bool { (s[key] as? NSNumber)?.boolValue ?? false }
    func hostPort(_ enable: String, _ host: String, _ port: String, fallback: Int) -> String? {
      guard flag(enable), let h = s[host] as? String, !h.isEmpty else { return nil }
      let p = (s[port] as? NSNumber)?.intValue ?? fallback
      return "\(h):\(p)"
    }
    var out: [String: Any] = [:]
    if let v = hostPort("HTTPEnable", "HTTPProxy", "HTTPPort", fallback: 80) { out["http"] = v }
    if let v = hostPort("HTTPSEnable", "HTTPSProxy", "HTTPSPort", fallback: 80) { out["https"] = v }
    if let v = hostPort("SOCKSEnable", "SOCKSProxy", "SOCKSPort", fallback: 1080) { out["socks"] = v }
    if flag("ProxyAutoConfigEnable"), let pac = s["ProxyAutoConfigURLString"] as? String, !pac.isEmpty {
      out["pacUrl"] = pac
    }
    out["autoDetect"] = flag("ProxyAutoDiscoveryEnable")
    out["bypass"] = (s["ExceptionsList"] as? [String]) ?? []
    out["excludeSimple"] = flag("ExcludeSimpleHostnames")
    return out
  }

  static func lines(_ proxies: [[String: Any]]) -> [String] {
    let none = kCFProxyTypeNone as String
    let http = kCFProxyTypeHTTP as String
    let https = kCFProxyTypeHTTPS as String
    let socks = kCFProxyTypeSOCKS as String
    return proxies.compactMap { entry -> String? in
      guard let type = entry[kCFProxyTypeKey as String] as? String else { return nil }
      let host = entry[kCFProxyHostNameKey as String] as? String
      let port = (entry[kCFProxyPortNumberKey as String] as? NSNumber)?.intValue
      if type == none { return "DIRECT" }
      guard let host = host, let port = port else { return nil }
      // Apple's "HTTPS" proxy is an HTTP proxy used for https URLs (CONNECT).
      if type == http || type == https { return "PROXY \(host):\(port)" }
      if type == socks { return "SOCKS \(host):\(port)" }
      return nil
    }
  }

  /// The system's decision for one URL, PAC evaluated. `done` runs on the main thread.
  static func resolve(_ urlString: String, done: @escaping ([String]) -> Void) {
    guard let url = URL(string: urlString) else { done([]); return }
    let cfProxies = CFNetworkCopyProxiesForURL(url as CFURL, settings() as CFDictionary).takeRetainedValue()
    let proxies = ((cfProxies as [AnyObject]) as? [[String: Any]]) ?? []
    let pacType = kCFProxyTypeAutoConfigurationURL as String
    guard let pac = proxies.first(where: { ($0[kCFProxyTypeKey as String] as? String) == pacType }),
      let pacURL = pac[kCFProxyAutoConfigurationURLKey as String] as? URL
    else {
      done(lines(proxies))
      return
    }
    let pending = PacRun(done: done)
    let retained = Unmanaged.passRetained(pending)
    var context = CFStreamClientContext(
      version: 0, info: retained.toOpaque(), retain: nil, release: nil, copyDescription: nil)
    let source = CFNetworkExecuteProxyAutoConfigurationURL(
      pacURL as CFURL, url as CFURL,
      { info, result, _ in
        let run = Unmanaged<PacRun>.fromOpaque(info).takeUnretainedValue()
        let list = ((result as [AnyObject]) as? [[String: Any]]) ?? []
        run.finish(RaftSystemProxy.lines(list))
      }, &context)
    pending.source = source
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    // A PAC host that never answers must not leave the lookup open.
    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
      pending.finish([])
      retained.release()
    }
  }
}

final class RaftProxyBridge: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "app.raft/system-proxy", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(RaftProxyBridge(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "snapshot":
      result(RaftSystemProxy.snapshot())
    case "resolve":
      guard let url = (call.arguments as? [String: Any])?["url"] as? String else {
        result(FlutterError(code: "invalid", message: "Missing URL.", details: nil)); return
      }
      RaftSystemProxy.resolve(url) { result($0) }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

// MARK: - First video frame (shared by iOS and macOS; keep both copies identical)

/// Channel `app.raft/video-frame` (see lib/platform/video_frame_probe.dart): the
/// first picture and the real shape of a video behind an http(s) URL, read with
/// AVFoundation's own ranged requests (the container header and one key frame),
/// never the whole file. `AVAssetImageGenerator` applies the track's preferred
/// transform, so the picture is upright and the size is the displayed one.
final class RaftVideoFrame {
  private final class Job {
    var cancelled = false
    var finished = false
    var generator: AVAssetImageGenerator?
    var asset: AVURLAsset?
    var timeout: DispatchWorkItem?
  }

  private let lock = NSLock()
  private var jobs: [String: Job] = [:]
  private let queue = DispatchQueue(label: "app.raft.video-frame")

  func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    switch call.method {
    case "probe":
      guard let args = call.arguments as? [String: Any],
        let id = args["id"] as? String,
        let text = args["url"] as? String,
        let url = URL(string: text),
        let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http"
      else {
        result(FlutterError(code: "failed", message: "Invalid video address.", details: nil))
        return
      }
      let headers = (args["headers"] as? [String: String]) ?? [:]
      let maxEdge = max(32, (args["maxEdge"] as? NSNumber)?.intValue ?? 640)
      let timeout = max(1.0, Double((args["timeoutMs"] as? NSNumber)?.intValue ?? 20000) / 1000)
      probe(id: id, url: url, headers: headers, maxEdge: maxEdge, timeout: timeout, result: result)
    case "cancel":
      if let id = (call.arguments as? [String: Any])?["id"] as? String { cancel(id) }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func cancel(_ id: String) {
    lock.lock()
    let job = jobs[id]
    job?.cancelled = true
    lock.unlock()
    job?.asset?.cancelLoading()
    job?.generator?.cancelAllCGImageGeneration()
  }

  private func probe(
    id: String, url: URL, headers: [String: String], maxEdge: Int, timeout: TimeInterval,
    result: @escaping FlutterResult
  ) {
    let job = Job()
    lock.lock()
    // A second request under the same id replaces the first.
    let previous = jobs[id]
    jobs[id] = job
    lock.unlock()
    previous?.cancelled = true
    previous?.asset?.cancelLoading()

    func finish(_ value: Any?) {
      lock.lock()
      if job.finished { lock.unlock(); return }
      job.finished = true
      if jobs[id] === job { jobs[id] = nil }
      lock.unlock()
      job.timeout?.cancel()
      job.generator?.cancelAllCGImageGeneration()
      job.asset?.cancelLoading()
      DispatchQueue.main.async { result(value) }
    }
    func fail(_ code: String, _ message: String) {
      finish(FlutterError(code: code, message: message, details: nil))
    }

    let options: [String: Any] = headers.isEmpty ? [:] : ["AVURLAssetHTTPHeaderFieldsKey": headers]
    let asset = AVURLAsset(url: url, options: options.isEmpty ? nil : options)
    job.asset = asset
    let watchdog = DispatchWorkItem { fail("failed", "Timed out.") }
    job.timeout = watchdog
    queue.asyncAfter(deadline: .now() + timeout, execute: watchdog)

    asset.loadValuesAsynchronously(forKeys: ["tracks", "duration", "playable"]) { [weak self] in
      guard let self = self else { return }
      if job.cancelled { fail("cancelled", "Cancelled."); return }
      var error: NSError?
      for key in ["tracks", "duration"] {
        if asset.statusOfValue(forKey: key, error: &error) == .failed {
          fail(RaftVideoFrame.code(of: error), "The video could not be read.")
          return
        }
      }
      guard let track = asset.tracks(withMediaType: .video).first else {
        fail("failed", "No video track.")
        return
      }
      let natural = track.naturalSize.applying(track.preferredTransform)
      let width = Int(abs(natural.width).rounded()), height = Int(abs(natural.height).rounded())
      guard width > 0, height > 0 else { fail("failed", "No video size."); return }
      let t = track.preferredTransform
      var degrees = Int((atan2(Double(t.b), Double(t.a)) * 180 / .pi).rounded())
      degrees = ((degrees % 360) + 360) % 360
      let seconds = CMTimeGetSeconds(asset.duration)
      let durationMs = seconds.isFinite && seconds > 0 ? Int(seconds * 1000) : 0

      let generator = AVAssetImageGenerator(asset: asset)
      generator.appliesPreferredTrackTransform = true
      generator.maximumSize = CGSize(width: maxEdge, height: maxEdge)
      // The first sync sample is enough: no decode of anything before it.
      generator.requestedTimeToleranceBefore = .positiveInfinity
      generator.requestedTimeToleranceAfter = .positiveInfinity
      job.generator = generator
      if job.cancelled { fail("cancelled", "Cancelled."); return }
      generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: .zero)]) {
        _, image, _, status, failure in
        if job.cancelled || status == .cancelled { fail("cancelled", "Cancelled."); return }
        guard status == .succeeded, let image = image,
          let data = RaftVideoFrame.jpeg(image, quality: 0.8)
        else {
          fail(RaftVideoFrame.code(of: failure as NSError?), "No picture.")
          return
        }
        finish([
          "jpeg": FlutterStandardTypedData(bytes: data),
          "width": width,
          "height": height,
          "rotation": degrees,
          "durationMs": durationMs,
        ])
      }
    }
  }

  /// `expired` for a host that refused the signature (HTTP 401, 403, 410), else `failed`.
  private static func code(of error: NSError?) -> String {
    var current = error
    while let e = current {
      if e.domain == "CoreMediaErrorDomain" && (e.code == -12660 || e.code == -12661) { return "expired" }
      if e.domain == AVFoundationErrorDomain && e.code == AVError.contentIsNotAuthorized.rawValue {
        return "expired"
      }
      if e.domain == NSURLErrorDomain && e.code == NSURLErrorUserAuthenticationRequired { return "expired" }
      current = e.userInfo[NSUnderlyingErrorKey] as? NSError
    }
    return "failed"
  }

  private static func jpeg(_ image: CGImage, quality: Double) -> Data? {
    let data = NSMutableData()
    guard
      let destination = CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil)
    else { return nil }
    CGImageDestinationAddImage(
      destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
    return CGImageDestinationFinalize(destination) ? data as Data : nil
  }
}
