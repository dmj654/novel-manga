import Foundation

/// 纯解析：把网页 HTML 按规则抽成结构化数据。全部可单测，不碰网络。
enum SourceEngine {

    static func expand(_ template: String,
                       rule: SourceRule,
                       key: String? = nil,
                       page: Int = 0,
                       detail: String? = nil,
                       chapterUrl: String? = nil) -> String {
        var result = template.replacingOccurrences(of: "{{base}}", with: rule.baseUrl)
        if let key {
            let encoded = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            result = result.replacingOccurrences(of: "{{key}}", with: encoded)
        }
        result = result.replacingOccurrences(of: "{{page}}", with: String(page))
        if let detail {
            result = result.replacingOccurrences(of: "{{detail}}", with: detail)
        }
        if let chapterUrl {
            result = result.replacingOccurrences(of: "{{chapterUrl}}", with: chapterUrl)
        }
        return result
    }

    static func absoluteURLString(_ raw: String?, rule: SourceRule) -> String? {
        guard var value = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        if value.hasPrefix("http://") || value.hasPrefix("https://") { return value }
        let base = rule.baseUrl.hasSuffix("/") ? String(rule.baseUrl.dropLast()) : rule.baseUrl
        if value.hasPrefix("/") {
            return base + value
        }
        if value.hasPrefix("//") {
            value = "https:" + value
            return value
        }
        return base + "/" + value
    }

    // MARK: - 搜索

    static func parseSearch(html: String, rule: SourceRule) -> [OnlineBook] {
        guard let search = rule.search else { return [] }
        let blocks = RegexExtract.split(html, by: search.list)
        let effectiveBlocks = blocks.isEmpty ? [html] : blocks

        var results: [OnlineBook] = []
        for block in effectiveBlocks {
            guard let name = RegexExtract.firstGroup(in: block, pattern: search.name)?
                .trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { continue }
            let detailPath = RegexExtract.firstGroup(in: block, pattern: search.detail) ?? ""
            guard !detailPath.isEmpty else { continue }
            results.append(OnlineBook(sourceID: rule.id,
                                      title: RegexExtract.cleanText(name),
                                      author: RegexExtract.firstGroup(in: block, pattern: search.author).map(RegexExtract.cleanText),
                                      coverURL: absoluteURLString(RegexExtract.firstGroup(in: block, pattern: search.cover), rule: rule),
                                      detailPath: detailPath))
        }
        return results
    }

    // MARK: - 详情

    static func parseDetail(html: String, rule: SourceRule) -> OnlineDetail? {
        guard let detail = rule.detail else { return nil }
        let name = RegexExtract.firstGroup(in: html, pattern: detail.name).map(RegexExtract.cleanText)
        let author = RegexExtract.firstGroup(in: html, pattern: detail.author).map(RegexExtract.cleanText)
        let intro = RegexExtract.firstGroup(in: html, pattern: detail.intro).map {
            RegexExtract.removeAdLines(RegexExtract.cleanText($0))
        }
        let cover = absoluteURLString(RegexExtract.firstGroup(in: html, pattern: detail.cover), rule: rule)
        let category = RegexExtract.firstGroup(in: html, pattern: detail.category)?.trimmingCharacters(in: .whitespaces)
        let statusText = RegexExtract.firstGroup(in: html, pattern: detail.status)
        let status: SerialStatus?
        switch statusText {
        case "连载中": status = .ongoing
        case "已完结": status = .finished
        default: status = nil
        }

        guard name != nil || author != nil || intro != nil else { return nil }
        return OnlineDetail(name: name ?? "未命名",
                            author: author,
                            intro: intro,
                            coverURL: cover,
                            category: category,
                            serialStatus: status)
    }

    // MARK: - 目录

    static func parseChapters(html: String, rule: SourceRule) -> [OnlineChapter] {
        guard let toc = rule.toc else { return [] }
        let blocks = RegexExtract.split(html, by: toc.list)
        let effectiveBlocks = blocks.isEmpty ? [html] : blocks

        var chapters: [OnlineChapter] = []
        for block in effectiveBlocks {
            guard let href = RegexExtract.firstGroup(in: block, pattern: toc.href), !href.isEmpty else { continue }
            let title = RegexExtract.firstGroup(in: block, pattern: toc.title).map(RegexExtract.cleanText)
                ?? "第\(chapters.count + 1)章"
            chapters.append(OnlineChapter(title: title, path: href))
        }
        return chapters
    }

    // MARK: - 正文 / 图片

    static func parseContent(html: String, rule: SourceRule) -> String? {
        guard let content = rule.content else { return nil }
        guard let raw = RegexExtract.firstGroup(in: html, pattern: content.text) else { return nil }
        let text = RegexExtract.removeAdLines(RegexExtract.cleanText(raw))
        return text.isEmpty ? nil : text
    }

    static func parseImages(html: String, rule: SourceRule) -> [String] {
        guard let images = rule.images else { return [] }
        let blocks = RegexExtract.split(html, by: images.list)
        let effectiveBlocks = blocks.isEmpty ? [html] : blocks
        return effectiveBlocks.compactMap { block in
            guard let raw = RegexExtract.firstGroup(in: block, pattern: images.src) else { return nil }
            return absoluteURLString(raw, rule: rule)
        }
    }
}
