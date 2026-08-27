import Foundation
import Security

/// Resolves App Group / Keychain identifiers at runtime instead of hardcoding
/// them, so the app keeps working when the bundle ID or signing team changes
/// (unsigned builds, ad-hoc re-signing, sideloading with a personal team).
///
/// Both lookups *probe* the sandbox with public APIs rather than trusting a
/// compile-time constant, because a re-sign rewrites entitlements without
/// touching the binary:
///
/// * App Group — candidates are tested with
///   `containerURL(forSecurityApplicationGroupIdentifier:)`, which returns
///   `nil` unless the entitlement is actually granted. The first container that
///   materialises wins.
/// * Keychain access group — the team prefix (`$(AppIdentifierPrefix)`) is
///   recovered by adding an item *without* an access group and reading back the
///   `kSecAttrAccessGroup` the system assigned, which is Apple's documented way
///   to discover it. Hardcoding it is what broke widgets on re-signed builds.
enum WidgetSharedConfig {

  // MARK: - App Group

  /// App Group suite shared by the app and every extension.
  ///
  /// Resolution order: granted container (ground truth) → value configured in
  /// Info.plist → derived from the bundle ID. Every target computes the same
  /// candidate list in the same order, so the app and its extensions always
  /// agree on one suite.
  static let appGroupIdentifier: String = {
    let candidates = appGroupCandidates()
    let fileManager = FileManager.default
    for candidate in candidates
    where fileManager.containerURL(forSecurityApplicationGroupIdentifier: candidate) != nil {
      return candidate
    }
    // Nothing is entitled (typically an unsigned build running in the
    // simulator). Fall back to the first candidate so behaviour stays
    // deterministic and `isAppGroupAvailable` can report the problem.
    return candidates.first ?? "group.cc.boring-lab.monodash"
  }()

  /// `false` when no App Group container could be opened. Widgets cannot read
  /// anything in that state, so the UI should surface a configuration error
  /// instead of rendering a misleading empty state.
  static var isAppGroupAvailable: Bool {
    FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) != nil
  }

  /// `UserDefaults` for the shared App Group.
  static var sharedDefaults: UserDefaults? {
    UserDefaults(suiteName: appGroupIdentifier)
  }

  private static func appGroupCandidates() -> [String] {
    var candidates: [String] = []

    // 1. Configured at build time from Config.xcconfig.
    if let configured = Bundle.main.object(forInfoDictionaryKey: "MDAppGroupIdentifier") as? String,
       !configured.isEmpty,
       !configured.hasPrefix("$("),
       configured.hasPrefix("group.") {
      candidates.append(configured)
    }

    // 2. Derived from the (possibly rewritten) bundle ID.
    if let derived = derivedAppGroupFromBundleId() {
      candidates.append(derived)
    }

    // 3. The upstream default, so an untouched build still finds its data.
    candidates.append("group.cc.boring-lab.monodash")

    // Preserve order, drop duplicates.
    var seen = Set<String>()
    return candidates.filter { seen.insert($0).inserted }
  }

  /// Strips extension suffixes so the app and all extensions derive the *same*
  /// group. `cc.example.app.ServerStatusWidgetExtension` -> `group.cc.example.app`
  private static func derivedAppGroupFromBundleId() -> String? {
    guard var bundleId = Bundle.main.bundleIdentifier, !bundleId.isEmpty else { return nil }
    for suffix in ["ServerStatusWidgetExtension", "ServerStatusWidgetIntentsExtension"] {
      if bundleId.hasSuffix(".\(suffix)") {
        bundleId = String(bundleId.dropLast(suffix.count + 1))
        break
      }
    }
    return bundleId.isEmpty ? nil : "group.\(bundleId)"
  }

  // MARK: - Keychain

  static let keychainService = "MonoDashServerWidget"

  /// Shared Keychain access group, discovered at runtime.
  ///
  /// Returns `nil` when the Keychain is unusable (unsigned build, or the
  /// entitlement was dropped during re-signing); callers then use the App Group
  /// fallback in `WidgetApiKeyStore`.
  static let keychainAccessGroup: String? = {
    guard let prefix = discoveredTeamPrefix() else { return nil }
    // The app and the extensions share `<prefix>.<app bundle id>.widget`, which
    // matches the `keychain-access-groups` entry in the entitlements files.
    guard let appBundleId = appBundleIdentifier() else { return nil }
    return "\(prefix)\(appBundleId).widget"
  }()

  /// Whether the Keychain path is usable in the current signing context.
  /// Verified once with a probe write/delete so a broken entitlement degrades to
  /// the `UserDefaults` fallback instead of silently returning no data.
  static let isKeychainUsable: Bool = {
    guard let accessGroup = keychainAccessGroup else { return false }
    let probe: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: "__md_probe__",
      kSecAttrAccessGroup as String: accessGroup,
      kSecValueData as String: Data("probe".utf8),
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
    ]
    SecItemDelete(probe as CFDictionary)
    let status = SecItemAdd(probe as CFDictionary, nil)
    guard status == errSecSuccess else { return false }
    SecItemDelete(probe as CFDictionary)
    return true
  }()

  /// The main app's bundle ID, even when called from an extension.
  private static func appBundleIdentifier() -> String? {
    guard var bundleId = Bundle.main.bundleIdentifier, !bundleId.isEmpty else { return nil }
    for suffix in ["ServerStatusWidgetExtension", "ServerStatusWidgetIntentsExtension"] {
      if bundleId.hasSuffix(".\(suffix)") {
        bundleId = String(bundleId.dropLast(suffix.count + 1))
        break
      }
    }
    return bundleId
  }

  /// Recovers `$(AppIdentifierPrefix)` (i.e. `TEAMID.`) by adding a Keychain
  /// item with no explicit access group and reading back the one the system
  /// assigned. Apple documents this as the way to learn the prefix at runtime.
  private static func discoveredTeamPrefix() -> String? {
    let account = "__md_prefix_probe__"
    let base: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: account
    ]
    SecItemDelete(base as CFDictionary)

    var addQuery = base
    addQuery[kSecValueData as String] = Data("probe".utf8)
    addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
    guard SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess else { return nil }

    defer { SecItemDelete(base as CFDictionary) }

    var readQuery = base
    readQuery[kSecReturnAttributes as String] = true
    readQuery[kSecMatchLimit as String] = kSecMatchLimitOne

    var result: AnyObject?
    guard
      SecItemCopyMatching(readQuery as CFDictionary, &result) == errSecSuccess,
      let attributes = result as? [String: Any],
      let accessGroup = attributes[kSecAttrAccessGroup as String] as? String,
      let dot = accessGroup.firstIndex(of: ".")
    else { return nil }

    // `accessGroup` looks like `ABCDE12345.cc.example.app`; keep `ABCDE12345.`
    return String(accessGroup[..<accessGroup.index(after: dot)])
  }

  // MARK: - Storage keys

  static let serversKey = "server_widget_servers"
  static let snapshotsKey = "server_widget_snapshots"
  static let settingsKey = "server_widget_settings"
  /// Fallback store used when the Keychain is unavailable.
  static let apiKeyFallbackKey = "server_widget_api_keys"

  static func apiKeyAccount(serverId: Int) -> String { "server_\(serverId)" }
}
