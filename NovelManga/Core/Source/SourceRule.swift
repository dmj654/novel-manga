import Foundation

/// 书源规则（对应《开发计划》§6.1）
struct SourceRule: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    /// "novel" / "comic"
    var type: String
    var baseUrl: String
    var charset: String?
    var headers: [String: String]?
    var search: SearchRule?
    var detail: DetailRule?
    var toc: TocRule?
    var content: ContentRule?
    var images: ImagesRule?
    var categories: [CategoryRule]?
    var ranks: [RankRule]?

    var isComic: Bool { type.lowercased() == "comic" }

    static func decode(from json: String) throws -> SourceRule {
        guard let data = json.data(using: .utf8) else {
            throw ImportError.unreadable("书源规则")
        }
        return try JSONDecoder().decode(SourceRule.self, from: data)
    }
}

struct SearchRule: Codable, Hashable {
    var url: String
    var list: String?
    var name: String?
    var author: String?
    var cover: String?
    var detail: String?
    var pageStep: Int?
}

struct DetailRule: Codable, Hashable {
    var url: String
    var name: String?
    var author: String?
    var intro: String?
    var cover: String?
    var category: String?
    var status: String?
}

struct TocRule: Codable, Hashable {
    var url: String
    var list: String?
    var title: String?
    var href: String?
    var nextPage: String?
}

struct ContentRule: Codable, Hashable {
    var url: String
    var text: String?
    var nextPage: String?
}

struct ImagesRule: Codable, Hashable {
    var url: String
    var list: String?
    var src: String?
    var nextPage: String?
}

struct CategoryRule: Codable, Hashable {
    var name: String
    var url: String
}

struct RankRule: Codable, Hashable {
    var name: String
    var url: String
}

// MARK: - 在线数据模型

struct OnlineBook: Hashable, Identifiable {
    var id: String { sourceID + "|" + detailPath + "|" + title }
    let sourceID: String
    let title: String
    let author: String?
    let coverURL: String?
    let detailPath: String
}

struct OnlineDetail: Hashable {
    let name: String
    let author: String?
    let intro: String?
    let coverURL: String?
    let category: String?
    let serialStatus: SerialStatus?
}

struct OnlineChapter: Hashable {
    let title: String
    let path: String
}

enum SourceError: LocalizedError {
    case network(String)
    case ruleMismatch(String)
    case emptyResult(String)

    var errorDescription: String? {
        switch self {
        case .network(let message): return "网络失败：\(message)"
        case .ruleMismatch(let message): return "规则不匹配：\(message)"
        case .emptyResult(let message): return "没有结果：\(message)"
        }
    }
}
