import Foundation
import GRDB

/// 章 / 话 / 分卷，统称 Unit
struct Unit: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable {
    static let databaseTableName = "units"

    var id: String
    var bookID: String
    var idx: Int
    var title: String?
    var url: String?
    var pageCount: Int?
    var cached: Bool
    var updatedAt: Int64?

    enum CodingKeys: String, CodingKey {
        case id, idx, title, url, cached
        case bookID = "book_id"
        case pageCount = "page_count"
        case updatedAt = "updated_at"
    }

    init(id: String = UUID().uuidString,
         bookID: String,
         idx: Int,
         title: String?,
         url: String? = nil,
         pageCount: Int? = nil,
         cached: Bool = false,
         updatedAt: Int64? = nil) {
        self.id = id
        self.bookID = bookID
        self.idx = idx
        self.title = title
        self.url = url
        self.pageCount = pageCount
        self.cached = cached
        self.updatedAt = updatedAt
    }
}

/// 漫画单页
struct ComicPage: Codable, FetchableRecord, PersistableRecord, Hashable {
    static let databaseTableName = "pages"

    var bookID: String
    var unitIdx: Int
    var pageIdx: Int
    var url: String?
    var localPath: String?
    var width: Int?
    var height: Int?

    enum CodingKeys: String, CodingKey {
        case url, width, height
        case bookID = "book_id"
        case unitIdx = "unit_idx"
        case pageIdx = "page_idx"
        case localPath = "local_path"
    }
}

/// 阅读进度，与书架解耦（D4）
struct ReadingProgress: Codable, FetchableRecord, PersistableRecord, Hashable {
    static let databaseTableName = "progress"

    var bookID: String
    var unitIdx: Int
    /// 小说：章内字符偏移；漫画固定 0
    var charOffset: Int
    /// 漫画：页序号；小说固定 0
    var pageIdx: Int
    var percent: Double
    var updatedAt: Int64

    enum CodingKeys: String, CodingKey {
        case percent
        case bookID = "book_id"
        case unitIdx = "unit_idx"
        case charOffset = "char_offset"
        case pageIdx = "page_idx"
        case updatedAt = "updated_at"
    }

    init(bookID: String,
         unitIdx: Int,
         charOffset: Int = 0,
         pageIdx: Int = 0,
         percent: Double = 0,
         updatedAt: Date = Date()) {
        self.bookID = bookID
        self.unitIdx = unitIdx
        self.charOffset = charOffset
        self.pageIdx = pageIdx
        self.percent = percent
        self.updatedAt = Int64(updatedAt.timeIntervalSince1970)
    }
}
