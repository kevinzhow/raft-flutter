import Foundation
import Security

struct ShareAccessSession: Codable, Equatable {
  let identifier: String
  let origin: String
  let principal: String
  let name: String
  let accessToken: String
  let expiresAt: Int64
  let preferredServerId: String?

  static func parse(_ value: [String: Any], now: Date = Date()) throws -> Self {
    guard let origin = value["origin"] as? String,
          let parts = URLComponents(string: origin), parts.scheme == "https",
          parts.host?.isEmpty == false, parts.user == nil, parts.password == nil,
          parts.query == nil, parts.fragment == nil, parts.path.isEmpty || parts.path == "/",
          let principal = value["principal"] as? String, !principal.isEmpty, principal.count <= 200,
          let token = value["accessToken"] as? String, !token.isEmpty, token.utf8.count <= 16384,
          !token.contains("\n"), !token.contains("\r"),
          let expires = value["expiresAt"] as? NSNumber,
          expires.int64Value > Int64(now.timeIntervalSince1970 * 1000),
          expires.int64Value <= Int64(now.addingTimeInterval(24 * 3600 + 5).timeIntervalSince1970 * 1000)
    else { throw ShareComposeFailure.signIn }
    return Self(identifier: UUID().uuidString, origin: origin.trimmingCharacters(in: CharacterSet(charactersIn: "/")),
      principal: principal, name: String((value["name"] as? String ?? "").prefix(200)),
      accessToken: token, expiresAt: expires.int64Value,
      preferredServerId: value["preferredServerId"] as? String)
  }
  func valid(now: Date = Date()) -> Bool { expiresAt > Int64(now.timeIntervalSince1970 * 1000) }
}

protocol ShareSessionReading {
  func read() throws -> ShareAccessSession?
}

/// Explicit shared access group; the app's original default keychain group
/// remains first in entitlements so its existing login items do not migrate.
final class ShareSessionVault: ShareSessionReading {
  let accessGroup: String
  init(accessGroup: String) { self.accessGroup = accessGroup }
  private var query: [String: Any] { [kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "app.raft.share-access", kSecAttrAccount as String: "current",
    kSecAttrAccessGroup as String: accessGroup] }

  func replace(_ session: ShareAccessSession?) throws {
    if session == nil {
      let status = SecItemDelete(query as CFDictionary)
      guard status == errSecSuccess || status == errSecItemNotFound else { throw ShareComposeFailure.signIn }
      return
    }
    let data = try JSONEncoder().encode(session!)
    let updates = [kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly] as [String: Any]
    let updated = SecItemUpdate(query as CFDictionary, updates as CFDictionary)
    if updated == errSecItemNotFound {
      var item = query; updates.forEach { item[$0.key] = $0.value }
      guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw ShareComposeFailure.signIn }
    } else if updated != errSecSuccess { throw ShareComposeFailure.signIn }
  }
  func read() throws -> ShareAccessSession? {
    var item = query
    item[kSecReturnData as String] = true
    item[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    let status = SecItemCopyMatching(item as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, let data = result as? Data else { throw ShareComposeFailure.signIn }
    let value = try JSONDecoder().decode(ShareAccessSession.self, from: data)
    return value.valid() ? value : nil
  }
}

enum ShareComposeFailure: Error, Equatable { case signIn, unavailable, invalidContent, upload, cancelled }
