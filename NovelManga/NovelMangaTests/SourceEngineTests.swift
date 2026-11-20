import XCTest
@testable import NovelManga

final class SourceEngineTests: XCTestCase {

    private func makeRule() -> SourceRule {
        let json = """
        {
          "id": "demo",
          "name": "示例源",
          "type": "novel",
          "baseUrl": "https://example.com",
          "search": {
            "url": "{{base}}/search?q={{key}}&page={{page}}",
            "list": "<div class=\\"book-item\\">",
            "name": "<h3>(.*?)</h3>",
            "author": "作者：(.*?)<",
            "cover": "src=\\"(.*?)\\"",
            "detail": "href=\\"(.*?)\\""
          },
          "detail": {
            "url": "{{base}}{{detail}}",
            "name": "<h1>(.*?)</h1>",
            "author": "作者：(.*?)<",
            "intro": "<div id=\\"intro\\">(.*?)</div>",
            "cover": "src=\\"(.*?)\\"",
            "category": "分类：(.*?)<",
            "status": "(连载中|已完结)"
          },
          "toc": {
            "url": "{{base}}{{detail}}",
            "list": "<dd>",
            "title": "<a[^>]*>(.*?)</a>",
            "href": "href=\\"(.*?)\\""
          },
          "content": {
            "url": "{{base}}{{chapterUrl}}",
            "text": "<div id=\\"content\\">(.*?)</div>"
          },
          "images": {
            "url": "{{base}}{{chapterUrl}}",
            "list": "<img",
            "src": "data-src=\\"(.*?)\\""
          }
        }
        """
        return try! SourceRule.decode(from: json)
    }

    func testDecodesRuleJSON() {
        let rule = makeRule()
        XCTAssertEqual(rule.id, "demo")
        XCTAssertEqual(rule.type, "novel")
        XCTAssertEqual(rule.search?.pageStep, nil)
        XCTAssertEqual(rule.toc?.list, "<dd>")
    }

    func testExpandReplacesTemplates() {
        let rule = makeRule()
        let url = SourceEngine.expand(rule.search!.url, rule: rule, key: "abc", page: 2)
        XCTAssertTrue(url.contains("q=abc"))
        XCTAssertTrue(url.contains("page=2"))
        XCTAssertFalse(url.contains("{{"))
    }

    func testParseSearchReturnsBooksWithAbsoluteCover() {
        let rule = makeRule()
        let html = """
        <div class="book-item"><h3>剑来</h3><p>作者：烽火戏诸侯</p><img src="/cover/1.jpg"><a href="/book/1">详情</a></div>
        <div class="book-item"><h3>诡秘之主</h3><p>作者：爱潜水的乌贼</p><img src="/cover/2.jpg"><a href="/book/2">详情</a></div>
        """
        let books = SourceEngine.parseSearch(html: html, rule: rule)
        XCTAssertEqual(books.count, 2)
        XCTAssertEqual(books[0].title, "剑来")
        XCTAssertEqual(books[0].author, "烽火戏诸侯")
        XCTAssertEqual(books[0].coverURL, "https://example.com/cover/1.jpg")
        XCTAssertEqual(books[0].detailPath, "/book/1")
        XCTAssertEqual(books[0].sourceID, "demo")
    }

    func testParseSearchSkipsBlocksWithoutDetailLink() {
        let rule = makeRule()
        let html = "<div class=\"book-item\"><h3>没有链接</h3></div>"
        XCTAssertTrue(SourceEngine.parseSearch(html: html, rule: rule).isEmpty)
    }

    func testParseDetail() {
        let rule = makeRule()
        let html = """
        <h1>剑来</h1><p>作者：烽火戏诸侯</p>
        <div id="intro">大千世界，无奇不有。</div>
        <img src="/cover/1.jpg">
        <p>分类：玄幻</p><p>连载中</p>
        """
        let detail = SourceEngine.parseDetail(html: html, rule: rule)
        XCTAssertEqual(detail?.name, "剑来")
        XCTAssertEqual(detail?.author, "烽火戏诸侯")
        XCTAssertEqual(detail?.intro, "大千世界，无奇不有。")
        XCTAssertEqual(detail?.coverURL, "https://example.com/cover/1.jpg")
        XCTAssertEqual(detail?.serialStatus, .ongoing)
    }

    func testParseChapters() {
        let rule = makeRule()
        let html = "<dd><a href=\"/chapter/1\">第一章 惊蛰</a></dd><dd><a href=\"/chapter/2\">第二章 少年</a></dd>"
        let chapters = SourceEngine.parseChapters(html: html, rule: rule)
        XCTAssertEqual(chapters.count, 2)
        XCTAssertEqual(chapters[0].title, "第一章 惊蛰")
        XCTAssertEqual(chapters[0].path, "/chapter/1")
    }

    func testParseContentRemovesAdLines() {
        let rule = makeRule()
        let html = "<div id=\"content\"><p>正文第一段</p><p>请记住本站域名</p><p>正文第二段</p></div>"
        let text = SourceEngine.parseContent(html: html, rule: rule)
        XCTAssertNotNil(text)
        XCTAssertTrue(text!.contains("正文第一段"))
        XCTAssertTrue(text!.contains("正文第二段"))
        XCTAssertFalse(text!.contains("请记住本站"))
        XCTAssertFalse(text!.contains("<p>"))
    }

    func testParseImages() {
        let rule = makeRule()
        let html = "<img data-src=\"/img/1.jpg\"><img data-src=\"/img/2.jpg\">"
        let urls = SourceEngine.parseImages(html: html, rule: rule)
        XCTAssertEqual(urls, ["https://example.com/img/1.jpg", "https://example.com/img/2.jpg"])
    }

    func testRuleWithoutSearchRuleReturnsEmpty() {
        var rule = makeRule()
        rule.search = nil
        XCTAssertTrue(SourceEngine.parseSearch(html: "<div class=\"book-item\"><h3>a</h3></div>", rule: rule).isEmpty)
    }
}

final class SourceStoreTests: XCTestCase {

    func testSaveSourceAndToggleAndDelete() throws {
        let store = try LibraryStore.makeInMemory()
        let rule = SourceRule(id: "src-1", name: "源一", type: "novel", baseUrl: "https://a.com",
                              charset: nil, headers: nil, search: nil, detail: nil,
                              toc: nil, content: nil, images: nil, categories: nil, ranks: nil)
        let source = try Source(rule: rule)

        try store.save(source: source)
        XCTAssertEqual(try store.sources().count, 1)
        XCTAssertEqual(try store.enabledSources().count, 1)

        let loaded = try XCTUnwrap(try store.source(id: "src-1"))
        let decoded = try loaded.decodedRule()
        XCTAssertEqual(decoded.name, "源一")
        XCTAssertEqual(decoded.baseUrl, "https://a.com")

        try store.setSourceEnabled(id: "src-1", enabled: false)
        XCTAssertTrue(try store.enabledSources().isEmpty)
        XCTAssertEqual(try store.sources().count, 1)

        try store.deleteSource(id: "src-1")
        XCTAssertTrue(try store.sources().isEmpty)
    }
}
