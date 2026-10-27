import Cocoa
import FlutterMacOS
import desktop_drop
@testable import RaftMacTitleBar

// Only the channel transport is recorded. The production handler runs against
// real AppKit windows and real standard window buttons.
private final class Messenger: NSObject, FlutterBinaryMessenger {
  var handler: FlutterBinaryMessageHandler?
  func send(onChannel channel: String, message: Data?) {}
  func send(onChannel channel: String, message: Data?, binaryReply: FlutterBinaryReply?) {}
  func setMessageHandlerOnChannel(_ channel: String, binaryMessageHandler: FlutterBinaryMessageHandler?) -> FlutterBinaryMessengerConnection {
    handler = binaryMessageHandler
    return 1
  }
  func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) { handler = nil }
  func invoke(_ method: String, _ args: [String: Any] = [:]) -> Any? {
    let codec = FlutterStandardMethodCodec.sharedInstance()
    var reply: Any?
    handler?(codec.encode(FlutterMethodCall(methodName: method, arguments: args))) {
      if let data = $0 { reply = codec.decodeEnvelope(data) }
    }
    return reply
  }
}

private var failures: [String] = []
private func check(_ value: @autoclosure () -> Bool, _ text: String) {
  if !value() { failures.append(text) }
}
private func closeRect(_ window: NSWindow) -> NSRect {
  let button = window.standardWindowButton(.closeButton)!
  return button.convert(button.bounds, to: window.contentView)
}

// A real engine, Flutter view, wrapper and registrar are constructed by the
// pinned framework. Only the controller's Dart startup and final mouse receiver
// are replaced: this tests MainFlutterWindow.sendEvent, not Dart recognition or
// a synthetic NSView whose mouseDownCanMoveWindow differs from Flutter's view.
private final class RecordingFlutterViewController: FlutterViewController {
  var received: [NSEvent] = []
  override func viewWillAppear() {}
  override func mouseDown(with event: NSEvent) { received.append(event) }
  override func mouseUp(with event: NSEvent) { received.append(event) }
  override func mouseDragged(with event: NSEvent) { received.append(event) }
}

private func pointFromTop(_ view: NSView, x: CGFloat, top: CGFloat) -> NSPoint {
  let y = view.isFlipped ? view.bounds.minY + top : view.bounds.maxY - top
  return view.convert(NSPoint(x: view.bounds.minX + x, y: y), to: nil)
}

private func inputSequence(_ window: NSWindow,
  _ items: [(NSEvent.EventType, NSPoint, Int)], offset: TimeInterval) -> [NSEvent] {
  let stamp = ProcessInfo.processInfo.systemUptime + offset
  return items.enumerated().map { index, item in
    NSEvent.mouseEvent(with: item.0, location: item.1, modifierFlags: [],
      timestamp: stamp + Double(index) * 0.075, windowNumber: window.windowNumber,
      context: nil, eventNumber: index + 20, clickCount: item.2,
      pressure: item.0 == .leftMouseUp ? 0 : 1)!
  }
}

private func describeInput(_ label: String, _ controller: RecordingFlutterViewController,
  expected: [NSEvent], before: NSRect, after: NSRect) {
  let rows = controller.received.map { event -> [String: Any] in
    ["type": event.type.rawValue,
      "clickCount": event.type == .leftMouseDragged ? 0 : event.clickCount,
      "x": event.locationInWindow.x, "y": event.locationInWindow.y]
  }
  let data: [String: Any] = ["target": label, "expectedEvents": expected.count,
    "received": rows, "frameBefore": NSStringFromRect(before),
    "frameAfter": NSStringFromRect(after)]
  print("Native header input:", String(data: try! JSONSerialization.data(withJSONObject: data), encoding: .utf8)!)
}

private func checkSameEvents(_ actual: [NSEvent], _ expected: [NSEvent], _ label: String) {
  check(actual.count == expected.count && zip(actual, expected).allSatisfy { $0.0 === $0.1 },
    "\(label) must deliver every original down/up/drag to the same Flutter controller; actual \(actual.map { $0.type.rawValue })")
}

