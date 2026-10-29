import Cocoa
import FlutterMacOS
import Sparkle

/// Bridges Sparkle 2's standard updater UI to Dart (`app.raft/updater`).
///
/// The app is sandboxed, so Sparkle runs its installer through the
/// `Installer.xpc` launcher service: Info.plist must set
/// `SUEnableInstallerLauncherService`, and the entitlements must allow the
/// `-spks` / `-spki` mach-lookup names (see docs/auto-update.md). Updates are
/// verified with the EdDSA key in `SUPublicEDKey`; without that key the
/// updater stays off and Dart opens the release page instead.
public class RaftUpdaterPlugin: NSObject, FlutterPlugin, SPUUpdaterDelegate {
    private var controller: SPUStandardUpdaterController?
    private var feedURL: String?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "app.raft/updater", binaryMessenger: registrar.messenger)
        let instance = RaftUpdaterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "configure":
            result(configure(call.arguments as? [String: Any] ?? [:]))
        case "checkForUpdates":
            guard let controller = controller else {
                result(false)
                return
            }
            // Foreground check with Sparkle's own UI: "update available",
            // release notes, download progress, install and relaunch. The
            // user driver activates the app itself when it shows the alert
            // (SPUStandardUserDriver _activateApplication), so no activate here.
            controller.checkForUpdates(nil)
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func configure(_ arguments: [String: Any]) -> [String: Any] {
        if controller != nil {
            return ["available": true]
        }
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        if key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ["available": false, "reason": "This build has no SUPublicEDKey."]
        }
        // https only; loopback http is for local rehearsals (needs NSAllowsLocalNetworking).
        guard let feed = arguments["feedUrl"] as? String,
              feed.hasPrefix("https://") || feed.hasPrefix("http://localhost") || feed.hasPrefix("http://127.0.0.1")
        else {
            return ["available": false, "reason": "The update feed must be an https URL."]
        }
        feedURL = feed
        let created = SPUStandardUpdaterController(
            startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
        do {
            try created.updater.start()
        } catch {
            return ["available": false, "reason": "Sparkle failed to start: \(error.localizedDescription)"]
        }
        controller = created
        return ["available": true]
    }

    // MARK: SPUUpdaterDelegate

    public func feedURLString(for updater: SPUUpdater) -> String? {
        return feedURL
    }
}
