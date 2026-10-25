import Foundation

/// Publish bytes into the NSSavePanel-selected file, rather than copying a
/// private cache file's metadata (including its sandbox quarantine flags).
/// Atomic replacement also discards stale metadata on an existing destination
/// and leaves that file intact if reading or writing fails. macOS still applies
/// its normal quarantine policy; this does not remove quarantine attributes.
enum AttachmentFileWriter {
  static func write(source: URL, destination: URL) throws {
    // Cached attachments are local files held by the caller until completion.
    // Mapping keeps large attachments out of a second in-memory byte buffer.
    let data = try Data(contentsOf: source, options: .alwaysMapped)
    try data.write(to: destination, options: .atomic)
  }
}
