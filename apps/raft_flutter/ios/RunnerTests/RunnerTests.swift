import Flutter
import UIKit
import UserNotifications
import XCTest
@testable import Runner
import workmanager_apple

class RunnerTests: XCTestCase {
  @MainActor
  func testAppDelegateReceivesNotificationCenterCallbacks() {
    // flutter_local_notifications presents foreground alerts and reports taps
    // only through the app delegate. Without it iOS silently drops every
    // notification posted while Raft is open, including the settings test.
    XCTAssertTrue(UNUserNotificationCenter.current().delegate === UIApplication.shared.delegate)
  }

  func testFoldSnapshotBuildingAndDeduplication() {
    let region: [AnyHashable: Any] = ["kind": "division", "active": true,
                                     "x": 455.0, "y": 0.0, "w": 40.0, "h": 669.0]
    let snapshot = raftFoldSnapshot(status: "partiallyOpen", regions: [region], size: CGSize(width: 951, height: 669))
    XCTAssertEqual(snapshot["hinge"] as? String, "partiallyOpen")
    XCTAssertEqual(snapshot["viewWidth"] as? Double, 951)
    XCTAssertTrue(raftFoldSnapshotChanged(snapshot, from: nil))
    XCTAssertFalse(raftFoldSnapshotChanged(
      raftFoldSnapshot(status: "partiallyOpen", regions: [region], size: CGSize(width: 951, height: 669)), from: snapshot))
    var changed = region
    changed["active"] = false
    XCTAssertTrue(raftFoldSnapshotChanged(
      raftFoldSnapshot(status: "partiallyOpen", regions: [changed], size: CGSize(width: 951, height: 669)), from: snapshot))
    XCTAssertTrue(raftFoldSnapshotChanged(
      raftFoldSnapshot(status: "none", regions: [], size: CGSize(width: 951, height: 669)), from: snapshot))
    XCTAssertFalse(raftFoldStatusChanged("partiallyOpen", from: "partiallyOpen"))
    XCTAssertTrue(raftFoldStatusChanged("none", from: "partiallyOpen"))
  }

  func testFoldListenCancelListenAndNilHinge() {
    let bridge = RaftFoldBridge()
    let controller = FlutterViewController()
    bridge.controller = controller
    let view = FoldLayoutTestView()
    controller.view = view
    let monitor = FoldTestMonitor()
    var creations = 0
    var update: ((String) -> Void)?
    bridge.makeMonitor = { _, callback in
      creations += 1
      update = callback
      return monitor
    }
    var events: [NSDictionary] = []
    let sink: FlutterEventSink = { if let value = $0 as? NSDictionary { events.append(value) } }
    XCTAssertNil(bridge.onListen(withArguments: nil, eventSink: sink))
    update?("partiallyOpen")
    let layouts = view.layoutRequests
    update?("partiallyOpen")
    XCTAssertEqual(view.layoutRequests, layouts)
    bridge.layoutPassed(controller)
    bridge.layoutPassed(controller)
    XCTAssertEqual(events.count, 1)
    update?("none")
    bridge.layoutPassed(controller)
    XCTAssertEqual(events.last?["hinge"] as? String, "none")
    XCTAssertNil(bridge.onCancel(withArguments: nil))
    bridge.layoutPassed(controller)
    XCTAssertEqual(events.count, 2)
    XCTAssertEqual(monitor.invalidations, 1)
    XCTAssertEqual(monitor.reads, 3)
    XCTAssertNil(bridge.onListen(withArguments: nil, eventSink: sink))
    bridge.layoutPassed(controller)
    XCTAssertEqual(events.count, 3)
    XCTAssertEqual(creations, 2)
    XCTAssertNil(bridge.onCancel(withArguments: nil))
  }

