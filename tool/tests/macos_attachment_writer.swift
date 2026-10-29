import Foundation

@main
struct AttachmentWriterTests {
  static func attribute(_ path: URL) -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
    process.arguments = ["-p", "com.apple.quarantine", path.path]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()
    try! process.run()
    process.waitUntilExit()
    return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
  }

  static func seedQuarantine(_ path: URL) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
    process.arguments = ["-w", "com.apple.quarantine", "0086;00000000;RaftFixture;", path.path]
    try process.run()
    process.waitUntilExit()
    precondition(process.terminationStatus == 0)
  }

  static func main() throws {
    let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    let source = directory.appendingPathComponent("cached.zip")
    let destination = directory.appendingPathComponent("selected.zip")
    let bytes = Data("complete attachment 日本語".utf8)
    try bytes.write(to: source)
    try seedQuarantine(source)
    let sourceAttributes = attribute(source)

    // Old metadata-preserving copy is a positive control for this fixture.
    let legacy = directory.appendingPathComponent("legacy.zip")
    try FileManager.default.copyItem(at: source, to: legacy)
    precondition(attribute(legacy).hasPrefix("0086;"))
    try AttachmentFileWriter.write(source: source, destination: destination)
    precondition(try! Data(contentsOf: destination) == bytes)
    precondition(!attribute(destination).hasPrefix("0086;"), "Private sandbox flags reached the chosen destination")
    precondition(attribute(source) == sourceAttributes, "The cache must stay read-only")
    print("new destination: passed")

    try seedQuarantine(destination)
    try AttachmentFileWriter.write(source: source, destination: destination)
    precondition(try! Data(contentsOf: destination) == bytes)
    precondition(!attribute(destination).hasPrefix("0086;"), "Replacement retained stale private sandbox flags")
    print("existing destination metadata: passed")

    do {
      try AttachmentFileWriter.write(source: directory.appendingPathComponent("missing"), destination: destination)
      preconditionFailure("Missing source must fail")
    } catch {}
    precondition(try! Data(contentsOf: destination) == bytes, "A failed read damaged the selected file")
    print("failed read preserves destination: passed")

    let folder = directory.appendingPathComponent("folder", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
    let existing = folder.appendingPathComponent("keep.txt")
    try bytes.write(to: existing)
    do {
      try AttachmentFileWriter.write(source: source, destination: folder)
      preconditionFailure("Cannot replace a directory with attachment bytes")
    } catch {}
    precondition(try! Data(contentsOf: existing) == bytes)
    print("failed publication preserves destination: passed")

    let empty = directory.appendingPathComponent("empty")
    try Data().write(to: empty)
    try AttachmentFileWriter.write(source: empty, destination: destination)
    precondition(try! Data(contentsOf: destination).isEmpty)
    print("empty attachment: passed")
    print("5 cases, 0 failed assertions")
  }
}
