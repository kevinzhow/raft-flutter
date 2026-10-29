import Flutter
import UIKit

func raftFoldSnapshot(status: String, regions: [[AnyHashable: Any]], size: CGSize) -> NSDictionary {
  return ["hinge": status, "regions": regions,
          "viewWidth": Double(size.width), "viewHeight": Double(size.height)]
}

func raftFoldSnapshotChanged(_ snapshot: NSDictionary, from previous: NSDictionary?) -> Bool {
  return previous == nil || !snapshot.isEqual(previous)
}

func raftFoldStatusChanged(_ status: String, from previous: String) -> Bool {
  return status != previous
}

protocol RaftFoldMonitoring {
  func readRegions() -> [[AnyHashable: Any]]
  func invalidate()
}

extension RaftFoldMonitor: RaftFoldMonitoring {}

final class RaftFoldBridge: NSObject, FlutterPlugin, FlutterStreamHandler {
  static let shared = RaftFoldBridge()
  weak var controller: FlutterViewController?
  private var sink: FlutterEventSink?
  private var monitor: RaftFoldMonitoring?
  private var monitoringStarted = false
  private var status = "none"
  private var lastSnapshot: NSDictionary?
  // Injectable lifecycle hooks let RunnerTests exercise cancellation without UIKit hinge hardware.
  var makeMonitor: (UIView, @escaping (String) -> Void) -> RaftFoldMonitoring? = {
    RaftFoldMonitor(view: $0, onHinge: $1)
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let bridge = shared
    if let controller = registrar.viewController as? FlutterViewController {
      bridge.controller = controller
    }
    FlutterEventChannel(name: "app.raft/display-folds", binaryMessenger: registrar.messenger())
      .setStreamHandler(bridge)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    stop()
    sink = events
    if let controller {
      startMonitoring(controller)
      controller.view.setNeedsLayout()
    }
    return nil
  }

  private func startMonitoring(_ controller: FlutterViewController) {
    guard !monitoringStarted else { return }
    monitoringStarted = true
    monitor = makeMonitor(controller.view) { [weak self] status in
      self?.hingeUpdated(status)
    }
  }

  func hingeUpdated(_ next: String) {
    guard sink != nil, raftFoldStatusChanged(next, from: status) else { return }
    status = next
    controller?.view.setNeedsLayout()
  }

  func layoutPassed(_ controller: FlutterViewController) {
    // Remember the view even before listening; UIKit may already have laid it out
    // when the implicit engine registers a registrar without a view controller.
    if self.controller == nil { self.controller = controller }
    guard sink != nil, self.controller === controller else { return }
    startMonitoring(controller)
    let snapshot = raftFoldSnapshot(
      status: status, regions: monitor?.readRegions() ?? [], size: controller.view.bounds.size)
    if raftFoldSnapshotChanged(snapshot, from: lastSnapshot) {
      lastSnapshot = snapshot
      sink?(snapshot)
    }
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stop()
    return nil
  }

  private func stop() {
    monitor?.invalidate()
    monitor = nil
    monitoringStarted = false
    sink = nil
    status = "none"
    lastSnapshot = nil
  }
}
