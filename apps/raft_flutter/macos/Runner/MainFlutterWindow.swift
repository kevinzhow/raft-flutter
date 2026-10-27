import Cocoa
import FlutterMacOS
import desktop_drop
import CFNetwork
import AVFoundation
import ImageIO

class MainFlutterWindow: NSWindow, RaftPreferencesWindow, RaftPasteWindow, RaftUpdatesWindow {
  private var attachmentFilesChannel: AttachmentFilesChannel?
  private var interactionChannel: FlutterMethodChannel?
  private var memoryChannel: FlutterMethodChannel?
  fileprivate var titleBar: RaftTitleBar?
  private var proxyChannel: FlutterMethodChannel?
  private var windowChannel: FlutterMethodChannel?
  private var windowCommandsReady = false
  private(set) var canOpenPreferences = false
  private(set) var canPasteIntoFlutter = false
  private(set) var canCheckForUpdates = false
  private var videoFrameChannel: FlutterMethodChannel?
  private let videoFrame = RaftVideoFrame()
  private struct HeaderMouseSequence {
    let controller: FlutterViewController
    let down: NSEvent
    var lastEvent: NSEvent
  }
  private var headerMouseSequence: HeaderMouseSequence?
  private var headerDragHandedOff = false
  private var pendingHeaderMouseEvents: [NSEvent]?
  private var headerCancellationInFlight = false
  private var appKitMouseSequence = false

  // AppKit resets standard-button frames during layout. Align them after that
  // layout, before display; didUpdate arrives after a displaced frame can paint.
  override func layoutIfNeeded() {
    super.layoutIfNeeded()
    titleBar?.positionButtons()
  }

  override func displayIfNeeded() {
    layoutIfNeeded()
    super.displayIfNeeded()
  }

  override func display() {
    layoutIfNeeded()
    super.display()
  }

  override func sendEvent(_ event: NSEvent) {
    if event.window === self {
      if event.type == .leftMouseDown {
        appKitMouseSequence = titleBar?.isStandardButtonMouseDown(event) == true
          || mouseDownHitsNativeView(event)
      }
      if appKitMouseSequence,
        [.leftMouseDown, .leftMouseDragged, .leftMouseUp].contains(event.type) {
        // NSButton may synchronously track through mouseUp. Never queue its
        // down while retaining that release in a separate Flutter replay loop.
        if event.type == .leftMouseUp { appKitMouseSequence = false }
        super.sendEvent(event)
        return
      }
    }
    dispatchFlutterHeaderEvent(event)
  }

