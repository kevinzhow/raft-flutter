import Foundation

struct ShareDestination: Equatable {
  let serverId: String
  let channelId: String
  let name: String
}

/// Uses the same mounted human endpoints as RaftClient. The extension never
/// rotates refresh credentials or automatically submits shared content.
final class ShareComposeClient: NSObject, URLSessionTaskDelegate {
  let access: ShareAccessSession
  let vault: ShareSessionReading
  private let stateLock = NSLock()
  private var _cancelled = false
  private var randomId = UUID().uuidString
  private var attempt: String?
  private var attachments: [String] = []
  private var uploadedTarget: String?
  private var network: URLSession?
  private func session() -> URLSession {
    stateLock.lock(); defer { stateLock.unlock() }
    if let network { return network }
    let config = URLSessionConfiguration.ephemeral
    config.timeoutIntervalForRequest = 30
    config.timeoutIntervalForResource = 120
    config.httpShouldSetCookies = false
    config.urlCache = nil
    let created = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    network = created
    return created
  }
  private var cancelled: Bool {
    stateLock.lock(); defer { stateLock.unlock() }; return _cancelled
  }

  // Test seam runs against local DTOs and temporary files, never a real account.
  var transport: ((URLRequest, URL?) async throws -> (Data, Int))?
  init(access: ShareAccessSession, vault: ShareSessionReading) {
    self.access = access; self.vault = vault
  }
  private func currentAccess() throws -> ShareAccessSession {
    guard !cancelled else { throw ShareComposeFailure.cancelled }
    guard let latest = try vault.read(), latest.valid(),
          latest.origin == access.origin, latest.principal == access.principal else {
      throw ShareComposeFailure.signIn
    }
    return latest
  }
  func check() throws { _ = try currentAccess() }
  func cancel() {
    stateLock.lock(); _cancelled = true; let current = network; stateLock.unlock()
    current?.invalidateAndCancel()
  }
  deinit { network?.invalidateAndCancel() }

  func urlSession(_ session: URLSession, task: URLSessionTask,
                  willPerformHTTPRedirection response: HTTPURLResponse,
                  newRequest request: URLRequest,
                  completionHandler: @escaping (URLRequest?) -> Void) {
    // Credential-bearing requests never follow a redirect to another host.
    completionHandler(nil)
  }