private func exerciseFlutterHeaderInput() {
  let input = MainFlutterWindow(contentRect: NSRect(x: 40, y: 40, width: 900, height: 600),
    styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
  input.isReleasedWhenClosed = false
  input.title = "Raft native header input test"
  // Initialize the production private titlebar before replacing the initial
  // controller. Its view is never shown, so it does not start a Dart isolate.
  input.awakeFromNib()
  let initial = input.contentViewController as? FlutterViewController
  let recorder = RecordingFlutterViewController()
  input.contentViewController = recorder
  DesktopDropPlugin.register(with: recorder.registrar(forPlugin: "DesktopDropPlugin"))
  defer {
    input.orderOut(nil)
    input.contentViewController = nil
    input.close()
    recorder.engine.shutDownEngine()
    initial?.engine.shutDownEngine()
    _ = NSApp.setActivationPolicy(.prohibited)
  }
  let registrar = recorder.registrar(forPlugin: "NativeHeaderInputFixture")
  guard let renderView = registrar.view else {
    check(false, "fixture must expose the pinned engine's real registrar.view")
    return
  }
  check(recorder.engine.viewController === recorder,
    "fixture must retain its actual Flutter engine/controller association")
  check(renderView !== recorder.view && renderView.isDescendant(of: recorder.view),
    "fixture must use the real render view inside Flutter's wrapper")
  NSApp.finishLaunching()
  input.orderBack(nil)
  RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
  // Assigning a fresh controller adopts its initial 1x1 wrapper size. Restore
  // the test viewport after installation, before deriving any input locations.
  input.setFrame(NSRect(x: 40, y: 40, width: 900, height: 600), display: false)
  input.layoutIfNeeded()
  input.contentView?.layoutSubtreeIfNeeded()
  guard input.isVisible &&
    renderView.bounds.width >= 800 && renderView.bounds.height >= 500 else {
    check(false, "fixture must be laid out in a real window before input; frame \(input.frame), render \(renderView.bounds)")
    return
  }
  print("Native header fixture:", NSStringFromClass(type(of: renderView)),
    "wrapper:", NSStringFromClass(type(of: recorder.view)),
    "active:", NSApp.isActive, "key:", input.isKeyWindow)
  let baseline = input.frame

  let content: NSView = recorder.view
  let dropViews = content.subviews.filter { $0.registeredDraggedTypes.contains(.fileURL) }
  guard dropViews.count == 1, let overlay = dropViews.first else {
    check(false, "the real desktop_drop registration must install exactly one file-drop overlay")
    return
  }
  check(NSStringFromClass(type(of: overlay)) == "desktop_drop.DropTarget",
    "the fixture must load the actual plugin DropTarget, not a substitute NSView")
  let originalChildren = content.subviews.map { ObjectIdentifier($0) }
  let registeredTypes = Set(overlay.registeredDraggedTypes)
  var expectedTypes = Set(NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) })
  expectedTypes.insert(.fileURL)
  expectedTypes.insert(NSPasteboard.PasteboardType("NSFilenamesPboardType"))
  check(registeredTypes.isSuperset(of: expectedTypes),
    "the overlay must retain file URL, legacy filename and file-promise registrations")
  check(overlay.superview === content && overlay.frame == content.bounds
    && overlay.autoresizingMask.contains(.width) && overlay.autoresizingMask.contains(.height),
    "the drop overlay must remain full-size and resize with the Flutter wrapper")
  let overlayPoint = content.superview?.convert(
    pointFromTop(renderView, x: 140, top: 24), from: nil)
    ?? content.convert(pointFromTop(renderView, x: 140, top: 24), from: nil)
  check(content.hitTest(overlayPoint) === overlay,
    "ordinary AppKit hit testing must still select the registered drop overlay")
  check(DesktopDropPlugin.mouseEventTarget(in: content, at: overlayPoint) === renderView,
    "ordinary mouse routing must resolve through the overlay to the actual Flutter render view")
  do {
    let buttonPoint = pointFromTop(renderView, x: 260, top: 24)
    let center = content.convert(buttonPoint, from: nil)
    let button = NSButton(frame: NSRect(x: center.x - 32, y: center.y - 12, width: 64, height: 24))
    button.title = "Native"
    content.addSubview(button, positioned: .below, relativeTo: overlay)
    defer { button.removeFromSuperview() }
    let childrenWithButton = content.subviews.map { ObjectIdentifier($0) }
    let hitPoint = content.superview?.convert(buttonPoint, from: nil)
      ?? content.convert(buttonPoint, from: nil)
    check(content.hitTest(hitPoint) === overlay,
      "the lower native button must remain covered by the ordinary drop-overlay hit")
    check(DesktopDropPlugin.mouseEventTarget(in: content, at: hitPoint) === button,
      "overlay resolution must preserve the lower NSButton's native ownership instead of choosing Flutter")
    // Resolving a target does not prove a covered native control receives its
    // action through AppKit. This contract checks classification and structure.
    check(content.subviews.map { ObjectIdentifier($0) } == childrenWithButton,
      "resolving a lower native target must not reorder or remove views")
  }
  check(content.subviews.map { ObjectIdentifier($0) } == originalChildren
    && overlay.superview === content && Set(overlay.registeredDraggedTypes) == registeredTypes,
    "mouse target resolution must preserve the drop destination and original view hierarchy")
  print("Native drop overlay:", NSStringFromClass(type(of: overlay)),
    "resolved render:", NSStringFromClass(type(of: renderView)),
    "registered types:", registeredTypes.count, "lower NSButton ownership checked")

  // This fixture stays inactive/non-key. The real DropTarget declines first
  // mouse, so ordinary body input must retain AppKit's negative behavior rather
  // than being force-forwarded through the special header path.
  guard !NSApp.isActive && !input.isKeyWindow else {
    check(false, "background body fixture must be inactive/non-key; active \(NSApp.isActive), key \(input.isKeyWindow)")
    return
  }
  let body = pointFromTop(renderView, x: 450, top: 240)
  let bodyEvents = inputSequence(input, [(.leftMouseDown, body, 1),
    (.leftMouseUp, body, 1), (.leftMouseDown, body, 2), (.leftMouseUp, body, 2)], offset: 0)
  // Route through NSApplication so the production sendEvent runs with AppKit's
  // currentEvent context. These synthesized packets test routing only; this
  // background fixture does not reproduce the active app's native zoom.
  check(!overlay.acceptsFirstMouse(for: bodyEvents[0]),
    "the actual drop overlay must decline first mouse in this background body fixture")
  for event in bodyEvents { NSApp.sendEvent(event) }
  check(recorder.received.isEmpty,
    "inactive body input must keep AppKit dispatch and must not be force-forwarded to Flutter")
  check(input.frame == baseline, "inactive body input must not resize the native window")
  print("Native inactive body negative: sent", bodyEvents.count, "mouse events; active app body input is not exercised")
  describeInput("inactive body AppKit negative", recorder,
    expected: [], before: baseline, after: input.frame)

  input.setFrame(baseline, display: false)
  recorder.received.removeAll()
  let header = pointFromTop(renderView, x: 140, top: 24)
  let headerEvents = inputSequence(input, [(.leftMouseDown, header, 1),
    (.leftMouseUp, header, 1), (.leftMouseDown, header, 2), (.leftMouseUp, header, 2)], offset: 1)
  for event in headerEvents { NSApp.sendEvent(event) }
  checkSameEvents(recorder.received, headerEvents, "integrated header double-click")
  check(input.frame == baseline,
    "an integrated Flutter control's complete double-click must leave the native frame unchanged")
  describeInput("integrated header double-click", recorder,
    expected: headerEvents, before: baseline, after: input.frame)

  // Releases and drags remain part of the press that began in Flutter's header,
  // even after the pointer crosses into the body. Reclassifying each event by
  // its current Y would drop the tail of a gesture.
  input.setFrame(baseline, display: false)
  recorder.received.removeAll()
  let outsideHeader = pointFromTop(renderView, x: 180, top: 120)
  let crossEvents = inputSequence(input, [(.leftMouseDown, header, 1),
    (.leftMouseDragged, outsideHeader, 1), (.leftMouseUp, outsideHeader, 1)], offset: 2)
  for event in crossEvents { NSApp.sendEvent(event) }
  checkSameEvents(recorder.received, crossEvents, "header press leaving header")
  check(input.frame == baseline, "Flutter header input must not start an unrelated native drag")
  describeInput("header press leaving header", recorder,
    expected: crossEvents, before: baseline, after: input.frame)
}

