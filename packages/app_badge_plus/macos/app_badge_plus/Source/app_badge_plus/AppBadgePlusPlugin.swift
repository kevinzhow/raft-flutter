import Cocoa
import FlutterMacOS

public class AppBadgePlusPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "app_badge_plus", binaryMessenger: registrar.messenger)
    let instance = AppBadgePlusPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
      case "updateBadge":
        let args = call.arguments as? Dictionary<String, Any>
        let count = (args?["count"] as? Int) ?? 0
        DispatchQueue.main.async {
          let expected = count > 0 ? "\(count)" : nil
          NSApplication.shared.dockTile.badgeLabel = expected
          // AppKit's setter is synchronous; acknowledge its applied property,
          // not merely scheduling work on the main queue.
          if (NSApplication.shared.dockTile.badgeLabel ?? "") == (expected ?? "") {
            result(nil)
          } else {
            result(FlutterError(
              code: "badge_update_failed",
              message: "The Dock badge value was not applied.",
              details: nil
            ))
          }
        }
      case "isSupported":
        result(true)
      default:
        result(FlutterMethodNotImplemented)
    }
  }
}
