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

  func testBrowserMediaSuspensionCallsOnlyForTransitions() {
    var media = DesktopBrowserMediaSuspension()
    var calls: [Bool] = []
    XCTAssertFalse(media.muted)
    for requested in [false, true, true, false, false, true, false] {
      media.setMuted(requested) { calls.append($0) }
    }
    XCTAssertEqual(calls, [true, false, true, false])
    XCTAssertFalse(media.muted)
  }

  func testFragmentClickCannotAuthorizeALaterDownloadRedirect() throws {
    let page = try XCTUnwrap(URL(string: "https://public.test/page"))
    let fragment = try XCTUnwrap(URL(string: "\(page.absoluteString)#"))
    let timerTarget = try XCTUnwrap(URL(string: "https://public.test/go"))
    let download = try XCTUnwrap(URL(string: "https://public.test/file"))
    let navigation = NSObject()
    var now: TimeInterval = 0
    var authorization = DesktopBrowserDownloadAuthorization()
    authorization.now = { now }

    authorization.clicked(fragment)
    authorization.authorize(fragment, currentPage: page, requiresLink: true)
    XCTAssertFalse(authorization.consume(fragment))

    now = 5
    authorization.authorize(timerTarget, currentPage: fragment, requiresLink: false)
    authorization.started(timerTarget, navigation: navigation)
    authorization.redirected(download, navigation: navigation)
    XCTAssertFalse(authorization.consume(download))
  }

  func testBrowserDownloadClickCanBeConsumedOnlyOnce() throws {
    let target = try XCTUnwrap(URL(string: "https://public.test/export"))
    let download = try XCTUnwrap(URL(string: "https://cdn.test/file"))
    let navigation = NSObject()
    var now: TimeInterval = 0
    var authorization = DesktopBrowserDownloadAuthorization()
    authorization.now = { now }

    authorization.clicked(download)
    authorization.authorize(download, currentPage: nil, requiresLink: true)
    XCTAssertTrue(authorization.consume(download))
    XCTAssertFalse(authorization.consume(download))

    authorization.clicked(target)
    authorization.authorize(target, currentPage: nil, requiresLink: true)
    authorization.started(target, navigation: navigation)
    now = 0.5
    authorization.redirected(download, navigation: navigation)
    XCTAssertTrue(authorization.consume(download))
    XCTAssertFalse(authorization.consume(download))

    authorization.clicked(target)
    authorization.authorize(target, currentPage: nil, requiresLink: true)
    authorization.started(target, navigation: navigation)
    now = 5
    authorization.redirected(download, navigation: navigation)
    XCTAssertFalse(authorization.consume(download))

    authorization.clicked(target)
    authorization.authorize(target, currentPage: nil, requiresLink: true)
    now = 7
    XCTAssertFalse(authorization.consume(target))
  }
}
