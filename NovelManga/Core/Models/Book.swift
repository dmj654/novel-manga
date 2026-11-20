import Foundation
import GRDB

/// 书类型：0 小说 / 1 漫画
enum BookKind: Int, Codable, CaseIterable {
    case novel = 0
    case comic = 1

    var displayName: String {
        switch self {
        case .novel: return "小说"
        case .comic: return "漫画"
        }
    }
}

/// 来源类型：0 本地 / 1 在线
enum BookOrigin: Int, Codable {
    case local = 0
    case online = 1
}

/// 连载状态：0 完结 / 1 连载
enum SerialStatus: Int, Codable {
    case finished = 0
    case ongoing = 1
}

struct Book: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable {
    static let databaseTableName = "books"

    var id: String
    var title: String
    var author: String?
    var coverPath: String?
    /// 0 小说 / 1 漫画，见 BookKind
    var type: Int
    /// 0 本地 / 1 在线，见 BookOrigin
    var origin: Int
    var sourceID: String?
    var remoteKey: String?
    var intro: String?
    var category: String?
    var serialStatus: Int?
    var unitCount: Int
    var inShelf: Bool
    var favoritedAt: Int64?
    var lastOpenedAt: Int64?
    var createdAt: Int64
    var updatedAt: Int64?

    enum CodingKeys: String, CodingKey {
        case id, title, author, type, origin, intro, category
        case coverPath = "cover_path"
        case sourceID = "source_id"
        case remoteKey = "remote_key"
        case serialStatus = "serial_status"
        case unitCount = "unit_count"
        case inShelf = "in_shelf"
        case favoritedAt = "favorited_at"
        case lastOpenedAt = "last_opened_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var kind: BookKind { BookKind(rawValue: type) ?? .novel }
    var bookOrigin: BookOrigin { BookOrigin(rawValue: origin) ?? .local }

    var createdAtDate: Date { Date(timeIntervalSince1970: TimeInterval(createdAt)) }
    var lastOpenedDate: Date? {
        lastOpenedAt.map { Date(timeIntervalSince1970: TimeInterval($0)) }
    }
}

extension Book {
    /// 新建一本本地书，默认不入书架（D4）
    static func makeLocal(title: String,
                          author: String?,
                          kind: BookKind,
                          coverPath: String?,
                          unitCount: Int,
                          now: Date = Date()) -> Book {
        Book(id: UUID().uuidString,
             title: title,
             author: author,
             coverPath: coverPath,
             type: kind.rawValue,
             origin: BookOrigin.local.rawValue,
             sourceID: nil,
             remoteKey: nil,
             intro: nil,
             category: nil,
             serialStatus: nil,
             unitCount: unitCount,
             inShelf: false,
             favoritedAt: nil,
             lastOpenedAt: nil,
             createdAt: Int64(now.timeIntervalSince1970),
             updatedAt: nil)
    }
}
