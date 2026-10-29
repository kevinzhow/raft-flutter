import Flutter

@objc(RaftFlutterViewController)
class RaftFlutterViewController: FlutterViewController {
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    RaftFoldBridge.shared.layoutPassed(self)
  }
}
