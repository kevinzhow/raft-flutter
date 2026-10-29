import Foundation

/// A separate extension process publishes a complete envelope with one rename.
/// Runner uses the same format as IncomingShareInbox; no credentials enter here.
final class ShareInboxWriter {
  static let maxItemBytes = 25 * 1024 * 1024
  static let maxTotalBytes = 100 * 1024 * 1024
  static let maxFiles = 9
  enum Failure: Error { case cancelled, invalidFile, tooLarge, tooMany, invalidText, empty }
  let root: URL
  let token = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
  private let lock = NSLock()
  private let cancelLock = NSLock()
  private var cancellationRequested = false
  private var isCancelled: Bool {
    cancelLock.lock(); defer { cancelLock.unlock() }
    return cancellationRequested
  }
  private let folder: URL
  private var files: [[String: Any]] = []
  private var total = 0
  private var finished = false

  init(root: URL) throws {
    self.root = root
    folder = root.appendingPathComponent(".staging-" + token, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
    var protected = folder
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try protected.setResourceValues(values)
  }

  static func directory(group: String) throws -> URL {
    guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
    else { throw Failure.invalidFile }
    var root = container.appendingPathComponent("raft-incoming", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true,
      attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try root.setResourceValues(values)
    try reapOrphanStaging(in: root)
    return root
  }

  static func reapOrphanStaging(in root: URL, now: Date = Date()) throws {
    for entry in try FileManager.default.contentsOfDirectory(at: root,
        includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey]) {
      guard entry.lastPathComponent.range(of: "^\\.staging-[a-f0-9]{32}$", options: .regularExpression) != nil,
            let values = try? entry.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey]),
            values.isDirectory == true, values.isSymbolicLink != true,
            let modified = values.contentModificationDate,
            now.timeIntervalSince(modified) > 24 * 60 * 60 else { continue }
      try? FileManager.default.removeItem(at: entry)
    }
  }

  // Open while the NSItemProvider callback still owns its temporary URL.
  // The descriptor stays valid even if the provider removes that pathname.
  final class Input {
    let handle: FileHandle
    init(_ source: URL) throws {
      let values = try source.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
      guard source.isFileURL, values.isRegularFile == true, values.isSymbolicLink != true
      else { throw Failure.invalidFile }
      if (values.fileSize ?? 0) > ShareInboxWriter.maxItemBytes { throw Failure.tooLarge }
      handle = try FileHandle(forReadingFrom: source)
    }
    deinit { try? handle.close() }
  }

  func addFile(_ source: URL, filename: String, mimeType: String) throws {
    try addFile(Input(source), filename: filename, mimeType: mimeType)
  }

  func addFile(_ input: Input, filename: String, mimeType: String) throws {
    lock.lock(); defer { lock.unlock() }
    guard !finished, !isCancelled else { throw Failure.cancelled }
    guard files.count < Self.maxFiles else { throw Failure.tooMany }
    let name = "item-\(files.count)"
    let destination = folder.appendingPathComponent(name)
    guard FileManager.default.createFile(atPath: destination.path, contents: nil,
      attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
    else { throw Failure.invalidFile }
    let output = try FileHandle(forWritingTo: destination)
    defer { try? input.handle.close(); try? output.close() }
    var size = 0
    do {
      while let data = try input.handle.read(upToCount: 64 * 1024), !data.isEmpty {
        guard !isCancelled else { throw Failure.cancelled }
        size += data.count
        guard size <= Self.maxItemBytes, total + size <= Self.maxTotalBytes else { throw Failure.tooLarge }
        try output.write(contentsOf: data)
      }
      guard !isCancelled else { throw Failure.cancelled }
      guard size > 0 else { throw Failure.invalidFile }
      try output.synchronize()
    } catch {
      try? FileManager.default.removeItem(at: destination)
      if isCancelled {
        finished = true
        try? FileManager.default.removeItem(at: folder)
      }
      throw error
    }
    total += size
    let basename = (filename.replacingOccurrences(of: "\\", with: "/") as NSString).lastPathComponent
    let safe = String(String.UnicodeScalarView(basename.unicodeScalars.map {
      $0.value < 32 || $0.value == 127 ? UnicodeScalar(95)! : $0
    }))
    let displayName = safe.isEmpty || safe == "." || safe == ".." ? "attachment" : String(safe.prefix(200))
    files.append(["file": name, "filename": displayName,
                  "mimeType": mimeType, "sizeBytes": size])
  }

  struct PreparedFile {
    let url: URL
    let name: String
    let size: Int
  }
  /// A private, unpublished snapshot for the extension's explicit Send action.
  /// The copied files keep their staged lifetime until completion/cancellation.
  func preparedFiles() throws -> [PreparedFile] {
    lock.lock(); defer { lock.unlock() }
    guard !finished, !isCancelled else { throw Failure.cancelled }
    return try files.map { row in
      guard let file = row["file"] as? String, let name = row["filename"] as? String,
            let size = row["sizeBytes"] as? Int else { throw Failure.invalidFile }
      return PreparedFile(url: folder.appendingPathComponent(file), name: name, size: size)
    }
  }

  func commit(text: String?) throws -> String {
    lock.lock(); defer { lock.unlock() }
    guard !finished, !isCancelled else { throw Failure.cancelled }
    guard (text?.utf16.count ?? 0) <= 65536, !Self.unsafeText(text ?? "") else { throw Failure.invalidText }
    guard !files.isEmpty || !(text ?? "").isEmpty else { throw Failure.empty }
    let record: [String: Any] = ["token": token, "created": Int64(Date().timeIntervalSince1970 * 1000),
      "pending": true, "text": text.map { $0 as Any } ?? NSNull(), "files": files]
    let data = try JSONSerialization.data(withJSONObject: record)
    try data.write(to: folder.appendingPathComponent("envelope.json"), options: .atomic)
    guard !isCancelled else { throw Failure.cancelled }
    try FileManager.default.moveItem(at: folder, to: root.appendingPathComponent(token))
    finished = true
    return token
  }

  /// Match path_provider's iOS temporary-directory policy (Library/Caches),
  /// accepting the system /var alias without accepting links outside the lease.
  static func exportFile(path: String, caches: URL) -> URL? {
    let original = URL(fileURLWithPath: path).standardizedFileURL
    let allowed = caches.appendingPathComponent("raft-share").resolvingSymlinksInPath().standardizedFileURL
    let file = original.resolvingSymlinksInPath().standardizedFileURL
    let parts = file.pathComponents
    guard let values = try? original.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
          values.isRegularFile == true, values.isSymbolicLink != true,
          parts.starts(with: allowed.pathComponents), parts.count == allowed.pathComponents.count + 2,
          file.deletingLastPathComponent().lastPathComponent.hasPrefix("share-") else { return nil }
    return file
  }

  // Match the ordinary app's pre-staging credential-link rejection. These
  // values must never be written to the durable extension inbox.
  static func unsafeText(_ text: String) -> Bool {
    if text.range(of: "raft://oauth(?:/|\\?|$)", options: [.regularExpression, .caseInsensitive]) != nil { return true }
    let regex = try! NSRegularExpression(pattern: "https?://[^\\s]+")
    let sensitive = try! NSRegularExpression(pattern: "^(token|access_token|refresh_token|signature|x-amz-.+|oauth_code)$", options: .caseInsensitive)
    for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
      guard let range = Range(match.range, in: text), let parts = URLComponents(string: String(text[range])),
            parts.user == nil, parts.password == nil else { return true }
      if (parts.queryItems ?? []).contains(where: {
        sensitive.firstMatch(in: $0.name, range: NSRange($0.name.startIndex..., in: $0.name)) != nil
      }) { return true }
    }
    return false
  }

  func cancel() {
    cancelLock.lock(); cancellationRequested = true; cancelLock.unlock()
    // A running copy observes cancellation between chunks and cleans up.
    // The extension's Cancel button never waits for file I/O on the UI thread.
    guard lock.try() else {
      DispatchQueue.global(qos: .utility).async {
        self.lock.lock(); defer { self.lock.unlock() }
        guard !self.finished else { return }
        self.finished = true
        try? FileManager.default.removeItem(at: self.folder)
      }
      return
    }
    defer { lock.unlock() }
    guard !finished else { return }
    finished = true
    try? FileManager.default.removeItem(at: folder)
  }
  deinit { cancel() }
}
