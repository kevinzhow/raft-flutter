import Foundation
import FlutterMacOS

final class AttachmentFilesChannel {
  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "app.raft/attachment-files", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "writeSaved" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let args = call.arguments as? [String: Any],
        let path = args["path"] as? String, path.hasPrefix("/"),
        let destination = args["uri"] as? String, destination.hasPrefix("/") else {
        result(FlutterError(code: "invalid", message: "Missing local attachment paths.", details: nil))
        return
      }
      DispatchQueue.global(qos: .utility).async {
        do {
          try AttachmentFileWriter.write(
            source: URL(fileURLWithPath: path), destination: URL(fileURLWithPath: destination))
          DispatchQueue.main.async { result(nil) }
        } catch {
          // Paths can carry private filenames; never expose them in diagnostics.
          DispatchQueue.main.async {
            result(FlutterError(code: "save_failed", message: "The attachment could not be saved.", details: nil))
          }
        }
      }
    }
  }
}
