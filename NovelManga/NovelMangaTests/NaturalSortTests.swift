import XCTest
@testable import NovelManga

final class NaturalSortTests: XCTestCase {

    func testPagesAreOrderedNumerically() {
        let input = ["10.jpg", "2.jpg", "1.jpg", "100.jpg", "20.jpg"]
        XCTAssertEqual(NaturalSort.sorted(input),
                       ["1.jpg", "2.jpg", "10.jpg", "20.jpg", "100.jpg"])
    }

    func testLeadingZerosDoNotChangeOrder() {
        let input = ["page_08.png", "page_1.png", "page_10.png", "page_2.png"]
        XCTAssertEqual(NaturalSort.sorted(input),
                       ["page_1.png", "page_2.png", "page_08.png", "page_10.png"])
    }

    func testChineseChapterTitlesWithNumbers() {
        let input = ["第10章", "第2章", "第1章", "第100章"]
        XCTAssertEqual(NaturalSort.sorted(input),
                       ["第1章", "第2章", "第10章", "第100章"])
    }

    func testCaseInsensitiveForLatinNames() {
        let input = ["Chapter2.txt", "chapter10.txt", "Chapter1.txt"]
        XCTAssertEqual(NaturalSort.sorted(input),
                       ["Chapter1.txt", "Chapter2.txt", "chapter10.txt"])
    }

    func testOrderingIsTotalAndStable() {
        let input = ["b", "a", "b", "a"]
        let output = NaturalSort.sorted(input)
        XCTAssertEqual(output.count, input.count, "排序不能丢元素")
        XCTAssertEqual(output, ["a", "a", "b", "b"])
    }

    func testMixedNumberAndTextChunks() {
        let input = ["vol1_ch2.jpg", "vol1_ch10.jpg", "vol2_ch1.jpg", "vol1_ch1.jpg"]
        XCTAssertEqual(NaturalSort.sorted(input),
                       ["vol1_ch1.jpg", "vol1_ch2.jpg", "vol1_ch10.jpg", "vol2_ch1.jpg"])
    }

    func testEqualStringsCompareDeterministically() {
        XCTAssertFalse(NaturalSort.isOrderedBefore("same", "same"))
        XCTAssertFalse(NaturalSort.isOrderedBefore("Same", "same"))
    }
}
