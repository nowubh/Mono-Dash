import Foundation
import Security

/// Stores per-server API keys for the widgets.
///
/// Primary store is the Keychain with a shared access group. When the app is
/// re-signed by a different team (sideloading, ad-hoc distribution) the access
/// group no longer matches and every Keychain query fails with
/// `errSecMissingEntitlement` — previously this made widgets render an empty /
/// error state with no way to recover. In that case this store transparently
/// falls back to the shared App Group `UserDefaults`, which requires no
/// team-specific entitlement.
///
/// Security note: the fallback is less protected than the Keychain (App Group
/// containers are readable by the app and its extensions, and are included in
/// device backups). It is only engaged when the Keychain is genuinely
/// unavailable, and `isUsingFallback` lets the UI disclose the downgrade.
enum WidgetApiKeyStore {

  /// True when API keys are being kept in the App Group instead of the Keychain.
  static var isUsingFallback: Bool { !WidgetSharedConfig.isKeychainUsable }

  // MARK: - Read

  static func apiKey(serverId: Int) -> String? {
    guard serverId > 0 else { return nil }
    if WidgetSharedConfig.isKeychainUsable,
       let value = keychainApiKey(serverId: serverId) {
      return value
    }
    return fallbackApiKey(serverId: serverId)
  }

  // MARK: - Write

  static func save(_ apiKey: String, serverId: Int) {
    guard serverId > 0, !apiKey.isEmpty else { return }
    if WidgetSharedConfig.isKeychainUsable {
      saveToKeychain(apiKey, serverId: serverId)
      // Drop any stale fallback copy so the Keychain stays authoritative.
      removeFromFallback(serverId: serverId)
      return
    }
    saveToFallback(apiKey, serverId: serverId)
  }

  static func delete(serverId: Int) {
    guard serverId > 0 else { return }
    if WidgetSharedConfig.isKeychainUsable {
      SecItemDelete(baseQuery(serverId: serverId) as CFDictionary)
    }
    removeFromFallback(serverId: serverId)
  }

  // MARK: - Keychain

  private static func baseQuery(serverId: Int) -> [String: Any] {
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: WidgetSharedConfig.keychainService,
      kSecAttrAccount as String: WidgetSharedConfig.apiKeyAccount(serverId: serverId)
    ]
    if let accessGroup = WidgetSharedConfig.keychainAccessGroup {
      query[kSecAttrAccessGroup as String] = accessGroup
    }
    return query
  }

  private static func keychainApiKey(serverId: Int) -> String? {
    var query = baseQuery(serverId: serverId)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    guard status == errSecSuccess, let data = result as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }

  private static func saveToKeychain(_ apiKey: String, serverId: Int) {
    guard let data = apiKey.data(using: .utf8) else { return }
    var query = baseQuery(serverId: serverId)
    SecItemDelete(query as CFDictionary)
    query[kSecValueData as String] = data
    query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
    SecItemAdd(query as CFDictionary, nil)
  }

  // MARK: - App Group fallback

  private static func fallbackMap() -> [String: String] {
    guard
      let string = WidgetSharedConfig.sharedDefaults?
        .string(forKey: WidgetSharedConfig.apiKeyFallbackKey),
      let data = string.data(using: .utf8),
      let map = try? JSONSerialization.jsonObject(with: data) as? [String: String]
    else { return [:] }
    return map
  }

  private static func writeFallbackMap(_ map: [String: String]) {
    guard
      let data = try? JSONSerialization.data(withJSONObject: map),
      let string = String(data: data, encoding: .utf8)
    else { return }
    WidgetSharedConfig.sharedDefaults?
      .set(string, forKey: WidgetSharedConfig.apiKeyFallbackKey)
  }

  private static func fallbackApiKey(serverId: Int) -> String? {
    fallbackMap()[String(serverId)]
  }

  private static func saveToFallback(_ apiKey: String, serverId: Int) {
    var map = fallbackMap()
    map[String(serverId)] = apiKey
    writeFallbackMap(map)
  }

  private static func removeFromFallback(serverId: Int) {
    var map = fallbackMap()
    guard map.removeValue(forKey: String(serverId)) != nil else { return }
    writeFallbackMap(map)
  }
}