  private func dispatchFlutterHeaderEvent(_ event: NSEvent) {
    let primary = event.window === self
      && [.leftMouseDown, .leftMouseDragged, .leftMouseUp].contains(event.type)
    if primary, pendingHeaderMouseEvents != nil {
      pendingHeaderMouseEvents?.append(event)
      if event.type == .leftMouseDown { cancelPendingHeaderSequence() }
      return
    }
    if event.type == .leftMouseDown, event.window === self {
      if headerMouseSequence != nil {
        // A cancelled/interrupted native sequence can omit mouseUp. Cancel its
        // Dart recognizers before closing the engine's pressed state, then
        // replay the new Flutter input in order.
        pendingHeaderMouseEvents = [event]
        cancelPendingHeaderSequence()
        return
      }
      // performDrag may consume mouseUp. A fresh press starts a new sequence.
      headerDragHandedOff = false
    }
    if headerDragHandedOff, event.window === self {
      if event.type == .leftMouseUp {
        headerDragHandedOff = false
        return
      }
      if event.type == .leftMouseDragged { return }
    }
    if var sequence = headerMouseSequence, event.window === self {
      if event.type == .leftMouseUp {
        headerMouseSequence = nil
        sequence.controller.mouseUp(with: event)
        return
      }
      if event.type == .leftMouseDragged {
        sequence.lastEvent = event
        headerMouseSequence = sequence
        sequence.controller.mouseDragged(with: event)
        return
      }
    }
    guard titleBar?.ownsFlutterHeaderMouseDown(event) == true,
      let controller = contentViewController as? FlutterViewController,
      let content = contentView
    else {
      super.sendEvent(event)
      return
    }
    // The controller's public view is a wrapper. The registrar exposes the
    // actual rendering view, so embedded native controls keep AppKit dispatch.
    let registrar = controller.registrar(forPlugin: "RaftHeaderMouseDispatch")
    guard registrar.viewController === controller, let renderView = registrar.view else {
      super.sendEvent(event)
      return
    }
    let point = content.superview?.convert(event.locationInWindow, from: nil)
      ?? content.convert(event.locationInWindow, from: nil)
    guard DesktopDropPlugin.mouseEventTarget(in: content, at: point) === renderView else {
      super.sendEvent(event)
      return
    }
    if !isKeyWindow {
      guard renderView.acceptsFirstMouse(for: event) else {
        super.sendEvent(event)
        return
      }
      makeKeyAndOrderFront(nil)
    }
    // FlutterView declines this while TextInputPlugin owns the text responder.
    if renderView.acceptsFirstResponder, firstResponder !== renderView {
      _ = makeFirstResponder(renderView)
    }
    headerMouseSequence = HeaderMouseSequence(controller: controller, down: event, lastEvent: event)
    // NSWindow's titlebar recognizer acts on mouseUp independently of Dart's
    // gesture arena. Forward the complete client sequence exactly once, before
    // that native recognizer can acquire it; blank Flutter gestures explicitly
    // request window actions through the existing titlebar channel.
    controller.mouseDown(with: event)
  }

  private func mouseDownHitsNativeView(_ event: NSEvent) -> Bool {
    guard let controller = contentViewController as? FlutterViewController,
      let content = contentView,
      let renderView = controller.registrar(forPlugin: "RaftHeaderMouseDispatch").view
    else { return false }
    let point = content.superview?.convert(event.locationInWindow, from: nil)
      ?? content.convert(event.locationInWindow, from: nil)
    guard let hit = DesktopDropPlugin.mouseEventTarget(in: content, at: point) else { return false }
    return hit !== renderView
  }

  private func cancelPendingHeaderSequence() {
    guard !headerCancellationInFlight, let previous = headerMouseSequence,
      pendingHeaderMouseEvents != nil, let titleBar else { return }
    headerCancellationInFlight = true
    titleBar.cancelHeaderPointer(downTimestampMicros: Self.micros(previous.down)) {
      [weak self] cancelled in
      guard let self else { return }
      self.headerCancellationInFlight = false
      // Without a cancellation acknowledgement, an invented up could tap the
      // old control. Keep Flutter's queue until a later press retries the same
      // cancellation. Native buttons remain on their own AppKit path.
      guard cancelled, let up = self.closingUp(for: previous) else { return }
      let events = self.pendingHeaderMouseEvents ?? []
      self.pendingHeaderMouseEvents = nil
      self.headerMouseSequence = nil
      previous.controller.mouseUp(with: up)
      for queued in events { self.dispatchFlutterHeaderEvent(queued) }
    }
  }

  private static func micros(_ event: NSEvent) -> Int64 {
    Int64(event.timestamp * 1_000_000)
  }

  private func closingUp(for sequence: HeaderMouseSequence) -> NSEvent? {
    let source = sequence.lastEvent
    // Keep the original event clock: input already queued behind a platform
    // message must not acquire a timestamp older than this closing packet.
    return NSEvent.mouseEvent(with: .leftMouseUp,
      location: source.locationInWindow, modifierFlags: source.modifierFlags,
      timestamp: source.timestamp, windowNumber: windowNumber, context: nil,
      eventNumber: 0, clickCount: 1, pressure: 0)
  }