_ = NSApplication.shared.setActivationPolicy(.prohibited)
let window = MainFlutterWindow(contentRect: NSRect(x: 100, y: 100, width: 1000, height: 700),
  styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
window.isReleasedWhenClosed = false
private let messenger = Messenger()
window.styleMask.insert(.fullSizeContentView)
let standardCenter = window.contentView!.bounds.height - closeRect(window).midY
let titlebar = RaftTitleBar(window: window, messenger: messenger)
let boot = messenger.invoke("status") as? [String: Any]
check(boot?["integrated"] as? Bool == true, "the native window must start with the 48pt frame before Dart or login is ready")
check(abs(closeRect(window).minX - 16) < 0.01, "the first native frame must already use the reference left inset")
check(abs(window.contentView!.bounds.height - closeRect(window).maxY - 17) < 0.01, "the first native frame must already use the reference top inset")

let integrated = messenger.invoke("setIntegrated", ["enabled": true, "height": 48]) as? [String: Any]
print("Native integrated geometry:", integrated ?? [:])
check(integrated?["integrated"] as? Bool == true, "the runner must accept the integrated header")
let zoom = window.standardWindowButton(.zoomButton)!
let expectedInset = Double(zoom.convert(zoom.bounds, to: window.contentView).maxX + 4)
check(integrated?["leadingInset"] as? Double == expectedInset, "the row must reserve the native controls plus their gutter")
let rect = closeRect(window)
check(abs(window.contentView!.bounds.height - rect.midY - 24) < 0.01, "traffic lights must centre on the 48pt row")
check(abs(rect.minX - 16) < 0.01, "traffic lights must keep the reference desktop shell's 16pt edge inset")
check(window.standardWindowButton(.closeButton)?.target != nil, "standard controls must retain native targets")

window.setContentSize(NSSize(width: 900, height: 600))
let resized = messenger.invoke("status") as? [String: Any]
check(abs(window.contentView!.bounds.height - closeRect(window).midY - 24) < 0.01, "resize must preserve traffic-light placement")
check(resized?["leadingInset"] as? Double == expectedInset, "resize must preserve the safe leading inset")

_ = messenger.invoke("setIntegrated", ["enabled": true, "height": 60])
check(abs(window.contentView!.bounds.height - closeRect(window).midY - 30) < 0.01, "a taller row must recenter the native controls")
let content = window.contentView!
for x in [100.0, 347.0, 500.0, 800.0] {
  let point = NSPoint(x: x, y: content.bounds.height - 24)
  check(content.superview?.hitTest(point) === content,
    "the transparent titlebar must leave Flutter controls clickable at x=\(x)")
}

let buttonParent = window.standardWindowButton(.closeButton)!.superview!
let parentOrigin = buttonParent.frame.origin
buttonParent.setFrameOrigin(NSPoint(x: parentOrigin.x, y: parentOrigin.y - 4))
_ = messenger.invoke("status")
check(abs(content.bounds.height - closeRect(window).midY - 30) < 0.01,
  "native container offsets must not move the controls off the shared row's centre")
buttonParent.setFrameOrigin(parentOrigin)

// AppKit can lay out native buttons while changing title/appearance, before
// didUpdate. Inspect those frames directly: status itself used to repair them
// and concealed a one-frame jump from (16,17) back to (12,13).
_ = messenger.invoke("setIntegrated", ["enabled": true, "height": 48])
let controlsBefore = [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].map {
  window.standardWindowButton($0)!.convert(window.standardWindowButton($0)!.bounds, to: content)
}
var transitionFrames: [[String: Any]] = []
for index in 0..<6 {
  window.title = "Page \(index)"
  window.appearance = NSAppearance(named: index % 2 == 0 ? .darkAqua : .aqua)
  content.superview?.needsLayout = true
  content.superview?.layoutSubtreeIfNeeded()
  window.layoutIfNeeded()
  for phase in ["layout", "display"] {
    if phase == "display" { window.displayIfNeeded() }
    let frame = closeRect(window)
    let top = content.bounds.height - frame.maxY
    transitionFrames.append(["page": index, "phase": phase, "left": frame.minX, "top": top])
    for (offset, type) in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].enumerated() {
      let button = window.standardWindowButton(type)!
      check(button.convert(button.bounds, to: content) == controlsBefore[offset],
        "page \(index) \(phase) control \(offset) must retain native frame \(controlsBefore[offset]); actual \(button.convert(button.bounds, to: content))")
      check(button.target != nil, "native controls must keep their AppKit actions")
    }
    check(abs(frame.minX - 16) < 0.01 && abs(top - 17) < 0.01,
      "page \(index) \(phase) must not expose a displaced native control frame: \(frame.minX),\(top)")
  }
  NSApp.updateWindows()
}
print("Native transition frames:", String(data: try! JSONSerialization.data(withJSONObject: transitionFrames), encoding: .utf8)!)

