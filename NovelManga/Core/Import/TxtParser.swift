import Foundation
import CoreFoundation

/// TXT 解析：编码识别 → 章节切分。纯逻辑，便于单测。
enum TxtParser {

    // MARK: - 编码

    /// 依次尝试 UTF-8、GB18030、UTF-16；都失败返回 nil
    static func decode(_ data: Data) -> String? {
        if let text = String(data: data, encoding: .utf8), !text.isEmpty {
            return text
        }
        if let text = String(data: data, encoding: gb18030), !text.isEmpty {
            return text
        }
        if let text = String(data: data, encoding: .utf16), !text.isEmpty {
            return text
        }
        if let text = String(data: data, encoding: .isoLatin1), !text.isEmpty {
            return text
        }
        return nil
    }

    static var gb18030: String.Encoding {
        let cf = CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
        return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cf))
    }

    // MARK: - 章节切分

    private static let chapterRegex: NSRegularExpression = {
        let pattern = "^\\s*(?:第\\s*[0-9０-９零一二三四五六七八九十百千万两〇]+\\s*[章节回卷篇集话話]"
            + "|Chapter\\s+\\d+"
            + "|\\d{1,4}\\s*[、.．]"
            + "|序章|楔子|前言|后记|尾声)"
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()

    /// 正文里以「第一章的…」「第二章是…」开头的句子不是标题，用它挡住误判
    private static let continuationCharacters: Set<Character> = [
        "的", "是", "中", "里", "内", "所", "就", "都", "也", "又", "还",
        "在", "有", "要", "和", "与", "及", "把", "被", "让", "使", "了", "着"
    ]

    static func isChapterTitle(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 40 else { return false }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard let match = chapterRegex.firstMatch(in: trimmed, options: [], range: range),
              let matchRange = Range(match.range, in: trimmed) else {
            return false
        }

        let rest = trimmed[matchRange.upperBound...]
        guard let next = rest.first else { return true }
        if next.isWhitespace { return true }
        if "：:、·—-_（(【[/".contains(next) { return true }
        return !continuationCharacters.contains(next)
    }

    /// 切章：返回 (标题, 正文)。没有任何章节标记时整篇作为一章。
    static func splitChapters(_ text: String) -> [(title: String, body: String)] {
        var chapters: [(String, String)] = []
        var currentTitle: String?
        var currentBody: [String] = []

        func flush() {
            let body = currentBody.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if let title = currentTitle {
                chapters.append((title, body))
            } else if !body.isEmpty {
                chapters.append(("全文", body))
            }
            currentBody = []
        }

        for line in text.components(separatedBy: .newlines) {
            if isChapterTitle(line) {
                flush()
                currentTitle = line.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                currentBody.append(line)
            }
        }
        flush()

        if chapters.isEmpty {
            let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !body.isEmpty { chapters.append(("全文", body)) }
        }
        return chapters
    }

    // MARK: - 书名 / 作者

    static func bookTitle(fileName: String, text: String) -> String {
        var name = (fileName as NSString).deletingPathExtension
        // 兼容 "书名 - 作者" / "书名_作者" 这类常见命名
        for separator in [" - ", "-", "_"] where name.contains(separator) {
            let parts = name.components(separatedBy: separator)
            if let first = parts.first, first.count >= 2 {
                name = first
                break
            }
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未命名" : trimmed
    }

    static func findAuthor(in text: String) -> String? {
        let head = text.components(separatedBy: .newlines).prefix(30)
        for line in head {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            for prefix in ["作者：", "作者:", "作 者："] where trimmed.hasPrefix(prefix) {
                let value = trimmed.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
                if !value.isEmpty { return value }
            }
        }
        return nil
    }

    // MARK: - 入口

    static func parse(data: Data, fileName: String) throws -> ParsedBook {
        guard let text = decode(data) else { throw ImportError.unreadable(fileName) }
        return parse(text: text, fileName: fileName)
    }

    static func parse(text: String, fileName: String) -> ParsedBook {
        let chapters = splitChapters(text)
        let units = chapters.map { ParsedUnit(title: $0.title, text: $0.body, pages: []) }
        return ParsedBook(title: bookTitle(fileName: fileName, text: text),
                          author: findAuthor(in: text),
                          kind: .novel,
                          units: units,
                          coverData: nil,
                          intro: nil)
    }
}
