import XCTest
@testable import NovelManga

final class TxtParserTests: XCTestCase {

    func testDecodesUTF8Chinese() {
        let text = "第一章 开端\n正文内容"
        let data = text.data(using: .utf8)!
        XCTAssertEqual(TxtParser.decode(data), text)
    }

    func testSplitsChineseChapters() {
        let text = """
        第一章 开端
        这是第一章的内容。
        第二章 发展
        这是第二章的内容。
        第十章 结局
        最后一章的内容。
        """
        let book = TxtParser.parse(text: text, fileName: "测试书.txt")
        XCTAssertEqual(book.units.count, 3)
        XCTAssertEqual(book.units.first?.title, "第一章 开端")
        XCTAssertEqual(book.units.last?.title, "第十章 结局")
        XCTAssertTrue(book.units[1].text?.contains("这是第二章的内容") == true)
    }

    func testTextWithoutMarkersBecomesSingleUnit() {
        let text = "只是一段正文。\n第二段正文。"
        let book = TxtParser.parse(text: text, fileName: "无章节.txt")
        XCTAssertEqual(book.units.count, 1)
        XCTAssertEqual(book.units[0].title, "全文")
        XCTAssertEqual(book.units[0].text, text)
    }

    func testLongParagraphStartingWithChapterWordsIsNotAChapter() {
        let body = "第3章" + String(repeating: "内容", count: 30)
        let text = "正文开头\n\(body)\n正文结尾"
        let book = TxtParser.parse(text: text, fileName: "误判.txt")
        XCTAssertEqual(book.units.count, 1)
    }

    func testDetectsAuthor() {
        let text = """
        作者：某作者
        第一章 开端
        正文
        """
        let book = TxtParser.parse(text: text, fileName: "书.txt")
        XCTAssertEqual(book.author, "某作者")
    }

    func testTitleComesFromFileNameWithoutAuthorSuffix() {
        XCTAssertEqual(TxtParser.bookTitle(fileName: "斗破苍穹_天蚕土豆.txt", text: ""), "斗破苍穹")
        XCTAssertEqual(TxtParser.bookTitle(fileName: "凡人修仙传.txt", text: ""), "凡人修仙传")
    }

    func testEmptyTextProducesNoUnits() {
        let book = TxtParser.parse(text: "   \n\n  ", fileName: "空.txt")
        XCTAssertTrue(book.units.isEmpty)
    }
}
