import Cocoa
import Darwin
import FlutterMacOS
@testable import RaftMacMultiwindowLifecycle

// Baseline compiles the same behavioral probes against the previous host.
// The old host has no quit-owner protocol; the spy still exposes the contract.
#if OLD_BASELINE
protocol RaftApplicationExitWindow: AnyObject {
  func requestApplicationExit(_ completion: @escaping (Bool) -> Void)
}
#endif

private final class ApplicationSpy: NSApplication {
  var replies: [Bool] = []
  var directTerminations = 0
  override func reply(toApplicationShouldTerminate shouldTerminate: Bool) {
    replies.append(shouldTerminate)
  }
  override func terminate(_ sender: Any?) { directTerminations += 1 }
}

private final class PrimaryWindow: NSWindow, RaftApplicationExitWindow {
  var requests = 0
  var pending: ((Bool) -> Void)?
  func requestApplicationExit(_ completion: @escaping (Bool) -> Void) {
    requests += 1
    pending = completion
  }
  func resolve(_ accepted: Bool) { pending?(accepted); pending = nil }
}

private final class CloseWindow: NSWindow {
  var closeRequests = 0
  override func performClose(_ sender: Any?) { closeRequests += 1 }
}

private final class Messenger: NSObject, FlutterBinaryMessenger {
  var calls: [String] = []
  var response: Any? = true
  func send(onChannel channel: String, message: Data?) {}
  func send(onChannel channel: String, message: Data?, binaryReply: FlutterBinaryReply?) {
    let codec = FlutterStandardMethodCodec.sharedInstance()
    if let message {
      calls.append(codec.decodeMethodCall(message).method)
    }
    binaryReply?(codec.encodeSuccessEnvelope(response))
  }
  func setMessageHandlerOnChannel(_ channel: String,
    binaryMessageHandler: FlutterBinaryMessageHandler?) -> FlutterBinaryMessengerConnection { 1 }
  func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) {}
}

private var failures: [String] = []
private func check(_ condition: @autoclosure () -> Bool, _ message: String) {
  if !condition() { failures.append(message) }
}
private func drain() { RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02)) }

setbuf(stdout, nil)
print("Contract: initialize prohibited AppKit application")
private let application = ApplicationSpy.shared as! ApplicationSpy
_ = application.setActivationPolicy(.prohibited)
let delegate = AppDelegate()
application.delegate = delegate
private let primary = PrimaryWindow(contentRect: .zero, styleMask: [], backing: .buffered, defer: true)
primary.isReleasedWhenClosed = false
delegate.mainFlutterWindow = primary
delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

// Real pinned engine initializers reproduce the process-wide handler takeover.
// No engine is run, no Dart assets are started, and no window is displayed.
print("Contract: initialize two real pinned Flutter engines")
autoreleasepool {
  let older = FlutterEngine(name: "raft-quit-contract-older", project: nil, allowHeadlessExecution: true)
  let newer = FlutterEngine(name: "raft-quit-contract-newer", project: nil, allowHeadlessExecution: true)
  print("Contract: query application quit with both child handlers installed")
  let reply = delegate.applicationShouldTerminate(application)
  check(reply == .terminateLater, "quit must wait for the primary coordinator after child creation")
  check(primary.requests == 1, "the primary exit observer chain must receive the quit request")
  check(application.directTerminations == 0, "a newly created child must not force process termination")
  check(delegate.applicationShouldTerminate(application) == .terminateLater,
    "a duplicate quit must join the pending primary request")
  check(primary.requests == 1, "duplicate quit must not run primary saving twice")
  primary.resolve(false)
  drain()
  check(application.replies == [false], "primary draft veto must reach AppKit")
  older.shutDownEngine()
  newer.shutDownEngine()
}

// The default FlutterAppDelegate weak handler is now gone. The primary must
// still own retry/save instead of falling through to immediate termination.
print("Contract: query quit after engine destruction")
check(delegate.applicationShouldTerminate(application) == .terminateLater,
  "quit after the latest child closes must still consult the primary")
check(primary.requests == 2, "a vetoed quit must be retryable through the primary")
primary.resolve(true)
drain()
check(application.replies == [false, true], "successful primary save must approve AppKit termination")
check(application.directTerminations == 0, "the default last-child terminator must not run")

print("Contract: primary close notification")
let window = MainFlutterWindow(contentRect: .zero, styleMask: [.titled, .closable],
  backing: .buffered, defer: true)
window.isReleasedWhenClosed = false
var closeNotifications = 0
let observer = NotificationCenter.default.addObserver(
  forName: NSWindow.willCloseNotification, object: window, queue: .main) { _ in
    closeNotifications += 1
  }
window.close()
check(closeNotifications == 0, "primary Close must not unregister the live engine through willClose")
check(!window.isVisible, "primary Close must leave its window hidden")
NotificationCenter.default.removeObserver(observer)

#if !OLD_BASELINE
print("Contract: child menu transport")
private let childWindow = CloseWindow(contentRect: .zero, styleMask: [], backing: .buffered, defer: true)
childWindow.isReleasedWhenClosed = false
private let messenger = Messenger()
let command = FlutterMethodChannel(name: "app.raft/window", binaryMessenger: messenger)
let child = RaftChildWindow(window: childWindow, commandChannel: command)
child.closeFromMenu()
check(messenger.calls == ["closeRequested"], "child File Close must ask the Dart preview/dialog policy")
check(childWindow.closeRequests == 0, "handled preview/dialog Close must not close the child window")
messenger.response = false
child.closeFromMenu()
check(childWindow.closeRequests == 1, "unhandled child menu Close must use ordinary native save/close")
#endif

for failure in failures { print("FAIL: \(failure)") }
print("Native multi-window lifecycle contract: \(failures.count) failed assertions")
exit(failures.isEmpty ? 0 : 1)
