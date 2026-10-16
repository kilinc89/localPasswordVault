import Foundation

public struct Entry: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var username: String
    public var password: String
    public var url: String
    public var notes: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = UUID(), title: String = "", username: String = "", password: String = "",
                url: String = "", notes: String = "", createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.username = username
        self.password = password
        self.url = url
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public func matches(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return true }
        return [title, username, url].contains { $0.localizedCaseInsensitiveContains(q) }
    }
}

public struct VaultPayload: Codable, Sendable {
    public var entries: [Entry]
    public init(entries: [Entry] = []) { self.entries = entries }
}
