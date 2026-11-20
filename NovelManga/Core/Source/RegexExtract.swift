import Foundation

/// 轻量正则抽取 + HTML 清洗，书源规则用
enum RegexExtract {

    static func firstGroup(in text: String, pattern: String?) -> String? {
        guard let pattern, !pattern.isEmpty, !text.isEmpty else { return nil }
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let captured = Range(match.range(at: 1), in: text) else {
            return nil
        }
        let value = String(text[captured]).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    static func allFirstGroups(in text: String, pattern: String?) -> [String] {
        guard let pattern, !pattern.isEmpty, !text.isEmpty else { return [] }
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, options: [], range: range).compactMap { match in
            guard match.numberOfRanges > 1, let captured = Range(match.range(at: 1), in: text) else { return nil }
            let value = String(text[captured]).trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
    }

    /// 按字面标记切块（规则里的 list 字段）
    static func split(_ html: String, by marker: String?) -> [String] {
        guard let marker, !marker.isEmpty else { return [html] }
        return html.components(separatedBy: marker).dropFirst().map { String($0) }
    }

    static func cleanText(_ raw: String) -> String {
        HTMLTextExtractor.plainText(from: raw)
    }

    /// 广告行黑名单，可被规则覆盖（v1 固定清单）
    static let adKeywords = [
        "请记住本站", "本站域名", "最新章节", "无弹窗", "手机阅读",
        "手机用户请", "章节错误", "求收藏", "求推荐", "百度搜索", "一秒记住"
    ]

    static func removeAdLines(_ text: String, extra: [String] = []) -> String {
        let blacklist = adKeywords + extra
        return text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { line in
                guard !line.isEmpty else { return false }
                return !blacklist.contains { line.contains($0) }
            }
            .joined(separator: "\n")
    }
}
