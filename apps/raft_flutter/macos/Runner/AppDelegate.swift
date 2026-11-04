import Cocoa
import FlutterMacOS
import app_links

protocol RaftPreferencesWindow: AnyObject {
  var canOpenPreferences: Bool { get }
  func openPreferences()
}

protocol RaftPasteWindow: AnyObject {
  var canPasteIntoFlutter: Bool { get }
  func pasteFromMenu()
}

protocol RaftUpdatesWindow: AnyObject {
  var canCheckForUpdates: Bool { get }
  func checkForUpdates()
}

@main
class AppDelegate: FlutterAppDelegate, NSMenuItemValidation {
  // Flutter's outlet is weak. Keep the existing window and engine alive when
  // the user closes it, so reopening preserves the current workspace and draft.
  private var retainedMainWindow: NSWindow?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    // The nib starts invisible. Show behind existing windows without activation,
    // including when a cold launch finishes after the user has switched apps.
    retainedMainWindow = mainFlutterWindow
    retainedMainWindow?.order(.below, relativeTo: 0)
  }

  // app_links 7.2.2 handles custom URLs but needs the host to forward
  // NSUserActivity universal links, including an entry before Dart listens.
  override func application(
    _ application: NSApplication, continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([any NSUserActivityRestoring]) -> Void
  ) -> Bool {
    guard let url = AppLinks.shared.getUniversalLink(userActivity),
      let host = Bundle.main.object(forInfoDictionaryKey: "RaftAppLinkHost") as? String,
      url.scheme == "https", url.user == nil, url.password == nil, url.host?.lowercased() == host.lowercased()
    else { return false }
    AppLinks.shared.handleLink(link: url.absoluteString)
    _ = restoreMainWindow()
    // Keep propagation to other plugins, as the app_links host contract requires.
    return false
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationShouldHandleReopen(
    _ sender: NSApplication, hasVisibleWindows flag: Bool
  ) -> Bool {
    return restoreMainWindow() == nil
  }

  private func restoreMainWindow() -> NSWindow? {
    guard let window = retainedMainWindow ?? mainFlutterWindow else { return nil }
    if window.isMiniaturized { window.deminiaturize(nil) }
    window.makeKeyAndOrderFront(nil)
    return window
  }

  @objc func showPreferences(_ sender: Any?) {
    if let target = RaftChildWindow.commands(for: NSApp.keyWindow), target.canOpenPreferences {
      target.openPreferences(); return
    }
    guard let target = (retainedMainWindow ?? mainFlutterWindow) as? RaftPreferencesWindow,
      target.canOpenPreferences else { return }
    _ = restoreMainWindow()
    target.openPreferences()
  }

  @objc func checkForUpdates(_ sender: Any?) {
    guard let window = (retainedMainWindow ?? mainFlutterWindow) as? RaftUpdatesWindow,
      window.canCheckForUpdates else { return }
    _ = restoreMainWindow()
    window.checkForUpdates()
  }

  private var pasteWindow: RaftPasteWindow? {
    if let child = RaftChildWindow.commands(for: NSApp.keyWindow) { return child }
    let window = retainedMainWindow ?? mainFlutterWindow
    guard NSApp.keyWindow === window else { return nil }
    return window as? RaftPasteWindow
  }

  @objc func pasteIntoFlutter(_ sender: Any?) {
    if let window = pasteWindow {
      window.pasteFromMenu()
    } else {
      // Native file dialogs keep their own AppKit responder chain.
      NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: sender)
    }
  }

  func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
    if menuItem.action == #selector(checkForUpdates(_:)) {
      return ((retainedMainWindow ?? mainFlutterWindow) as? RaftUpdatesWindow)?
        .canCheckForUpdates ?? false
    }
    if menuItem.action == #selector(pasteIntoFlutter(_:)) {
      if let window = pasteWindow { return window.canPasteIntoFlutter }
      let action = #selector(NSText.paste(_:))
      guard let target = NSApp.target(forAction: action) else { return false }
      let item = NSMenuItem(title: menuItem.title, action: action, keyEquivalent: "")
      return (target as? NSMenuItemValidation)?.validateMenuItem(item) ?? true
    }
    if menuItem.action == #selector(showPreferences(_:)) {
      if let child = RaftChildWindow.commands(for: NSApp.keyWindow) { return child.canOpenPreferences }
      return ((retainedMainWindow ?? mainFlutterWindow) as? RaftPreferencesWindow)?
        .canOpenPreferences ?? false
    }
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