  fileprivate func prepareForHeaderWindowDrag(downTimestampMicros: Int64?) -> Bool {
    guard let sequence = headerMouseSequence else { return true }
    guard pendingHeaderMouseEvents == nil,
      downTimestampMicros == Self.micros(sequence.down),
      sequence.lastEvent.type == .leftMouseDragged,
      let up = closingUp(for: sequence)
    else { return false }
    headerMouseSequence = nil
    headerDragHandedOff = true
    // A recognized blank pan is handing input to WindowServer. performDrag
    // returns immediately and may eat mouseUp, so close Flutter's pressed state
    // now and keep the remaining native drag events out of Flutter.
    sequence.controller.mouseUp(with: up)
    return true
  }

  static func isRepeatedCloseKey(_ event: NSEvent?) -> Bool {
    // AppKit can dispatch a menu action after Flutter's asynchronous key reply;
    // currentEvent may then be a mouse or application event. Its isARepeat
    // getter raises an Objective-C exception unless it is a keyboard event.
    guard let event, event.type == .keyDown else { return false }
    return event.isARepeat
  }

  override func performClose(_ sender: Any?) {
    if Self.isRepeatedCloseKey(NSApp.currentEvent) { return }
    // Menu actions share Flutter's close policy with the keyboard fallback.
    // Route a menu Close through previews before closing the native window.
    guard sender is NSMenuItem, windowCommandsReady, let channel = windowChannel else {
      super.performClose(sender)
      return
    }
    channel.invokeMethod("closeRequested", arguments: nil) { [weak self] response in
      if (response as? Bool) != true { self?.closeWindowFromCommand() }
    }
  }

  private func closeWindowFromCommand() {
    super.performClose(nil)
  }

  func checkForUpdates() {
    guard windowCommandsReady && canCheckForUpdates else { return }
    windowChannel?.invokeMethod("checkForUpdatesRequested", arguments: nil)
  }

  func pasteFromMenu() {
    guard windowCommandsReady, canPasteIntoFlutter else { return }
    // Native menu/synthetic Cmd+V must reach the Dart editor, rather than
    // changing only Flutter's hidden AppKit accessibility field editor.
    windowChannel?.invokeMethod("pasteRequested", arguments: nil)
  }

  func openPreferences() {
    windowChannel?.invokeMethod("openPreferences", arguments: nil)
  }

