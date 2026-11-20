import Foundation

protocol HTTPFetching {
    func fetch(_ urlString: String, headers: [String: String]) async throws -> String
}

struct URLSessionFetcher: HTTPFetching {
    func fetch(_ urlString: String, headers: [String: String]) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw SourceError.network("地址不合法：\(urlString)")
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw SourceError.network("HTTP \(response.description)")
            }
            if let text = TxtParser.decode(data) { return text }
            throw SourceError.network("网页无法解码")
        } catch let error as SourceError {
            throw error
        } catch {
            throw SourceError.network(error.localizedDescription)
        }
    }
}

/// 书源客户端：模板展开 + 抓取 + 解析
struct SourceClient {
    let fetcher: HTTPFetching

    init(fetcher: HTTPFetching = URLSessionFetcher()) {
        self.fetcher = fetcher
    }

    func search(keyword: String, rule: SourceRule, page: Int = 0) async throws -> [OnlineBook] {
        guard let search = rule.search else { throw SourceError.ruleMismatch("\(rule.name) 没有搜索规则") }
        let url = SourceEngine.expand(search.url, rule: rule, key: keyword, page: page)
        let html = try await fetcher.fetch(url, headers: rule.headers ?? [:])
        let books = SourceEngine.parseSearch(html: html, rule: rule)
        if books.isEmpty { throw SourceError.emptyResult(rule.name) }
        return books
    }

    func detailAndChapters(for book: OnlineBook, rule: SourceRule) async throws -> (OnlineDetail?, [OnlineChapter]) {
        guard let detailRule = rule.detail else { throw SourceError.ruleMismatch("\(rule.name) 没有详情规则") }
        let detailURL = SourceEngine.expand(detailRule.url, rule: rule, detail: book.detailPath)
        let detailHTML = try await fetcher.fetch(detailURL, headers: rule.headers ?? [:])
        let detail = SourceEngine.parseDetail(html: detailHTML, rule: rule)

        guard let tocRule = rule.toc else { return (detail, []) }
        let tocURL = SourceEngine.expand(tocRule.url, rule: rule, detail: book.detailPath)
        let tocHTML = try await fetcher.fetch(tocURL, headers: rule.headers ?? [:])
        let chapters = SourceEngine.parseChapters(html: tocHTML, rule: rule)
        return (detail, chapters)
    }

    func content(for chapter: OnlineChapter, rule: SourceRule) async throws -> String {
        guard let content = rule.content else { throw SourceError.ruleMismatch("\(rule.name) 没有正文规则") }
        let url = SourceEngine.expand(content.url, rule: rule, chapterUrl: chapter.path)
        let html = try await fetcher.fetch(url, headers: rule.headers ?? [:])
        guard let text = SourceEngine.parseContent(html: html, rule: rule) else {
            throw SourceError.ruleMismatch("\(rule.name) 正文抽取为空")
        }
        return text
    }

    func imageURLs(for chapter: OnlineChapter, rule: SourceRule) async throws -> [String] {
        guard let images = rule.images else { throw SourceError.ruleMismatch("\(rule.name) 没有图片规则") }
        let url = SourceEngine.expand(images.url, rule: rule, chapterUrl: chapter.path)
        let html = try await fetcher.fetch(url, headers: rule.headers ?? [:])
        let urls = SourceEngine.parseImages(html: html, rule: rule)
        guard !urls.isEmpty else { throw SourceError.emptyResult("\(rule.name) 没有图片") }
        return urls
    }

    /// 分类 / 榜单页：复用搜索的列表规则
    func listBooks(at urlString: String, rule: SourceRule) async throws -> [OnlineBook] {
        let html = try await fetcher.fetch(urlString, headers: rule.headers ?? [:])
        let books = SourceEngine.parseSearch(html: html, rule: rule)
        if books.isEmpty { throw SourceError.emptyResult(rule.name) }
        return books
    }
}
