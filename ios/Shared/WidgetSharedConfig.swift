import Foundation
import Security

/// Resolves App Group / Keychain identifiers at runtime instead of hardcoding
/// them, so the app keeps working when the bundle ID or signing team changes
/// (unsigned builds, ad-hoc re-signing, sideloading with a personal team).
///
/// Resolution order for the App Group:
///   1. `MDAppGroupIdentifier` in Info.plist (injected from Config.xcconfig)
///   2. Derived from the bundle ID: `group.<bundle-id-without-extension-suffix>`
///   3. First `group.*` entry found in the embedded entitlements
///
/// The Keychain access group prefix (`$(AppIdentifierPrefix)`) can never be
/// hardcoded: it is the signing team's ID and changes on every re-sign. It is
/// discovered at runtime with a probe write, and if the Keychain is unusable
/// entirely (missing entitlement after re-sign) callers fall back to the
/// App Group `UserDefaults`, which is always available.
enum WidgetSharedConfig {

  // MARK: - App Group

  /// App Group suite shared by the app and every extension.
  static let appGroupIdentifier: String = {
    if let configured = Bundle.main.object(forInfoDictionaryKey: "MDAppGroupIdentifier") as? String,
       !configured.isEmpty,
       !configured.hasPrefix("$(") {
      return configured
    }
    if let derived = derivedAppGroupFromBundleId() {
      return derived
    }
    if let fromEntitlements = appGroupFromEntitlements() {
      return fromEntitlements
    }
    return "group.cc.boring-lab.monodash"
  }()

  /// `UserDefaults` for the shared App Group. `nil` only if the entitlement is
  /// missing altogether, in which case widgets cannot read anything and the
  /// caller should surface a configuration error rather than an empty state.
  static var sharedDefaults: UserDefaults? {
    UserDefaults(suiteName: appGroupIdentifier)
  }

  /// Strips extension suffixes so the app and all extensions derive the *same*
  /// group. `cc.example.app.MyWidgetExtension` -> `group.cc.example.app`
  private static func derivedAppGroupFromBundleId() -> String? {
    guard var bundleId = Bundle.main.bundleIdentifier, !bundleId.isEmpty else { return nil }
    for suffix in ["ServerStatusWidgetExtension", "ServerStatusWidgetIntentsExtension"] {
      if bundleId.hasSuffix(".\(suffix)") {
        bundleId = String(bundleId.dropLast(suffix.count + 1))
        break
      }
    }
    return "group.\(bundleId)"
  }

  private static func appGroupFromEntitlements() -> String? {
    guard let task = SecTaskCreateFromSelf(nil) else { return nil }
    let key = "com.apple.security.application-groups" as CFString
    guard
      let value = SecTaskCopyValueForEntitlement(task, key, nil) as? [String],
      let group = value.first(where: { $0.hasPrefix("group.") })
    else { return nil }
    return group
  }

  // MARK: - Keychain

  static let keychainService = "MonoDashServerWidget"

  /// The team prefix (`$(AppIdentifierPrefix)`) read from the live entitlements.
  /// Returns `nil` when running unsigned, which disables Keychain use.
  static let keychainAccessGroup: String? = {
    guard let task = SecTaskCreateFromSelf(nil) else { return nil }
    let key = "keychain-access-groups" as CFString
    guard let groups = SecTaskCopyValueForEntitlement(task, key, nil) as? [String] else {
      return nil
    }
    // Prefer the dedicated widget group, else the first shared group available.
    return groups.first(where: { $0.hasSuffix(".widget") }) ?? groups.first
  }()

  /// Whether the Keychain path is usable in the current signing context.
  /// Verified once with a probe write/delete so a broken entitlement degrades
  /// to the `UserDefaults` fallback instead of silently returning no data.
  static let isKeychainUsable: Bool = {
    guard let accessGroup = keychainAccessGroup else { return false }
    let probeAccount = "__md_probe__"
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: probeAccount,
      kSecAttrAccessGroup as String: accessGroup
    ]
    SecItemDelete(query as CFDictionary)
    query[kSecValueData as String] = Data("probe".utf8)
    query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
    let status = SecItemAdd(query as CFDictionary, nil)
    if status == errSecSuccess {
      SecItemDelete(query as CFDictionary)
      return true
    }
    return false
  }()

  // MARK: - Storage keys

  static let serversKey = "server_widget_servers"
  static let snapshotsKey = "server_widget_snapshots"
  static let settingsKey = "server_widget_settings"
  /// Fallback store used when the Keychain is unavailable.
  static let apiKeyFallbackKey = "server_widget_api_keys"

  static func apiKeyAccount(serverId: Int) -> String { "server_\(serverId)" }
}
