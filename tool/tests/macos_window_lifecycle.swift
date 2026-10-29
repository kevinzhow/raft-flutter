import Cocoa
import FlutterMacOS
@testable import RaftMacAppDelegate

// No real window is shown: the tests exercise the production delegate, while
// recording the native window operations it requests.
private final class WindowSpy: NSWindow, RaftPreferencesWindow, RaftUpdatesWindow {
  var canOpenPreferences = false
  var canCheckForUpdates = false
  func checkForUpdates() { operations.append("updates") }
  func openPreferences() { operations.append("preferences") }
  var minimized = false
  var operations: [String] = []

  override var isMiniaturized: Bool { minimized }

  override func deminiaturize(_ sender: Any?) {
    operations.append("restore")
    minimized = false
  }

  override func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    operations.append("order")
  }

  override func makeKeyAndOrderFront(_ sender: Any?) {
    operations.append("show")
  }
}

private var failures: [String] = []
private func check(_ condition: @autoclosure () -> Bool, _ message: String) {
  if !condition() { failures.append(message) }
}

final class WindowLifecycleTests {
  func testClosingLastWindowKeepsAppRunning() {
    let delegate = AppDelegate()
    check(!delegate.applicationShouldTerminateAfterLastWindowClosed(.shared), "last-window close must keep the process running")
  }

  private func reopen(visible: Bool, minimized: Bool = false) {
    let delegate = AppDelegate()
    let window = WindowSpy(contentRect: .zero, styleMask: [], backing: .buffered, defer: true)
    window.isReleasedWhenClosed = false
    window.minimized = minimized
    delegate.mainFlutterWindow = window
    let callback: NSApplicationDelegate = delegate

    check(callback.applicationShouldHandleReopen?(.shared, hasVisibleWindows: visible) == false, "main-window reopen must handle the event")
    check(window.operations == (minimized ? ["restore", "show"] : ["show"]), "reopen must restore/raise the original window")
    check(delegate.mainFlutterWindow === window, "reopen must retain the same window")
  }

  func testLaunchRetainsMainWindow() {
    let delegate = AppDelegate()
    weak var retained: NSWindow?
    autoreleasepool {
      let window = WindowSpy(contentRect: .zero, styleMask: [], backing: .buffered, defer: true)
      window.isReleasedWhenClosed = false
      delegate.mainFlutterWindow = window
      retained = window
      delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    }
    check(retained != nil, "the main window must survive its weak Flutter outlet")
  }

  func testDockReopenRestoresOriginalClosedWindow() {
    reopen(visible: false)
  }

  func testDockReopenRaisesExistingWindow() {
    reopen(visible: true)
  }

  func testDockReopenDeminiaturizesBeforeShowingWindow() {
    reopen(visible: true, minimized: true)
  }

