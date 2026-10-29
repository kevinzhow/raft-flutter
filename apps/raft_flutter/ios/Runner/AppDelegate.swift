import Flutter
import UIKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Restore alone only covers tasks persisted by a previous launch. The first
    // notification opt-in also needs its handler before Dart submits the task.
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "app.raft.raft_flutter.inbox_refresh"
    )
    WorkmanagerPlugin.registerLaunchHandlers()
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RaftDeviceMemory") {
      FlutterMethodChannel(name: "app.raft/device-memory", binaryMessenger: registrar.messenger())
        .setMethodCallHandler { call, result in
          if call.method == "snapshot" {
            result(["totalBytes": Int64(ProcessInfo.processInfo.physicalMemory)])
          } else if call.method == "availableStorageBytes",
            let args = call.arguments as? [String: Any], let path = args["path"] as? String {
            do {
              let values = try FileManager.default.attributesOfFileSystem(forPath: path)
              result((values[.systemFreeSize] as? NSNumber)?.int64Value)
            } catch {
              result(FlutterError(code: "storage_unavailable", message: "Available storage could not be read.", details: nil))
            }
          } else {
            result(FlutterMethodNotImplemented)
          }
        }
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RaftSharingBridge") {
      RaftSharingBridge.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RaftProxyBridge") {
      RaftProxyBridge.register(with: registrar)
    }
  }
}
