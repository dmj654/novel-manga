import Foundation

/// 从 XHTML/HTML 抽纯文本，EPUB 正文用得上
enum HTMLTextExtractor {

    private static let blockTagRegex = try! NSRegularExpression(
        pattern: "<\\s*(?:br|p|div|h[1-6]|li|tr|blockquote)[^>]*>", options: [.caseInsensitive])
    private static let tagRegex = try! NSRegularExpression(pattern: "<[^>]+>", options: [])
    private static let scriptRegex = try! NSRegularExpression(
        pattern: "<\\s*(?:script|style)[^>]*>[\\s\\S]*?<\\s*/\\s*(?:script|style)\\s*>",
        options: [.caseInsensitive])
    private static let titleRegex = try! NSRegularExpression(
        pattern: "<\\s*title[^>]*>([\\s\\S]*?)<\\s*/\\s*title\\s*>", options: [.caseInsensitive])
    private static let headingRegex = try! NSRegularExpression(
        pattern: "<\\s*h[1-3][^>]*>([\\s\\S]*?)<\\s*/\\s*h[1-3]\\s*>", options: [.caseInsensitive])

    private static let entities: [String: String] = [
        "&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">",
        "&quot;": "\"", "&#39;": "'", "&apos;": "'", "&hellip;": "…",
        "&mdash;": "—", "&ldquo;": "“", "&rdquo;": "”"
    ]

    static func title(from html: String) -> String? {
        for regex in [headingRegex, titleRegex] {
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            if let match = regex.firstMatch(in: html, options: [], range: range),
               match.numberOfRanges > 1,
               let r = Range(match.range(at: 1), in: html) {
                let raw = String(html[r])
                let cleaned = plainText(from: raw).trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty { return cleaned }
            }
        }
        return nil
    }

    static func plainText(from html: String) -> String {
        var text = html
        text = replacing(scriptRegex, in: text, with: "\n")
        text = replacing(blockTagRegex, in: text, with: "\n")
        text = replacing(tagRegex, in: text, with: "")
        text = decodeEntities(text)
        text = text.replacingOccurrences(of: "\u{00A0}", with: " ")

        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return lines.joined(separator: "\n")
    }

    private static func replacing(_ regex: NSRegularExpression, in text: String, with replacement: String) -> String {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: replacement)
    }

    private static func decodeEntities(_ text: String) -> String {
        var result = text
        for (entity, value) in entities {
            result = result.replacingOccurrences(of: entity, with: value)
        }
        let regex = try! NSRegularExpression(pattern: "&#(x?[0-9a-fA-F]+);", options: [])
        let range = NSRange(result.startIndex..<result.endIndex, in: result)
        let matches = regex.matches(in: result, options: [], range: range).reversed()
        for match in matches {
            guard match.numberOfRanges > 1, let r = Range(match.range(at: 1), in: result) else { continue }
            let token = String(result[r])
            let scalarValue: UInt32?
            if token.lowercased().hasPrefix("x") {
                scalarValue = UInt32(token.dropFirst(), radix: 16)
            } else {
                scalarValue = UInt32(token)
            }
            guard let value = scalarValue, let scalar = Unicode.Scalar(value) else { continue }
            result.replaceSubrange(r, with: String(Character(scalar)))
        }
        return result
    }
}