  override func awakeFromNib() {
    // Do not restore an old fullscreen/Space state during background launch.
    isRestorable = false
    let flutterViewController = FlutterViewController()
    // The window is ordered in before Flutter's first frame (AppDelegate), and
    // until then FlutterView paints black. Use the stored theme's canvas colour
    // for both so a dark theme does not flash white (or a light one black).
    let canvas = MainFlutterWindow.storedCanvasColor()
    self.backgroundColor = canvas
    flutterViewController.backgroundColor = canvas
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    attachmentFilesChannel = AttachmentFilesChannel(
      messenger: flutterViewController.engine.binaryMessenger)

    memoryChannel = FlutterMethodChannel(
      name: "app.raft/device-memory", binaryMessenger: flutterViewController.engine.binaryMessenger)
    memoryChannel?.setMethodCallHandler { call, result in
      if call.method == "snapshot" {
        result(["totalBytes": Int64(ProcessInfo.processInfo.physicalMemory)])
      } else if call.method == "availableStorageBytes",
        let args = call.arguments as? [String: Any], let path = args["path"] as? String {
        do {
          let values = try FileManager.default.attributesOfFileSystem(forPath: path)
          result((values[.systemFreeSize] as? NSNumber)?.int64Value)
        } catch {
          result(FlutterError(code: "storage_unavailable", message: "Available storage could not be read.", details: nil))
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    interactionChannel = FlutterMethodChannel(
      name: "app.raft/interaction",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    interactionChannel?.setMethodCallHandler { call, result in
      if call.method == "doubleClickInterval" {
        result(NSEvent.doubleClickInterval)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    // A desktop sign-in finishes in the browser; the app raises its own window
    // when the browser hands the result back.
    windowChannel = FlutterMethodChannel(
      name: "app.raft/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    windowChannel?.setMethodCallHandler { [weak self] call, result in
      if call.method == "isActive" {
        result(NSApp.isActive)
      } else if call.method == "setWindowCommandsState" {
        let state = call.arguments as? [String: Any]
        self?.windowCommandsReady = state?["ready"] as? Bool == true
        self?.canCheckForUpdates = self?.windowCommandsReady == true
          && state?["updates"] as? Bool == true
        self?.canPasteIntoFlutter = self?.windowCommandsReady == true
          && state?["paste"] as? Bool == true
        self?.canOpenPreferences = self?.windowCommandsReady == true
          && state?["preferences"] as? Bool == true
        result(nil)
      } else if call.method == "closeWindow" {
        self?.closeWindowFromCommand()
        result(nil)
      } else if call.method == "present" {
        if let window = self {
          if window.isMiniaturized { window.deminiaturize(nil) }
          NSApp.activate(ignoringOtherApps: true)
          window.makeKeyAndOrderFront(nil)
        }
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    proxyChannel = FlutterMethodChannel(
      name: "app.raft/system-proxy",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    proxyChannel?.setMethodCallHandler { call, result in
      switch call.method {
      case "snapshot":
        result(RaftSystemProxy.snapshot())
      case "resolve":
        guard let url = (call.arguments as? [String: Any])?["url"] as? String else {
          result(FlutterError(code: "invalid", message: "Missing URL.", details: nil))
          return
        }
        RaftSystemProxy.resolve(url) { result($0) }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // First picture and shape of a video behind an http(s) URL (AVFoundation).
    videoFrameChannel = FlutterMethodChannel(
      name: "app.raft/video-frame",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    videoFrameChannel?.setMethodCallHandler { [videoFrame] call, result in
      videoFrame.handle(call, result)
    }

    // The app draws the title strip (rail colours, no text) under the
    // transparent system title bar; see docs/desktop-title-bar.md.
    titleBar = RaftTitleBar(
      window: self, messenger: flutterViewController.engine.binaryMessenger)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  /// `layer-canvas` of the stored appearance. shared_preferences keeps
  /// `raft.mode` / `raft.light` in NSUserDefaults under the `flutter.` prefix.
  /// Dark is always Elegant dark (#141411); every light family's canvas is white.
  private static func storedCanvasColor() -> NSColor {
    let mode = UserDefaults.standard.string(forKey: "flutter.raft.mode") ?? "system"
    var dark = mode == "dark"
    if mode == "system" {
      let match = NSApplication.shared.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
      dark = match == .darkAqua
    }
    return dark
      ? NSColor(srgbRed: 20.0 / 255.0, green: 20.0 / 255.0, blue: 17.0 / 255.0, alpha: 1)
      : NSColor.white
  }
}

/// The window's title bar on macOS: transparent, over a full-size content
/// view, with the traffic lights left at the top-left where the system puts
/// them. Flutter paints the strip below them (`RaftDesktopTitleBar`), so this
/// reports how tall the system's bar is, whether the window is fullscreen
/// (the system hides the bar then), and does the two things a click on the
/// strip would have done in a native bar: move the window and zoom it.
final class RaftTitleBar: NSObject {
  private weak var window: NSWindow?
  private let channel: FlutterMethodChannel
  private var observers: [NSObjectProtocol] = []
  private var integratedHeight: CGFloat?
  private var previousToolbar: NSToolbar?
  private var previousToolbarStyle: Int?
  private var previousButtonFrames: [NSWindow.ButtonType: NSRect] = [:]
  private var positioningButtons = false
  private struct PointerGesture {
    let down: NSEvent
    let frame: NSRect
    let start: NSPoint
    var end: NSPoint?
    var consumed = false
  }
  private var pointerGesture: PointerGesture?
  private var pointerMonitor: Any?
  private static let buttons: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]

  init(window: NSWindow, messenger: FlutterBinaryMessenger) {
    self.window = window
    channel = FlutterMethodChannel(name: "app.raft/titlebar", binaryMessenger: messenger)
    super.init()
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.styleMask.insert(.fullSizeContentView)
    // Match the reference desktop frame before Flutter's first frame, including
    // sign-in, workspace selection and narrow layouts.
    (window as? MainFlutterWindow)?.titleBar = self
    setIntegrated(true, height: 48)
    pointerMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) {
      [weak self] event in
      self?.recordPointer(event)
      return event
    }
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.handle(call, result)
    }
    let names: [NSNotification.Name] = [
      NSWindow.didResizeNotification,
      NSWindow.willEnterFullScreenNotification,
      NSWindow.didEnterFullScreenNotification,
      NSWindow.willExitFullScreenNotification,
      NSWindow.didExitFullScreenNotification,
      NSWindow.didUpdateNotification,
    ]
    for name in names {
      observers.append(
        NotificationCenter.default.addObserver(
          forName: name, object: window, queue: .main
        ) { [weak self] _ in
          if name == NSWindow.willEnterFullScreenNotification
            || name == NSWindow.didEnterFullScreenNotification {
            self?.setIntegratedToolbarVisible(false)
          } else if name == NSWindow.didExitFullScreenNotification {
            self?.setIntegratedToolbarVisible(true)
          }
          if name == NSWindow.didUpdateNotification {
            self?.positionButtons()
          } else {
            self?.publish()
          }
        })
    }
  }

  deinit {
    for observer in observers { NotificationCenter.default.removeObserver(observer) }
    if let pointerMonitor { NSEvent.removeMonitor(pointerMonitor) }
  }

  /// The system title bar's height: what the content view has above the
  /// layout rect. Zero in fullscreen, where the bar is not part of the window.
  private var state: [String: Any] {
    guard let window = window, let content = window.contentView else {
      return ["height": 0, "fullscreen": false, "integrated": false, "leadingInset": 0]
    }
    positionButtons()
    let fullscreen = window.styleMask.contains(.fullScreen)
    let height = content.frame.height - window.contentLayoutRect.height
    let trailingEdge = Self.buttons.compactMap { type -> CGFloat? in
      guard let button = window.standardWindowButton(type) else { return nil }
      return button.convert(button.bounds, to: content).maxX
    }.max() ?? 0
    return [
      "height": fullscreen || !height.isFinite || height < 0 ? 0 : Double(height),
      "fullscreen": fullscreen,
      "integrated": integratedHeight != nil,
      "leadingInset": integratedHeight != nil && !fullscreen ? Double(trailingEdge + 4) : 0,
    ]
  }

  /// Keep AppKit's real controls, targets and accessibility, while Flutter owns
  /// the rest of the global row. The empty transparent toolbar gives the native
  /// button view enough height; it does not consume Flutter pointer events.
  private func setIntegrated(_ enabled: Bool, height: CGFloat) {
    guard let window else { return }
    if enabled {
      if integratedHeight == nil {
        previousToolbar = window.toolbar
        for type in Self.buttons {
          previousButtonFrames[type] = window.standardWindowButton(type)?.frame
        }
        if #available(macOS 11.0, *) {
          previousToolbarStyle = window.toolbarStyle.rawValue
          window.toolbarStyle = .unifiedCompact
        }
        let toolbar = NSToolbar(identifier: "app.raft.integrated-titlebar")
        toolbar.allowsUserCustomization = false
        window.toolbar = toolbar
      }
      integratedHeight = height
      window.layoutIfNeeded()
      setIntegratedToolbarVisible(!window.styleMask.contains(.fullScreen))
      positionButtons()
    } else if integratedHeight != nil {
      integratedHeight = nil
      window.toolbar = previousToolbar
      previousToolbar = nil
      if #available(macOS 11.0, *), let raw = previousToolbarStyle,
        let style = NSWindow.ToolbarStyle(rawValue: raw) {
        window.toolbarStyle = style
      }
      previousToolbarStyle = nil
      window.contentView?.layoutSubtreeIfNeeded()
      for (type, frame) in previousButtonFrames {
        window.standardWindowButton(type)?.setFrameOrigin(frame.origin)
      }
      previousButtonFrames.removeAll()
    }
  }

  private func setIntegratedToolbarVisible(_ visible: Bool) {
    guard integratedHeight != nil, let toolbar = window?.toolbar,
      toolbar.isVisible != visible else { return }
    // This empty toolbar only sizes windowed controls. AppKit otherwise floats
    // it over the Flutter-owned row in fullscreen, even with a transparent bar.
    toolbar.isVisible = visible
  }

  fileprivate func positionButtons() {
    guard !positioningButtons, let window, let content = window.contentView,
      let height = integratedHeight, !window.styleMask.contains(.fullScreen),
      let close = window.standardWindowButton(.closeButton), let parent = close.superview
    else { return }
    positioningButtons = true
    defer { positioningButtons = false }
    let start = close.convert(close.bounds, to: content).minX
    let offsets = Self.buttons.compactMap { type -> (NSButton, CGFloat)? in
      guard let button = window.standardWindowButton(type), button.superview === parent else { return nil }
      return (button, button.convert(button.bounds, to: content).minX - start)
    }
    for (button, offset) in offsets {
      // The native view remains the clipping boundary. A very tall custom row
      // keeps the controls reachable instead of moving them outside that view.
      let desired = parent.convert(NSPoint(x: 16 + offset,
        y: content.bounds.maxY - height / 2), from: content)
      let half = button.frame.height / 2
      let center = min(max(desired.y, parent.bounds.minY + half), parent.bounds.maxY - half)
      let origin = NSPoint(x: desired.x, y: center - half)
      if abs(button.frame.minX - origin.x) > 0.01 || abs(button.frame.minY - origin.y) > 0.01 {
        button.setFrameOrigin(origin)
      }
    }
  }

  private func recordPointer(_ event: NSEvent) {
    guard let window, event.window === window else { return }
    if event.type == .leftMouseDown {
      pointerGesture = PointerGesture(down: event, frame: window.frame,
        start: window.convertPoint(toScreen: event.locationInWindow))
    } else if event.type == .leftMouseUp, pointerGesture?.consumed == false {
      pointerGesture?.end = window.convertPoint(toScreen: event.locationInWindow)
    }
  }

  fileprivate func ownsFlutterHeaderMouseDown(_ event: NSEvent) -> Bool {
    guard event.type == .leftMouseDown, let window, event.window === window,
      let height = integratedHeight, !window.styleMask.contains(.fullScreen),
      let content = window.contentView
    else { return false }
    let point = content.convert(event.locationInWindow, from: nil)
    guard content.bounds.contains(point) else { return false }
    let fromTop = content.isFlipped
      ? point.y - content.bounds.minY : content.bounds.maxY - point.y
    guard fromTop >= 0, fromTop < height else { return false }
    return !isStandardButtonMouseDown(event)
  }

  fileprivate func isStandardButtonMouseDown(_ event: NSEvent) -> Bool {
    guard event.type == .leftMouseDown, let window, event.window === window,
      let content = window.contentView else { return false }
    let point = content.convert(event.locationInWindow, from: nil)
    return Self.buttons.contains { type in
      guard let button = window.standardWindowButton(type), !button.isHidden else { return false }
      return button.convert(button.bounds, to: content).contains(point)
    }
  }

  fileprivate func cancelHeaderPointer(downTimestampMicros: Int64,
    completion: @escaping (Bool) -> Void) {
    channel.invokeMethod("cancelHeaderPointer",
      arguments: ["downTimestampMicros": downTimestampMicros]) { response in
      completion((response as? Bool) == true)
    }
  }

  private func startDragging(downTimestampMicros: Int64?) {
    guard let window, !window.styleMask.contains(.fullScreen) else { return }
    if var gesture = pointerGesture {
      if let stamp = downTimestampMicros {
        guard stamp == Int64(gesture.down.timestamp * 1_000_000) else { return }
      }
      guard !gesture.consumed else { return }
      gesture.consumed = true
      pointerGesture = gesture
      // AppKit may already have moved or zoomed the window while Dart was
      // recognizing this gesture. Do not replay it over that newer frame.
      guard window.frame == gesture.frame else { return }
      if let end = gesture.end {
        // A quick pointer sequence may finish before Dart's platform message.
        // Preserve that user's movement without starting a second mouse loop.
        window.setFrameOrigin(NSPoint(x: gesture.frame.origin.x + end.x - gesture.start.x,
          y: gesture.frame.origin.y + end.y - gesture.start.y))
      } else {
        guard (window as? MainFlutterWindow)?.prepareForHeaderWindowDrag(
          downTimestampMicros: downTimestampMicros) != false else { return }
        window.performDrag(with: gesture.down)
      }
    } else if let event = NSApp.currentEvent,
      event.type == .leftMouseDown || event.type == .leftMouseDragged {
      guard (window as? MainFlutterWindow)?.prepareForHeaderWindowDrag(
        downTimestampMicros: downTimestampMicros) != false else { return }
      window.performDrag(with: event)
    }
  }

  private func publish() {
    channel.invokeMethod("state", arguments: state)
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    switch call.method {
    case "status":
      result(state)
    case "setIntegrated":
      guard let args = call.arguments as? [String: Any], let enabled = args["enabled"] as? Bool,
        let number = args["height"] as? NSNumber, number.doubleValue.isFinite, number.doubleValue > 0
      else {
        result(FlutterError(code: "invalid", message: "A finite positive header height is required.", details: nil))
        return
      }
      setIntegrated(enabled, height: CGFloat(number.doubleValue))
      result(state)
    case "setStyle":
      // Behind the transparent bar and under the Flutter view: what shows
      // while the window resizes, in the strip's own colour.
      if let args = call.arguments as? [String: Any],
        let argb = args["background"] as? Int
      {
        window?.backgroundColor = NSColor(
          srgbRed: CGFloat((argb >> 16) & 0xFF) / 255,
          green: CGFloat((argb >> 8) & 0xFF) / 255,
          blue: CGFloat(argb & 0xFF) / 255,
          alpha: 1)
        window?.appearance = NSAppearance(named: args["dark"] as? Bool == true ? .darkAqua : .aqua)
      }
      result(nil)
    case "setTitle":
      // The window's name for Mission Control, the Window menu and the Dock;
      // titleVisibility stays hidden, so the strip shows no text.
      if let args = call.arguments as? [String: Any], let title = args["title"] as? String {
        window?.title = title
      }
      result(nil)
    case "startDragging":
      let args = call.arguments as? [String: Any]
      let stamp = (args?["downTimestampMicros"] as? NSNumber)?.int64Value
      startDragging(downTimestampMicros: stamp)
      result(nil)
    case "doubleClick":
      // The user's System Settings choice for a title bar double-click.
      // "Fill" (macOS 15+) fills the screen's usable area and a second
      // double-click restores; older systems only have the Minimize bool.
      let defaults = UserDefaults.standard
      let action = defaults.string(forKey: "AppleActionOnDoubleClick")
        ?? (defaults.bool(forKey: "AppleMiniaturizeOnDoubleClick") ? "Minimize" : "Maximize")
      switch action {
      case "Minimize": window?.miniaturize(nil)
      case "None": break
      case "Fill": fill()
      default: window?.zoom(nil)
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private var frameBeforeFill: NSRect?

  private func fill() {
    guard let window, let visible = window.screen?.visibleFrame else { return }
    if window.frame == visible, let previous = frameBeforeFill {
      frameBeforeFill = nil
      window.setFrame(previous, display: true, animate: true)
    } else {
      frameBeforeFill = window.frame
      window.setFrame(visible, display: true, animate: true)
    }
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
