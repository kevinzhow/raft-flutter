import Foundation

final class FixtureVault: ShareSessionReading {
  var value: ShareAccessSession?
  init(_ value: ShareAccessSession?) { self.value = value }
  func read() throws -> ShareAccessSession? { value }
}
final class FixtureAPI {
  var calls: [URLRequest] = []
  var uploads: [Data] = []
  var posts: [[String: Any]] = []
  var failPosts = 0
  var limit = 1024
  var user = "alice"
  var role = "member"
  var channel: [String: Any] = ["id": "c1", "name": "Channel", "joined": true]
  var afterResponse: (() -> Void)?
  func run(_ request: URLRequest, _ file: URL?) async throws -> (Data, Int) {
    calls.append(request)
    let path = request.url!.path
    var result: Any = [:]
    var status = 200
    switch path {
    case "/api/auth/me": result = ["id": user]
    case "/api/servers": result = [["id": "s1", "name": "Workspace", "role": role]]
    case "/api/channels": result = [channel, ["id": "archived", "name": "Old", "joined": true, "archivedAt": "now"]]
    case "/api/channels/dm": result = [["id": "d1", "type": "dm", "name": "", "peerName": "Alice", "peerDisplayName": "Alice Display"]]
    case "/api/channels/c1": result = channel
    case "/api/attachments/upload-capabilities": result = ["maxBytes": limit]
    case "/api/attachments/upload":
      guard let file else { fatalError("upload must use disk stream") }
      uploads.append(try Data(contentsOf: file)); result = ["attachments": [["id": "a1"]]]
    case "/api/v2/messages":
      posts.append(try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any])
      if failPosts > 0 { failPosts -= 1; status = 503 }
      result = ["id": "m1"]
    default: fatalError("Unexpected mounted API \(path)")
    }
    afterResponse?()
    return (try JSONSerialization.data(withJSONObject: result), status)
  }
}

@main struct ShareComposeChecks {
  static var checks = 0
  static func require(_ condition: @autoclosure () -> Bool, _ label: String) {
    guard condition() else { fatalError(label) }
    checks += 1
  }
  static func access(principal: String = "alice", token: String = "fixture-access", preferred: String = "s1", expires: Int64? = nil) -> ShareAccessSession {
    ShareAccessSession(identifier: UUID().uuidString, origin: "https://fixture.invalid", principal: principal, name: "Alice", accessToken: token,
      expiresAt: expires ?? Int64(Date().addingTimeInterval(3600).timeIntervalSince1970 * 1000), preferredServerId: preferred)
  }
  static func rejects(_ expected: ShareComposeFailure, _ run: () async throws -> Void) async {
    do { try await run(); fatalError("Expected \(expected)") }
    catch { require(error as? ShareComposeFailure == expected, "Wrong failure: \(error)") }
  }
  static func main() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("raft-share-compose-fixture-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let original = access(), vault = FixtureVault(access())
    let client = ShareComposeClient(access: original, vault: vault), api = FixtureAPI()
    client.transport = api.run
    let destination = ShareDestination(serverId: "s1", channelId: "c1", name: "Channel")
    let servers = try await client.servers()
    require(servers.count == 1, "server membership")
    let channels = try await client.channels(server: "s1")
    require(channels.map { $0.channelId } == ["c1", "d1"], "joined channels and DMs only")
    require(channels.last?.name == "Alice Display", "DM display name, empty internal name")
    require(api.posts.isEmpty && api.uploads.isEmpty, "opening compose never sends")
    vault.value = access(token: "fixture-rotated", preferred: "s2")
    _ = try await client.servers()
    require(api.calls.last?.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-rotated", "same account rotation uses current token")
    vault.value = access(principal: "bob")
    let count = api.calls.count
    await rejects(.signIn) { _ = try await client.servers() }
    require(api.calls.count == count, "account switch blocks request")
    vault.value = nil
    await rejects(.signIn) { _ = try await client.servers() }
    vault.value = access(expires: 1)
    await rejects(.signIn) { _ = try await client.servers() }
    vault.value = access()
    api.afterResponse = { vault.value = nil }
    await rejects(.signIn) { _ = try await client.servers() }
    api.afterResponse = nil; vault.value = access()
    api.user = "bob"
    await rejects(.signIn) { try await client.send(to: destination, text: "hello", files: []) }
    require(api.posts.isEmpty, "identity response mismatch blocks post")
    api.user = "alice"; api.role = "removed"
    await rejects(.unavailable) { try await client.send(to: destination, text: "hello", files: []) }
    api.role = "member"; api.channel["archived"] = true
    await rejects(.unavailable) { try await client.send(to: destination, text: "hello", files: []) }
    api.channel["archived"] = nil
    api.channel["conversionState"] = ["status": "pending", "command": ["id": "k1", "kind": "start", "status": "pending"]]
    await rejects(.unavailable) { try await client.send(to: destination, text: "hello", files: []) }
    api.channel["conversionState"] = NSNull()
    require(ShareComposeClient.eligible(api.channel), "null conversion state means no fence")
    require(!ShareComposeClient.eligible(["type": "dm", "conversionState": ["status": "unknown"]]), "malformed conversion fenced")
    await rejects(.invalidContent) { try await client.send(to: destination, text: "  ", files: []) }
    await rejects(.invalidContent) { try await client.send(to: destination, text: String(repeating: "x", count: 65537), files: []) }
    let writer = try ShareInboxWriter(root: root.appendingPathComponent("inbox"))
    defer { writer.cancel() }
    let file = root.appendingPathComponent("sample.png")
    let bytes = Data([0, 1, 2, 255, 10, 13, 65])
    try bytes.write(to: file)
    try writer.addFile(file, filename: "sample.png", mimeType: "image/png")
    let prepared = try writer.preparedFiles()
    api.limit = 1
    await rejects(.upload) { try await client.send(to: destination, text: "hello", files: prepared) }
    require(api.uploads.isEmpty, "server limit checked before upload")
    api.limit = 1024; api.failPosts = 1
    await rejects(.unavailable) { try await client.send(to: destination, text: "hello", files: prepared) }
    require(api.uploads.count == 1, "one upload")
    require(api.uploads[0].range(of: bytes) != nil, "multipart preserves exact binary bytes")
    require(String(decoding: api.uploads[0], as: UTF8.self).contains("name=\"channelId\"\r\n\r\nc1"), "multipart channel contract")
    let firstId = api.posts.last!["randomId"] as! String
    try await client.send(to: destination, text: "hello", files: prepared)
    require(api.uploads.count == 1, "retry reuses uploaded attachment")
    require(api.posts.last!["randomId"] as? String == firstId, "retry uses same message randomId")
    require(api.posts.last!["attachmentIds"] as? [String] == ["a1"], "attachment message DTO")
    try await client.send(to: destination, text: "edited", files: prepared)
    require(api.posts.last!["randomId"] as? String != firstId, "edited message gets new identity")
    require(api.calls.filter { $0.url?.path != "/api/auth/me" && $0.url?.path != "/api/servers" }.allSatisfy { $0.value(forHTTPHeaderField: "X-Server-Id") == "s1" }, "explicit destination server remains selected")
    let remaining = try FileManager.default.contentsOfDirectory(atPath: prepared[0].url.deletingLastPathComponent().path)
    require(!remaining.contains { $0.hasPrefix(".upload-") }, "temporary multipart removed")
    client.cancel()
    await rejects(.cancelled) { try await client.send(to: destination, text: "hello", files: []) }
    print("native compose checks passed: \(checks)")
  }
}
