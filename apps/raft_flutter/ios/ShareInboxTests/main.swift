import Foundation

let root = FileManager.default.temporaryDirectory.appendingPathComponent("raft-ios-inbox-test-" + UUID().uuidString)
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: root) }
let inbox = root.appendingPathComponent("inbox")
let source = root.appendingPathComponent("source.png")
try Data([1, 2, 3, 4]).write(to: source)
var passed = 0
func check(_ condition: Bool, _ message: String) {
  precondition(condition, message)
  passed += 1
}
func rejected(_ work: () throws -> Void) {
  do { try work(); preconditionFailure("Expected rejection") } catch { passed += 1 }
}
func children() throws -> [URL] { try FileManager.default.contentsOfDirectory(at: inbox, includingPropertiesForKeys: nil) }
let first = try ShareInboxWriter(root: inbox)
try first.addFile(source, filename: "../../photo.png", mimeType: "image/png")
check(try children().allSatisfy { $0.lastPathComponent.hasPrefix(".staging-") }, "Unconfirmed share became visible")
let token = try first.commit(text: "https://example.test/page")
let data = try Data(contentsOf: inbox.appendingPathComponent(token).appendingPathComponent("envelope.json"))
let record = try JSONSerialization.jsonObject(with: data) as! [String: Any]
check(record["pending"] as? Bool == true, "Share not pending")
check(record["token"] as? String == token, "Token mismatch")
let files = record["files"] as! [[String: Any]]
check(files[0]["file"] as? String == "item-0", "Opaque filename required")
check(files[0]["filename"] as? String == "photo.png", "Filename escaped")
check(try Data(contentsOf: inbox.appendingPathComponent(token).appendingPathComponent("item-0")) == Data([1,2,3,4]), "File bytes changed")
let ephemeral = root.appendingPathComponent("provider-temporary")
try Data([5,6,7]).write(to: ephemeral)
let retained = try ShareInboxWriter.Input(ephemeral)
try FileManager.default.removeItem(at: ephemeral)
let lifetime = try ShareInboxWriter(root: inbox)
try lifetime.addFile(retained, filename: "temporary", mimeType: "application/octet-stream")
let lifetimeToken = try lifetime.commit(text: nil)
check(try Data(contentsOf: inbox.appendingPathComponent(lifetimeToken).appendingPathComponent("item-0")) == Data([5,6,7]), "Provider callback lifetime lost bytes")
try FileManager.default.removeItem(at: inbox.appendingPathComponent(lifetimeToken))
let names = try ShareInboxWriter(root: inbox)
try names.addFile(source, filename: "..\\..\\line\r\n.png", mimeType: "image/png")
let namesToken = try names.commit(text: nil)
let namesData = try Data(contentsOf: inbox.appendingPathComponent(namesToken).appendingPathComponent("envelope.json"))
let namesRecord = try JSONSerialization.jsonObject(with: namesData) as! [String: Any]
check((namesRecord["files"] as! [[String: Any]])[0]["filename"] as? String == "line__.png", "Controls or Windows path entered a draft filename")
try FileManager.default.removeItem(at: inbox.appendingPathComponent(namesToken))
let second = try ShareInboxWriter(root: inbox)
let secondToken = try second.commit(text: "Another share")
check(secondToken != token, "Shares overwrite one another")
check(try children().filter { !$0.lastPathComponent.hasPrefix(".") }.count == 2, "Lost a committed share")
let cancelled = try ShareInboxWriter(root: inbox)
try cancelled.addFile(source, filename: "cancel.png", mimeType: "image/png")
cancelled.cancel()
rejected { _ = try cancelled.commit(text: "Cancelled") }
check(try children().count == 2, "Cancel leaked staging data")
let linked = root.appendingPathComponent("link")
try FileManager.default.createSymbolicLink(at: linked, withDestinationURL: source)
let bounds = try ShareInboxWriter(root: inbox)
rejected { try bounds.addFile(linked, filename: "link", mimeType: "image/png") }
let oversized = root.appendingPathComponent("large")
_ = FileManager.default.createFile(atPath: oversized.path, contents: Data())
let handle = try FileHandle(forWritingTo: oversized)
try handle.truncate(atOffset: UInt64(ShareInboxWriter.maxItemBytes + 1)); try handle.close()
rejected { try bounds.addFile(oversized, filename: "large", mimeType: "application/octet-stream") }
for _ in 0..<9 { try bounds.addFile(source, filename: "x", mimeType: "image/png") }
rejected { try bounds.addFile(source, filename: "tenth", mimeType: "image/png") }
bounds.cancel()
for text in [String(repeating: "x", count: 65537), "raft://oauth/callback?code=x", "https://u:p@example.test/", "https://example.test/a?X-Amz-Signature=secret"] {
 let unsafe = try ShareInboxWriter(root: inbox)
 rejected { _ = try unsafe.commit(text: text) }
 unsafe.cancel()
}
let empty = try ShareInboxWriter(root: inbox)
rejected { _ = try empty.commit(text: nil) }; empty.cancel()
check(!ShareInboxWriter.unsafeText("https://example.test/voucher?code=ordinary"), "Ordinary URL rejected")
check(try children().count == 2, "Failure leaked a partial share")
let orphan = inbox.appendingPathComponent(".staging-" + String(repeating: "0", count: 32))
try FileManager.default.createDirectory(at: orphan, withIntermediateDirectories: false)
try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -25 * 60 * 60)], ofItemAtPath: orphan.path)
let currentStaging = try ShareInboxWriter(root: inbox)
try ShareInboxWriter.reapOrphanStaging(in: inbox)
check(!FileManager.default.fileExists(atPath: orphan.path), "Orphan staging not reaped")
check(try children().count == 3, "Reaper touched committed or current content")
currentStaging.cancel()
let caches = root.appendingPathComponent("Caches")
let lease = caches.appendingPathComponent("raft-share/share-1")
try FileManager.default.createDirectory(at: lease, withIntermediateDirectories: true)
let exported = lease.appendingPathComponent("image.png")
try Data([7,8,9]).write(to: exported)
check(ShareInboxWriter.exportFile(path: exported.path, caches: caches) != nil, "Valid cache export rejected")
let cacheAlias = root.appendingPathComponent("CachesAlias")
try FileManager.default.createSymbolicLink(at: cacheAlias, withDestinationURL: caches)
check(ShareInboxWriter.exportFile(path: cacheAlias.appendingPathComponent("raft-share/share-1/image.png").path, caches: caches) != nil, "System-style cache alias rejected")
check(ShareInboxWriter.exportFile(path: source.path, caches: caches) == nil, "Unrelated source admitted")
let escaping = lease.appendingPathComponent("escape")
try FileManager.default.createSymbolicLink(at: escaping, withDestinationURL: source)
check(ShareInboxWriter.exportFile(path: escaping.path, caches: caches) == nil, "File link escaped cache")
if CommandLine.arguments.count > 1 {
 let exported = URL(fileURLWithPath: CommandLine.arguments[1])
 let fixture = try ShareInboxWriter(root: exported)
 try fixture.addFile(source, filename: "../../photo.png", mimeType: "image/png")
 _ = try fixture.commit(text: "https://example.test/page")
}
print("\(passed) native inbox checks passed")
