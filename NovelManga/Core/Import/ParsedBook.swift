import Foundation

/// 解析后的书（还没入库）
struct ParsedBook {
    var title: String
    var author: String?
    var kind: BookKind
    var units: [ParsedUnit]
    var coverData: Data?
    var intro: String?
}

struct ParsedUnit {
    var title: String
    /// 小说章节正文（漫画为 nil）
    var text: String?
    /// 漫画页（小说为空）
    var pages: [ParsedPage]
}

struct ParsedPage {
    var data: Data
    var fileName: String
    var width: Int?
    var height: Int?
}

enum ImportError: LocalizedError {
    case unsupportedFormat(String)
    case unreadable(String)
    case emptyContent
    case brokenArchive(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let ext):
            return "不支持的文件格式：\(ext)"
        case .unreadable(let name):
            return "无法读取文件：\(name)"
        case .emptyContent:
            return "文件里没有可读内容"
        case .brokenArchive(let name):
            return "压缩包损坏或结构不完整：\(name)"
        }
    }
}
