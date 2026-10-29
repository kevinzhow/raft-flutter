import Flutter
import UIKit
import XCTest
import workmanager_apple

class RunnerTests: XCTestCase {
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
}
