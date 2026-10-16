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

    /// Merges `other` into this payload. Entries are matched by id and the more recently
    /// updated copy wins; entries whose contents already exist under another id are skipped.
    public func merging(_ other: VaultPayload) -> (payload: VaultPayload, summary: MergeSummary) {
        var merged = entries
        var summary = MergeSummary()
        for incoming in other.entries {
            if let i = merged.firstIndex(where: { $0.id == incoming.id }) {
                if incoming.updatedAt > merged[i].updatedAt {
                    merged[i] = incoming
                    summary.updated += 1
                } else {
                    summary.unchanged += 1
                }
            } else if merged.contains(where: { $0.hasSameContents(as: incoming) }) {
                summary.unchanged += 1
            } else {
                merged.append(incoming)
                summary.added += 1
            }
        }
        return (VaultPayload(entries: merged), summary)
    }
}

public struct MergeSummary: Equatable, Sendable {
    public var added = 0
    public var updated = 0
    public var unchanged = 0
    public init(added: Int = 0, updated: Int = 0, unchanged: Int = 0) {
        self.added = added
        self.updated = updated
        self.unchanged = unchanged
    }
}

extension Entry {
    func hasSameContents(as other: Entry) -> Bool {
        title == other.title && username == other.username && password == other.password
            && url == other.url && notes == other.notes
    }
}
