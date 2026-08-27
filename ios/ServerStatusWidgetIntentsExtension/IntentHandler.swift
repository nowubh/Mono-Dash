import Intents

// Resolved at runtime (see WidgetSharedConfig) to survive bundle ID / team changes.
private let appGroupId = WidgetSharedConfig.appGroupIdentifier
private let serversKey = WidgetSharedConfig.serversKey

final class IntentHandler: INExtension, SelectServerIntentHandling, SelectServerOverviewIntentHandling {
  override func handler(for intent: INIntent) -> Any {
    self
  }

  func provideServerOptionsCollection(
    for intent: SelectServerIntent,
    searchTerm: String?
  ) async throws -> INObjectCollection<ServerIntentItem> {
    INObjectCollection(items: serverItems(matching: searchTerm))
  }

  func defaultServer(for intent: SelectServerIntent) -> ServerIntentItem? {
    serverItems(matching: nil).first
  }

  func provideServer1OptionsCollection(
    for intent: SelectServerOverviewIntent,
    searchTerm: String?
  ) async throws -> INObjectCollection<ServerIntentItem> {
    INObjectCollection(items: serverItems(matching: searchTerm))
  }

  func provideServer2OptionsCollection(
    for intent: SelectServerOverviewIntent,
    searchTerm: String?
  ) async throws -> INObjectCollection<ServerIntentItem> {
    INObjectCollection(items: serverItems(matching: searchTerm))
  }

  func provideServer3OptionsCollection(
    for intent: SelectServerOverviewIntent,
    searchTerm: String?
  ) async throws -> INObjectCollection<ServerIntentItem> {
    INObjectCollection(items: serverItems(matching: searchTerm))
  }

  func defaultServer1(for intent: SelectServerOverviewIntent) -> ServerIntentItem? {
    serverItems(matching: nil).first
  }

  func defaultServer2(for intent: SelectServerOverviewIntent) -> ServerIntentItem? {
    serverItems(matching: nil).dropFirst().first
  }

  func defaultServer3(for intent: SelectServerOverviewIntent) -> ServerIntentItem? {
    serverItems(matching: nil).dropFirst(2).first
  }

  private func serverItems(matching searchTerm: String?) -> [ServerIntentItem] {
    let normalizedSearchTerm = searchTerm?.trimmingCharacters(in: .whitespacesAndNewlines)
    return WidgetIntentStore.servers()
      .filter { server in
        guard let normalizedSearchTerm, !normalizedSearchTerm.isEmpty else {
          return true
        }
        return server.title.localizedCaseInsensitiveContains(normalizedSearchTerm)
          || server.host.localizedCaseInsensitiveContains(normalizedSearchTerm)
      }
      .map { server in
        ServerIntentItem(
          identifier: String(server.id),
          display: server.title,
          subtitle: "\(server.host):\(server.port)",
          image: nil
        )
      }
  }
}

private struct WidgetIntentServer: Codable {
  let id: Int
  let name: String?
  let displayName: String
  let host: String
  let port: Int
  let sortIndex: Int

  var title: String {
    if let name, !name.isEmpty { return name }
    return displayName
  }
}

private enum WidgetIntentStore {
  private static var defaults: UserDefaults? {
    UserDefaults(suiteName: appGroupId)
  }

  static func servers() -> [WidgetIntentServer] {
    guard
      let string = defaults?.string(forKey: serversKey),
      let data = string.data(using: .utf8),
      let servers = try? JSONDecoder().decode([WidgetIntentServer].self, from: data)
    else { return [] }
    return servers.sorted { $0.sortIndex < $1.sortIndex }
  }
}