  func testPreferencesAreDisabledUntilWorkspaceIsReady() {
    let delegate = AppDelegate()
    let window = WindowSpy(contentRect: .zero, styleMask: [], backing: .buffered, defer: true)
    window.isReleasedWhenClosed = false
    delegate.mainFlutterWindow = window
    let item = NSMenuItem(title: "Preferences", action: #selector(AppDelegate.showPreferences(_:)), keyEquivalent: ",")
    check(!delegate.validateMenuItem(item), "preferences must be disabled before a workspace exists")
    delegate.showPreferences(nil)
    check(window.operations.isEmpty, "an unavailable workspace must not be opened")
  }

  func testPreferencesRestoreOriginalWindowBeforeNavigation() {
    let delegate = AppDelegate()
    let window = WindowSpy(contentRect: .zero, styleMask: [], backing: .buffered, defer: true)
    window.isReleasedWhenClosed = false
    window.canOpenPreferences = true
    window.minimized = true
    delegate.mainFlutterWindow = window
    let item = NSMenuItem(title: "Preferences", action: #selector(AppDelegate.showPreferences(_:)), keyEquivalent: ",")
    check(delegate.validateMenuItem(item), "preferences must become available with the workspace")
    delegate.showPreferences(nil)
    check(window.operations == ["restore", "show", "preferences"], "preferences must restore the same window before navigation")
    check(delegate.mainFlutterWindow === window, "preferences must not create a replacement window")
  }

  func testMissingWindowDisablesOnlyPreferences() {
    let delegate = AppDelegate()
    let item = NSMenuItem(title: "Preferences", action: #selector(AppDelegate.showPreferences(_:)), keyEquivalent: ",")
    check(!delegate.validateMenuItem(item), "missing window must disable preferences")
    delegate.showPreferences(nil)
    let hide = NSMenuItem(title: "Hide", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
    check(delegate.validateMenuItem(hide), "preferences validation must not disable other app commands")
  }

  func testUpdatesAreDisabledUntilCommandsAreReady() {
    let delegate = AppDelegate()
    let window = WindowSpy(contentRect: .zero, styleMask: [], backing: .buffered, defer: true)
    window.isReleasedWhenClosed = false
    delegate.mainFlutterWindow = window
    let item = NSMenuItem(title: "Check for Updates…", action: #selector(AppDelegate.checkForUpdates(_:)), keyEquivalent: "")
    check(!delegate.validateMenuItem(item), "updates must stay disabled before command registration")
    delegate.checkForUpdates(nil)
    check(window.operations.isEmpty, "disabled updates must not launch anything")
  }

  func testUpdatesWorkWithoutWorkspaceAndRestoreOriginalWindow() {
    let delegate = AppDelegate()
    let window = WindowSpy(contentRect: .zero, styleMask: [], backing: .buffered, defer: true)
    window.isReleasedWhenClosed = false
    window.canCheckForUpdates = true
    window.minimized = true
    delegate.mainFlutterWindow = window
    let item = NSMenuItem(title: "Check for Updates…", action: #selector(AppDelegate.checkForUpdates(_:)), keyEquivalent: "")
    check(delegate.validateMenuItem(item), "updates must not depend on signed-in workspace preferences")
    delegate.checkForUpdates(nil)
    check(window.operations == ["restore", "show", "updates"], "updates must restore the original window and use its command")
    check(delegate.mainFlutterWindow === window, "updates must preserve the original window")
    window.canCheckForUpdates = false
    check(!delegate.validateMenuItem(item), "a pending request must disable the update command")
  }

  func testMissingWindowDisablesUpdates() {
    let delegate = AppDelegate()
    let item = NSMenuItem(title: "Check for Updates…", action: #selector(AppDelegate.checkForUpdates(_:)), keyEquivalent: "")
    check(!delegate.validateMenuItem(item), "updates need a registered command window")
    delegate.checkForUpdates(nil)
  }

  func testCloseRepeatGuardAcceptsOnlyRepeatedKeyDown() {
    check(!MainFlutterWindow.isRepeatedCloseKey(nil), "menu action without an event must be accepted")
    let application = NSEvent.otherEvent(with: .applicationDefined, location: .zero,
      modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
      subtype: 0, data1: 0, data2: 0)!
    check(!MainFlutterWindow.isRepeatedCloseKey(application), "an application event must not access isARepeat")
    let mouse = NSEvent.mouseEvent(with: .leftMouseDown, location: .zero,
      modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
      eventNumber: 1, clickCount: 1, pressure: 1)!
    check(!MainFlutterWindow.isRepeatedCloseKey(mouse), "mouse menu clicks must not access isARepeat")
    for repeated in [false, true] {
      let event = NSEvent.keyEvent(with: .keyDown, location: .zero,
        modifierFlags: .command, timestamp: 0, windowNumber: 0, context: nil,
        characters: "w", charactersIgnoringModifiers: "w", isARepeat: repeated, keyCode: 13)!
      check(MainFlutterWindow.isRepeatedCloseKey(event) == repeated, "only repeated key-down must be ignored")
    }
  }

  func testMissingMainWindowLeavesDefaultReopenHandling() {
    let callback: NSApplicationDelegate = AppDelegate()
    check(callback.applicationShouldHandleReopen?(.shared, hasVisibleWindows: false) == true, "missing window must leave default handling")
  }
}

_ = NSApplication.shared.setActivationPolicy(.prohibited)
let tests = WindowLifecycleTests()
tests.testClosingLastWindowKeepsAppRunning()
tests.testLaunchRetainsMainWindow()
tests.testDockReopenRestoresOriginalClosedWindow()
tests.testDockReopenRaisesExistingWindow()
tests.testDockReopenDeminiaturizesBeforeShowingWindow()
tests.testMissingMainWindowLeavesDefaultReopenHandling()
tests.testPreferencesAreDisabledUntilWorkspaceIsReady()
tests.testPreferencesRestoreOriginalWindowBeforeNavigation()
tests.testMissingWindowDisablesOnlyPreferences()
tests.testCloseRepeatGuardAcceptsOnlyRepeatedKeyDown()
tests.testUpdatesAreDisabledUntilCommandsAreReady()
tests.testUpdatesWorkWithoutWorkspaceAndRestoreOriginalWindow()
tests.testMissingWindowDisablesUpdates()
for failure in failures { print("FAIL: \(failure)") }
print("Native window lifecycle: 13 cases, \(failures.count) failed assertions")
exit(failures.isEmpty ? 0 : 1)