  func testStoryboardCreatesFoldControllerAndImplicitEngineRegistersPlugins() throws {
    let controller = try XCTUnwrap(UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }
      .compactMap { $0.rootViewController as? RaftFlutterViewController }.first)
    RaftFoldBridge.shared.layoutPassed(controller)
    XCTAssertTrue(RaftFoldBridge.shared.controller === controller)
    let engine = try XCTUnwrap(controller.engine)
    XCTAssertTrue(engine.hasPlugin("RaftFoldBridge"))
    XCTAssertTrue(engine.hasPlugin("RaftSharingBridge"))
  }

  func testNativePermissionUsageDescriptions() throws {
    for key in ["NSPhotoLibraryUsageDescription", "NSPhotoLibraryAddUsageDescription", "NSLocalNetworkUsageDescription"] {
      let text = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: key) as? String, key)
      XCTAssertFalse(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, key)
    }
  }

  func testInboxRefreshHandlerWasRegisteredBeforeFirstNotificationOptIn() async throws {
    guard Bundle.main.bundleIdentifier?.hasPrefix("app.raft.notification-startup.qa.") == true else {
      throw XCTSkip("Run with the isolated notification_startup_main.dart fixture on a fresh simulator.")
    }
    guard !UserDefaults.standard.bool(forKey: "flutter.notification-startup-fixture.opted-in") else {
      throw XCTSkip("Use a fresh isolated fixture identity; a previous opt-in can leave launch metadata.")
    }
    try await MainActor.run {
      let identifier = "app.raft.raft_flutter.inbox_refresh"
      XCTAssertEqual(
        Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers") as? [String],
        [identifier]
      )
      // The fixture has not enabled notifications or submitted work. On a
      // fresh install this metadata can only come from native launch-time
      // preparation. Checking it first also catches the regression on the
      // simulator, where BGTaskScheduler does not enforce every device rule.
      let domain = "dev.fluttercommunity.workmanager"
      let store = try XCTUnwrap(UserDefaults(suiteName: "\(domain).userDefaults"))
      let data = try XCTUnwrap(
        store.data(forKey: "\(domain).scheduledTasks"),
        "The first notification opt-in must not be the first handler registration"
      )
      let tasks = try XCTUnwrap(
        JSONSerialization.jsonObject(with: data) as? [String: [String: Any]]
      )
      XCTAssertEqual(tasks[identifier]?["kind"] as? String, "refresh")
      // The same native call reached after scheduling must now be idempotent.
      WorkmanagerPlugin.registerPeriodicTask(withIdentifier: identifier)
    }
  }

  /// A system Paste of attachments is taken only once Dart's watcher listens
  /// (it asks `available` first). Before that the text paste runs at once.
  @MainActor
  func testClipboardPasteWaitsForDartWatcher() {
    let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
      UIColor.red.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
    }
    UIPasteboard.general.image = image
    let engine = FlutterEngine(name: "clipboard-attachments-test")
    let channel = FlutterMethodChannel(
      name: "app.raft/clipboard-attachments-test", binaryMessenger: engine.binaryMessenger)
    let clipboard = RaftClipboardAttachments(channel: channel)
    var textPastes = 0

    XCTAssertFalse(clipboard.dartReady)
    XCTAssertFalse(clipboard.systemPaste(orElse: { textPastes += 1 }))
    XCTAssertEqual(textPastes, 0)

    var answer: Any?
    clipboard.handle(FlutterMethodCall(methodName: "available", arguments: nil)) { answer = $0 }
    XCTAssertTrue(clipboard.dartReady)
    XCTAssertEqual(answer as? Bool, true)
    XCTAssertTrue(clipboard.systemPaste(orElse: { textPastes += 1 }))
  }
}

private final class FoldLayoutTestView: UIView {
  var layoutRequests = 0
  override func setNeedsLayout() {
    layoutRequests += 1
    super.setNeedsLayout()
  }
}

private final class FoldTestMonitor: RaftFoldMonitoring {
  var reads = 0
  var invalidations = 0
  func readRegions() -> [[AnyHashable: Any]] {
    reads += 1
    return [["kind": "division", "active": true, "x": 455.0,
             "y": 0.0, "w": 40.0, "h": 669.0]]
  }
  func invalidate() { invalidations += 1 }
}