// A quick gesture can end before the asynchronous Dart channel reaches AppKit.
// Dispatch real AppKit events first, then request the drag as Dart would.
let beforeDrag = window.frame.origin
let stamp = ProcessInfo.processInfo.systemUptime
for (type, point, time) in [
  (NSEvent.EventType.leftMouseDown, NSPoint(x: 500, y: 300), stamp),
  (NSEvent.EventType.leftMouseUp, NSPoint(x: 620, y: 360), stamp + 0.01),
] {
  let event = NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
    timestamp: time, windowNumber: window.windowNumber, context: nil,
    eventNumber: 1, clickCount: 1, pressure: type == .leftMouseDown ? 1 : 0)!
  NSApp.sendEvent(event)
}
check(window.frame.origin == beforeDrag, "recording pointer input must not itself move the window")
_ = messenger.invoke("startDragging")
check(window.frame.origin == NSPoint(x: beforeDrag.x + 120, y: beforeDrag.y + 60),
  "a completed quick drag must still move the native window by its actual delta")
let afterDrag = window.frame.origin
_ = messenger.invoke("startDragging")
check(window.frame.origin == afterDrag, "one pointer gesture must move the window only once")
let otherWindow = NSWindow(contentRect: NSRect(x: 300, y: 100, width: 500, height: 400),
  styleMask: [.titled], backing: .buffered, defer: false)
