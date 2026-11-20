import Foundation
import GRDB

struct Source: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable {
    static let databaseTableName = "sources"

    var id: String
    var name: String
    /// 0 小说 / 1 漫画
    var type: Int
    var enabled: Bool
    var rulesJSON: String
    var lastStatus: Int?
    var lastCheckedAt: Int64?
    var createdAt: Int64

    enum CodingKeys: String, CodingKey {
        case id, name, type, enabled, createdAt
        case rulesJSON = "rules_json"
        case lastStatus = "last_status"
        case lastCheckedAt = "last_checked_at"
    }

    init(rule: SourceRule, enabled: Bool = true, now: Date = Date()) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(rule)
        guard let json = String(data: data, encoding: .utf8) else {
            throw ImportError.unreadable(rule.name)
        }
        self.id = rule.id
        self.name = rule.name
        self.type = rule.isComic ? 1 : 0
        self.enabled = enabled
        self.rulesJSON = json
        self.lastStatus = nil
        self.lastCheckedAt = nil
        self.createdAt = Int64(now.timeIntervalSince1970)
    }

    func decodedRule() throws -> SourceRule {
        try SourceRule.decode(from: rulesJSON)
    }
}
