import XCTest

final class NotificationStartupUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
    #if !targetEnvironment(simulator)
    throw XCTSkip("This fixture controls only a dedicated simulator")
    #else
    XCTAssertEqual(ProcessInfo.processInfo.environment["SIMULATOR_UDID"], Configuration.simulator)
    XCTAssertTrue(Configuration.bundle.hasPrefix("app.raft.notification-startup.qa."))
    #endif
  }

  func testPermissionAnswerAndColdRelaunch() throws {
    guard Configuration.choice != "audit" else { throw XCTSkip("Run the audit case") }
    let app = XCUIApplication(bundleIdentifier: Configuration.bundle)
    app.launch()
    XCTAssertTrue(app.buttons["Enable notifications"].waitForExistence(timeout: 20))
    capture(app, "before-first-opt-in")
    app.buttons["Enable notifications"].tap()
    answerPrompt(allow: Configuration.choice == "allow", name: "notification")
    XCTAssertTrue(app.staticTexts["Permission and background binding completed"].waitForExistence(timeout: 20))
    let allowed = Configuration.choice == "allow"
    assertPermission(app, allowed)
    capture(app, "notification-permission-answered")
    app.buttons["Save synthetic photo"].tap()
    answerPrompt(allow: allowed, name: "photo-add-only")
    assertPhotoResult(app, allowed)
    capture(app, "photo-permission-answered")
    for i in 1...2 {
      coldLaunch(app)
      assertPermission(app, allowed)
      savePhoto(app, allowed)
      capture(app, "cold-relaunch-\(i)")
    }
    app.terminate()
  }

  // Run against the denied fixture after its permission test. This never
  // resets permissions or app data; changes go through real Settings controls.
  func testSettingsAndPhotosAudit() throws {
    guard Configuration.choice == "audit" else { throw XCTSkip("Run with audit configuration") }
    let app = XCUIApplication(bundleIdentifier: Configuration.bundle)
    app.launch()
    assertPermission(app, false)
    savePhoto(app, false)
    app.buttons["Pick photos"].tap()
    let cancel = app.buttons["Cancel"]
    XCTAssertTrue(cancel.waitForExistence(timeout: 15))
    capture(app, "system-photo-picker-while-library-denied")
    cancel.tap()
    XCTAssertTrue(app.staticTexts["Photos selected: 0"].waitForExistence(timeout: 15))
    capture(app, "photo-picker-cancelled")

    for allowed in [true, false] {
      let settings = openSettings(app)
      settings.buttons["NOTIFICATIONS"].tap()
      let toggle = settings.switches["ALLOW_NOTIFICATIONS_ID"]
      XCTAssertTrue(toggle.waitForExistence(timeout: 10))
      XCTAssertEqual(toggle.value as? String, allowed ? "0" : "1")
      // Settings exposes a full-row switch plus its actual thumb. Tap the
      // visible thumb; the centre of the full row only hits the label.
      toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
      let changed = XCTNSPredicateExpectation(
        predicate: NSPredicate(format: "value == %@", allowed ? "1" : "0"), object: toggle)
      XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed)
      capture(settings, "notification-settings-\(allowed)")
      app.activate()
      assertPermission(app, allowed)
      capture(app, "notification-settings-return-\(allowed)")
      coldLaunch(app)
      assertPermission(app, allowed)

      let photos = openSettings(app)
      photos.buttons["PHOTOS"].tap()
      let access = photos.cells[allowed ? "Add Photos Only" : "None"]
      XCTAssertTrue(access.waitForExistence(timeout: 10))
      access.tap()
      XCTAssertTrue(access.isSelected)
      capture(photos, "photo-settings-\(allowed)")
      app.activate()
      XCTAssertTrue(app.buttons["Save synthetic photo"].waitForExistence(timeout: 20))
      savePhoto(app, allowed)
      capture(app, "photo-settings-return-\(allowed)")
      coldLaunch(app)
      assertPermission(app, allowed)
      savePhoto(app, allowed)
      capture(app, "settings-cold-relaunch-\(allowed)")
    }
    app.terminate()
  }

  private func answerPrompt(allow: Bool, name: String) {
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let alert = springboard.alerts.firstMatch
    XCTAssertTrue(alert.waitForExistence(timeout: 10), "A real OS permission prompt must appear")
    capture(springboard, "actual-\(name)-prompt")
    let button = allow ? alert.buttons["Allow"]
      : alert.buttons.matching(NSPredicate(format: "label IN %@", ["Don’t Allow", "Don't Allow"])).firstMatch
    XCTAssertTrue(button.exists)
    button.tap()
  }

  private func assertPermission(_ app: XCUIApplication, _ allowed: Bool) {
    XCTAssertTrue(app.staticTexts[allowed ? "Permission: allowed" : "Permission: denied"].waitForExistence(timeout: 20))
  }

  private func assertPhotoResult(_ app: XCUIApplication, _ allowed: Bool) {
    XCTAssertTrue(app.staticTexts[allowed ? "Photo saved" : "Photo result: permission"].waitForExistence(timeout: 20))
  }

  private func savePhoto(_ app: XCUIApplication, _ allowed: Bool) {
    XCTAssertTrue(app.buttons["Save synthetic photo"].waitForExistence(timeout: 20))
    app.buttons["Save synthetic photo"].tap()
    assertPhotoResult(app, allowed)
  }

  private func coldLaunch(_ app: XCUIApplication) {
    app.terminate()
    app.launch()
    XCTAssertTrue(app.staticTexts["Restored after cold launch"].waitForExistence(timeout: 20))
  }

  private func openSettings(_ app: XCUIApplication) -> XCUIApplication {
    app.buttons["Open app settings"].tap()
    let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
    XCTAssertTrue(settings.wait(for: .runningForeground, timeout: 15))
    if !settings.buttons["NOTIFICATIONS"].waitForExistence(timeout: 3) {
      if settings.switches["ALLOW_NOTIFICATIONS_ID"].exists || settings.cells["Add Photos Only"].exists {
        settings.navigationBars.buttons["BackButton"].tap()
      }
    }
    if !settings.buttons["NOTIFICATIONS"].exists {
      if !settings.navigationBars["Apps"].exists {
        let apps = settings.buttons["com.apple.settings.apps"]
        for _ in 0..<5 {
          if apps.isHittable { break }
          settings.swipeUp()
        }
        XCTAssertTrue(apps.isHittable)
        apps.tap()
      }
      let qa = settings.buttons[Configuration.bundle]
      for _ in 0..<5 {
        if qa.isHittable { break }
        settings.swipeUp()
      }
      XCTAssertTrue(qa.isHittable)
      qa.tap()
    }
    XCTAssertTrue(settings.buttons["NOTIFICATIONS"].waitForExistence(timeout: 10))
    return settings
  }

  private func capture(_ app: XCUIApplication, _ name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
