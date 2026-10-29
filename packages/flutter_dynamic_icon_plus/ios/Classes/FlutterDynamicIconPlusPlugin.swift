import Flutter
import UIKit

public class FlutterDynamicIconPlusPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_dynamic_icon_plus", binaryMessenger: registrar.messenger())
        let instance = FlutterDynamicIconPlusPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case MethodNames.supportsAlternateIcons:
            if #available(iOS 10.3, *){
                result(UIApplication.shared.supportsAlternateIcons)
            }
            else {
                result(FlutterError(code: "Unavailable", message: "Method supportsAlternateIcons unsupported on iOS version < 10.3", details: nil))
            }
        case MethodNames.getAlternateIconName:
            if #available(iOS 10.3, *){
                result(UIApplication.shared.alternateIconName)
            }
            else {
                result(FlutterError(code: "Unavailable", message: "Method getAlternateIconName unsupported on iOS version < 10.3", details: nil))
            }
        case MethodNames.setAlternateIconName:
            if #available(iOS 10.3, *){
                guard let args = call.arguments as? [String: Any] else {
                    result(FlutterError(code: "InvalidArguments", message: "Missing or invalid arguments for setAlternateIconName", details: nil))
                    return
                }
                let iconName = args[Arguments.iconName] as? String
                let isSilent = args[Arguments.isSilent]

                if let isSilent = isSilent as? Bool, isSilent {
                    result(FlutterError(code: "unsupported_silent_icon", message: "Silent icon changes are not supported.", details: nil))
                } else {
                    self.setIconWithAlert(iconName, result: result)
                }
            }
            else {
                result(FlutterError(code: "Unavailable", message: "Method setAlternateIconName unsupported on iOS version < 10.3", details: nil))
            }
        case MethodNames.getApplicationIconBadgeNumber:
            if #available(iOS 10.3, *){
                result(NSNumber(value: UIApplication.shared.applicationIconBadgeNumber))
            }
            else {
                result(FlutterError(code: "Unavailable", message: "Method getApplicationIconBadgeNumber unsupported on iOS version < 10.3", details: nil))
            }
        case MethodNames.setApplicationIconBadgeNumber:
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "InvalidArguments", message: "Missing or invalid arguments for setApplicationIconBadgeNumber", details: nil))
                return
            }
            if #available(iOS 10.3, *){
                if #available(iOS 10.0, *) {
                    UNUserNotificationCenter.current().requestAuthorization(options: .badge) { granted, error in
                        if granted {
                            let batchIconNumber = (args[Arguments.batchIconNumber] as? NSNumber)?.intValue ?? 0
                            UIApplication.shared.applicationIconBadgeNumber = batchIconNumber
                            result(nil)
                        }
                        else {
                            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) {
                                (granted, error) in
                                let batchIconNumber = (args[Arguments.batchIconNumber] as? NSNumber)?.intValue ?? 0
                                UIApplication.shared.applicationIconBadgeNumber = batchIconNumber
                                result(nil)
                            }
                        }
                    }
                }
                else {
                    result(
                        FlutterError(
                            code: "Failed to set batch icon number",
                            message: "Permission denied by the user",
                            details: nil))
                }
            }
            else {
                let notificationSettings = UIUserNotificationSettings(types: .badge, categories: nil)
                UIApplication.shared.registerUserNotificationSettings(notificationSettings)
                let batchIconNumber = (args[Arguments.batchIconNumber] as? NSNumber)?.intValue ?? 0
                UIApplication.shared.applicationIconBadgeNumber = batchIconNumber
                result(nil)
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func setIconWithAlert(_ appIcon: String?, result: @escaping FlutterResult) {
        UIApplication.shared.setAlternateIconName(appIcon) { error in
          DispatchQueue.main.async {
            if let error {
                result(
                    FlutterError(
                        code: "Failed to set icon \(error.localizedDescription)",
                        message: error.localizedDescription,
                        details: nil))
            } else {
                result(nil)
            }
          }
        }
    }
}
