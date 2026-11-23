import Cocoa
import FlutterMacOS
import XCTest
@testable import Raft

class RunnerTests: XCTestCase {

  func testExample() {
    // If you add code to the Runner application, consider adding tests here.
    // See https://developer.apple.com/documentation/xctest for more information about using XCTest.
  }

  func testBrowserSubframePolicy() {
    let blocked: Set<String> = ["raft.test"]
    for address in ["http://public.test/", "https://public.test/", "about:blank",
                    "about:srcdoc", "blob:https://public.test/id", "data:text/html,example"] {
      XCTAssertTrue(desktopBrowserAllowsNavigation(URL(string: address),
                                                    blockedHosts: blocked, mainFrame: false), address)
    }
    for address in ["https://raft.test./", "https://user:pass@public.test/", "raft://channel/id",
                    "file:///example.html", "about:config", "javascript:void(0)"] {
      XCTAssertFalse(desktopBrowserAllowsNavigation(URL(string: address),
                                                     blockedHosts: blocked, mainFrame: false), address)
    }
    XCTAssertFalse(desktopBrowserAllowsNavigation(URL(string: "about:blank"),
                                                   blockedHosts: blocked, mainFrame: true))
  }

  func testBrowserCloseShortcutUsesActiveLatinLayout() {
    XCTAssertTrue(desktopBrowserCloseShortcut("W", latinFallback: { nil }))
    XCTAssertFalse(desktopBrowserCloseShortcut("z", latinFallback: { "w" }))
    XCTAssertTrue(desktopBrowserCloseShortcut("ц", latinFallback: { "w" }))
    XCTAssertFalse(desktopBrowserCloseShortcut("\u{1b}", latinFallback: { "w" }))
  }
}