for (type, point, time) in [
  (NSEvent.EventType.leftMouseDown, NSPoint(x: 100, y: 100), stamp + 0.02),
  (NSEvent.EventType.leftMouseUp, NSPoint(x: 250, y: 160), stamp + 0.03),
] {
  NSApp.sendEvent(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
    timestamp: time, windowNumber: otherWindow.windowNumber, context: nil,
    eventNumber: 2, clickCount: 1, pressure: 0)!)
}
_ = messenger.invoke("startDragging")
check(window.frame.origin == afterDrag, "another window's pointer input must not move this window")

for (type, point, time) in [
  (NSEvent.EventType.leftMouseDown, NSPoint(x: 500, y: 300), stamp + 0.04),
  (NSEvent.EventType.leftMouseUp, NSPoint(x: 620, y: 360), stamp + 0.05),
] {
  NSApp.sendEvent(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
    timestamp: time, windowNumber: window.windowNumber, context: nil,
    eventNumber: 3, clickCount: 1, pressure: 0)!)
}
var systemFrame = window.frame
systemFrame.origin.x += 30
systemFrame.size.width += 10
window.setFrame(systemFrame, display: false)
_ = messenger.invoke("startDragging")
check(window.frame == systemFrame,
  "a late drag must not overwrite a frame already changed by native window handling")

// The otherwise empty toolbar gives windowed traffic lights their height, but
// in fullscreen AppKit floats it over the Flutter-owned global row.
NotificationCenter.default.post(name: NSWindow.willEnterFullScreenNotification, object: window)
check(window.toolbar?.isVisible == false,
  "fullscreen must hide the empty native toolbar before it covers the shared row")
NotificationCenter.default.post(name: NSWindow.didEnterFullScreenNotification, object: window)
check(window.toolbar?.isVisible == false,
  "the empty native toolbar must remain hidden in fullscreen")
NotificationCenter.default.post(name: NSWindow.didExitFullScreenNotification, object: window)
check(window.toolbar?.isVisible == true,
  "exiting fullscreen must restore the windowed toolbar for native controls")

let restored = messenger.invoke("setIntegrated", ["enabled": false, "height": 48]) as? [String: Any]
check(restored?["integrated"] as? Bool == false, "leaving the workspace must restore the original titlebar")
check(restored?["leadingInset"] as? Double == 0, "the standalone strip must not reserve a second gutter")
check(window.toolbar == nil, "leaving the workspace must remove the integration toolbar")
check(abs(window.contentView!.bounds.height - closeRect(window).midY - standardCenter) < 0.01, "the original native button position must be restored")

exerciseFlutterHeaderInput()
window.orderOut(nil)
otherWindow.orderOut(nil)
otherWindow.close()
window.close()
for failure in failures { print("FAIL: \(failure)") }
print("Native integrated titlebar: 11 cases, \(failures.count) failed assertions")
withExtendedLifetime(titlebar) {}
exit(failures.isEmpty ? 0 : 1)