  private func request(_ path: String, server: String? = nil, method: String = "GET",
                       json: [String: Any]? = nil, file: URL? = nil,
                       contentType: String? = nil) async throws -> Any {
    let credential = try currentAccess()
    guard let origin = URLComponents(string: credential.origin), origin.scheme == "https",
          origin.host?.isEmpty == false, origin.user == nil, origin.password == nil,
          let url = URL(string: credential.origin + "/api" + path) else { throw ShareComposeFailure.signIn }
    var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
    request.httpMethod = method
    request.setValue("Bearer " + credential.accessToken, forHTTPHeaderField: "Authorization")
    if let server {
      guard Self.validID(server) else { throw ShareComposeFailure.unavailable }
      request.setValue(server, forHTTPHeaderField: "X-Server-Id")
    }
    if let json {
      request.httpBody = try JSONSerialization.data(withJSONObject: json)
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    if let contentType { request.setValue(contentType, forHTTPHeaderField: "Content-Type") }
    let data: Data, status: Int
    if let transport {
      (data, status) = try await transport(request, file)
    } else {
      let response: URLResponse
      if let file { (data, response) = try await session().upload(for: request, fromFile: file) }
      else { (data, response) = try await session().data(for: request) }
      status = (response as? HTTPURLResponse)?.statusCode ?? 0
    }
    try check()
    if status == 401 { throw ShareComposeFailure.signIn }
    guard (200...299).contains(status), data.count <= 4 * 1024 * 1024 else { throw ShareComposeFailure.unavailable }
    return try JSONSerialization.jsonObject(with: data)
  }

  static func validID(_ value: String) -> Bool {
    value.range(of: "^[A-Za-z0-9_-]{1,200}$", options: .regularExpression) != nil
  }

  func servers() async throws -> [[String: Any]] {
    let me = try await request("/auth/me")
    guard let user = me as? [String: Any], (user["id"] as? String) == access.principal,
          let rows = try await request("/servers") as? [[String: Any]] else { throw ShareComposeFailure.signIn }
    return rows.filter { Self.validID($0["id"] as? String ?? "") && ($0["name"] as? String)?.isEmpty == false && ["owner", "admin", "member", "guest"].contains($0["role"] as? String ?? "") }
  }

  func channels(server: String) async throws -> [ShareDestination] {
    let channels = try await request("/channels?archived=include", server: server) as? [[String: Any]] ?? []
    let dms = try await request("/channels/dm", server: server) as? [[String: Any]] ?? []
    return (channels + dms).compactMap { row in
      guard let id = row["id"] as? String, Self.validID(id), eligible(row),
            let name = Self.destinationName(row) else { return nil }
      return ShareDestination(serverId: server, channelId: id, name: name)
    }
  }

  static func destinationName(_ row: [String: Any]) -> String? {
    let fields = row["type"] as? String == "dm" ? ["peerDisplayName", "peerName", "name"] : ["name"]
    return fields.compactMap { row[$0] as? String }.first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
  }

  static func eligible(_ row: [String: Any]) -> Bool {
    let archived = row["archivedAt"] != nil && !(row["archivedAt"] is NSNull)
    let membership = row["membership"] != nil && !(row["membership"] is NSNull)
    let joined = row["type"] as? String == "dm" || row["joined"] as? Bool == true ||
      row["isJoined"] as? Bool == true || membership
    return !archived && row["archived"] as? Bool != true && joined && !conversionBlocked(row)
  }
  // Port of raft_client/channel_conversion.dart's durable sending fence.
  static func conversionBlocked(_ row: [String: Any]) -> Bool {
    let nested = row["channel"] as? [String: Any] ?? [:]
    let raw = row["conversionState"] ?? nested["conversionState"]
    let canonical = raw is NSNull ? nil : raw
    let state = canonical as? [String: Any] ?? [:]
    let command = (canonical != nil ? state["command"] : row["conversionCommand"] ?? nested["conversionCommand"]) as? [String: Any] ?? [:]
    let job = (canonical != nil ? state["job"] : row["conversionJob"] ?? nested["conversionJob"]) as? [String: Any] ?? [:]
    if !command.isEmpty && (command["id"] as? String == nil ||
        !["pending", "completed", "failed"].contains(command["status"] as? String ?? "") ||
        !["start", "retry", "cancel"].contains(command["kind"] as? String ?? "")) { return true }
    if !job.isEmpty && (job["id"] as? String == nil || job["phase"] as? String == nil ||
        !["pending", "running", "failed", "done", "canceled"].contains(job["status"] as? String ?? "") ||
        (job["canCancel"] != nil && !(job["canCancel"] is Bool))) { return true }
    let commandStatus = command["status"] as? String
    let jobStatus = job["status"] as? String
    let expected = commandStatus == "pending" ? "pending" :
      (!job.isEmpty ? (jobStatus == "pending" ? "running" : jobStatus ?? "") :
        (commandStatus == "failed" ? "failed" : "idle"))
    let status = canonical != nil ? state["status"] as? String ?? "" : expected
    guard status == expected, ["idle", "pending", "running", "failed", "done", "canceled"].contains(status),
      !(status == "pending" && command.isEmpty),
      !(["running", "done", "canceled"].contains(status) && job.isEmpty) else { return true }
    if status == "pending" { return true }
    if jobStatus == "failed", (job["progress"] as? [String: Any])?["rollbackState"] as? String == "restored" { return false }
    return ["pending", "running", "failed"].contains(jobStatus ?? "")
  }
  private func eligible(_ row: [String: Any]) -> Bool { Self.eligible(row) }

  func send(to destination: ShareDestination, text: String,
            files: [ShareInboxWriter.PreparedFile], randomId suppliedId: String? = nil) async throws {
    try check()
    guard Self.validID(destination.serverId), Self.validID(destination.channelId) else { throw ShareComposeFailure.unavailable }
    guard text.utf16.count <= 65536, !ShareInboxWriter.unsafeText(text),
          !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !files.isEmpty else {
      throw ShareComposeFailure.invalidContent
    }
    // Revalidate membership and destination immediately before uploading/send.
    let member = try await servers().contains { ($0["id"] as? String) == destination.serverId }
    guard member else { throw ShareComposeFailure.unavailable }
    let id = destination.channelId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#")))!
    guard let channel = try await request("/channels/" + id, server: destination.serverId) as? [String: Any],
          channel["id"] as? String == destination.channelId, eligible(channel) else { throw ShareComposeFailure.unavailable }
    let target = destination.serverId + ":" + destination.channelId
    if uploadedTarget != target { attachments = []; uploadedTarget = target }
    if !files.isEmpty {
      let capabilities = try await request("/attachments/upload-capabilities", server: destination.serverId) as? [String: Any]
      guard let limit = capabilities?["maxBytes"] as? NSNumber, limit.intValue > 0,
            files.count <= ShareInboxWriter.maxFiles,
            files.allSatisfy({ $0.size > 0 && $0.size <= min(limit.intValue, ShareInboxWriter.maxItemBytes) }) else {
        throw ShareComposeFailure.upload
      }
      for file in files.dropFirst(attachments.count) {
        try check()
        let boundary = "RaftShare-" + UUID().uuidString
        let body = try Self.multipart(file, channel: destination.channelId, boundary: boundary)
        defer { try? FileManager.default.removeItem(at: body) }
        let uploaded = try await request("/attachments/upload", server: destination.serverId,
          method: "POST", file: body, contentType: "multipart/form-data; boundary=" + boundary) as? [String: Any]
        guard let result = uploaded?["attachments"] as? [[String: Any]], result.count == 1,
              let id = result.first?["id"] as? String, !id.isEmpty else { throw ShareComposeFailure.upload }
        attachments.append(id)
      }
    }
    let fingerprint = destination.serverId + ":" + destination.channelId + ":" + text + ":" + attachments.joined(separator: ",")
    if attempt != fingerprint { randomId = suppliedId ?? UUID().uuidString; attempt = fingerprint }
    _ = try await request("/v2/messages", server: destination.serverId, method: "POST",
      json: ["channelId": destination.channelId, "content": text,
        "attachmentIds": attachments, "randomId": randomId])
  }

  static func multipart(_ file: ShareInboxWriter.PreparedFile, channel: String,
                        boundary: String) throws -> URL {
    let body = file.url.deletingLastPathComponent().appendingPathComponent(".upload-" + UUID().uuidString)
    guard FileManager.default.createFile(atPath: body.path, contents: nil,
      attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]) else { throw ShareComposeFailure.upload }
    let output = try FileHandle(forWritingTo: body)
    let input = try ShareInboxWriter.Input(file.url)
    defer { try? output.close(); try? input.handle.close() }
    do {
      let filename = file.name.replacingOccurrences(of: "\"", with: "_")
      let prefix = "--\(boundary)\r\nContent-Disposition: form-data; name=\"channelId\"\r\n\r\n\(channel)\r\n--\(boundary)\r\nContent-Disposition: form-data; name=\"files\"; filename=\"\(filename)\"\r\nContent-Type: application/octet-stream\r\n\r\n"
      try output.write(contentsOf: Data(prefix.utf8))
      var count = 0
      while let data = try input.handle.read(upToCount: 64 * 1024), !data.isEmpty {
        count += data.count
        guard count <= file.size, count <= ShareInboxWriter.maxItemBytes else { throw ShareComposeFailure.upload }
        try output.write(contentsOf: data)
      }
      guard count == file.size else { throw ShareComposeFailure.upload }
      try output.write(contentsOf: Data("\r\n--\(boundary)--\r\n".utf8))
      try output.synchronize()
      return body
    } catch { try? FileManager.default.removeItem(at: body); throw error }
  }
}
