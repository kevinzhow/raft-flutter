import Flutter
import UIKit
import UserNotifications

public class AppBadgePlusPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "app_badge_plus", binaryMessenger: registrar.messenger())
    let instance = AppBadgePlusPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
      case "updateBadge":
        let args = call.arguments as? Dictionary<String, Any>
        let count = (args?["count"] as? Int) ?? 0
        DispatchQueue.main.async {
          if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(count) { error in
              // The system completion may arrive off the platform thread.
              DispatchQueue.main.async {
                if let error = error as NSError? {
                  result(FlutterError(
                    code: "badge_update_failed",
                    message: error.localizedDescription,
                    details: ["domain": error.domain, "code": error.code]
                  ))
                } else {
                  result(nil)
                }
              }
            }
          } else {
            Self.updateLegacyBadge(count, result: result)
          }
        }
      case "isSupported":
        result(true)
      default:
        result(FlutterMethodNotImplemented)
    }
  }

  // The legacy setter is synchronous. Check its property before acknowledging;
  // this verifies the API value, not the visual home-screen badge.
  static func updateLegacyBadge(_ count: Int, result: @escaping FlutterResult) {
    UIApplication.shared.applicationIconBadgeNumber = count
    if UIApplication.shared.applicationIconBadgeNumber == count {
      result(nil)
    } else {
      result(FlutterError(
        code: "badge_update_failed",
        message: "The application badge value was not applied.",
        details: nil
      ))
    }
  }
}
