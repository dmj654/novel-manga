import XCTest
@testable import NovelManga

final class NovelTextLayoutTests: XCTestCase {

    func testParagraphsCarryCorrectCharOffsets() {
        let text = "第一段\n\n第二段\n第三段"
        let paragraphs = NovelTextLayout.paragraphs(from: text)

        XCTAssertEqual(paragraphs.count, 3)
        XCTAssertEqual(paragraphs[0].text, "第一段")
        XCTAssertEqual(paragraphs[0].charOffset, 0)
        XCTAssertEqual(paragraphs[1].charOffset, "第一段\n\n".count)
        XCTAssertEqual(paragraphs[2].charOffset, "第一段\n\n第二段\n".count)
    }

    func testEmptyParagraphsAreSkipped() {
        let text = "\n\n  \n正文\n\n"
        let paragraphs = NovelTextLayout.paragraphs(from: text)
        XCTAssertEqual(paragraphs.count, 1)
        XCTAssertEqual(paragraphs[0].text, "正文")
    }

    func testParagraphIndexForOffset() {
        let text = "甲\n乙\n丙"
        let paragraphs = NovelTextLayout.paragraphs(from: text)
        XCTAssertEqual(NovelTextLayout.paragraphIndex(forCharOffset: 0, in: paragraphs), 0)
        XCTAssertEqual(NovelTextLayout.paragraphIndex(forCharOffset: 1, in: paragraphs), 0)
        XCTAssertEqual(NovelTextLayout.paragraphIndex(forCharOffset: 2, in: paragraphs), 1)
        XCTAssertEqual(NovelTextLayout.paragraphIndex(forCharOffset: 4, in: paragraphs), 2)
        XCTAssertEqual(NovelTextLayout.paragraphIndex(forCharOffset: 100, in: paragraphs), 2)
        XCTAssertEqual(NovelTextLayout.paragraphIndex(forCharOffset: 0, in: []), 0)
    }

    func testPercentWithinChapter() {
        // 3 章，第 1 章读了一半
        let percent = NovelProgress.percent(unitIdx: 0, charOffset: 50, currentCharCount: 100, totalUnits: 3)
        XCTAssertEqual(percent, 0.5 / 3.0, accuracy: 0.0001)
    }

    func testPercentAtLastChapterEndIsOne() {
        let percent = NovelProgress.percent(unitIdx: 2, charOffset: 100, currentCharCount: 100, totalUnits: 3)
        XCTAssertEqual(percent, 1.0, accuracy: 0.0001)
    }

    func testPercentWithoutUnitsIsZero() {
        XCTAssertEqual(NovelProgress.percent(unitIdx: 0, charOffset: 0, currentCharCount: 0, totalUnits: 0), 0)
    }

    func testPercentIsClamped() {
        let over = NovelProgress.percent(unitIdx: 99, charOffset: 500, currentCharCount: 100, totalUnits: 2)
        XCTAssertEqual(over, 1.0, accuracy: 0.0001)
        let negative = NovelProgress.percent(unitIdx: -3, charOffset: -10, currentCharCount: 100, totalUnits: 2)
        XCTAssertGreaterThanOrEqual(negative, 0)
    }

    func testClampOffset() {
        XCTAssertEqual(NovelProgress.clampOffset(-5, charCount: 10), 0)
        XCTAssertEqual(NovelProgress.clampOffset(20, charCount: 10), 10)
        XCTAssertEqual(NovelProgress.clampOffset(5, charCount: 10), 5)
    }
}

final class ComicProgressTests: XCTestCase {

    func testFirstPageOfFirstUnit() {
        XCTAssertEqual(ComicProgress.percent(unitIdx: 0, pageIdx: 0, pageCount: 10, totalUnits: 2), 0)
    }

    func testHalfwayThroughFirstUnitOfTwo() {
        let value = ComicProgress.percent(unitIdx: 0, pageIdx: 5, pageCount: 10, totalUnits: 2)
        XCTAssertEqual(value, 0.25, accuracy: 0.0001)
    }

    func testLastPageOfLastUnit() {
        let value = ComicProgress.percent(unitIdx: 1, pageIdx: 10, pageCount: 10, totalUnits: 2)
        XCTAssertEqual(value, 1.0, accuracy: 0.0001)
    }

    func testZeroUnitsSafe() {
        XCTAssertEqual(ComicProgress.percent(unitIdx: 0, pageIdx: 3, pageCount: 9, totalUnits: 0), 0)
    }
}

final class ProgressThrottleTests: XCTestCase {

    func testSavesOnlyAfterInterval() {
        var throttle = ProgressThrottle(minimumInterval: 1.5)
        let start = Date(timeIntervalSince1970: 1000)

        XCTAssertTrue(throttle.shouldSave(at: start), "第一次应写入")
        XCTAssertFalse(throttle.shouldSave(at: start.addingTimeInterval(0.5)))
        XCTAssertFalse(throttle.shouldSave(at: start.addingTimeInterval(1.4)))
        XCTAssertTrue(throttle.shouldSave(at: start.addingTimeInterval(1.6)))
    }
}
