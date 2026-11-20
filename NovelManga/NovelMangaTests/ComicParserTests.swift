import XCTest
@testable import NovelManga

final class ComicParserTests: XCTestCase {

    func testPagesAreSortedNumericallyNotLexically() throws {
        let dir = try ZipFixture.tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let zipURL = dir.appendingPathComponent("漫画.zip")

        try ZipFixture.makeZip(at: zipURL, files: [
            ("1.jpg", Data("page-1".utf8)),
            ("2.jpg", Data("page-2".utf8)),
            ("10.jpg", Data("page-10".utf8))
        ])

        let parsed = try ComicParser.parse(archiveURL: zipURL, fileName: "某漫画.zip")
        XCTAssertEqual(parsed.kind, .comic)
        XCTAssertEqual(parsed.units.count, 1)
        XCTAssertEqual(parsed.units[0].pages.count, 3)
        XCTAssertEqual(parsed.units[0].pages[0].data, Data("page-1".utf8))
        XCTAssertEqual(parsed.units[0].pages[1].data, Data("page-2".utf8))
        XCTAssertEqual(parsed.units[0].pages[2].data, Data("page-10".utf8))
        XCTAssertEqual(parsed.title, "某漫画")
    }

    func testNestedFolderImagesAreIncluded() throws {
        let dir = try ZipFixture.tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let zipURL = dir.appendingPathComponent("嵌套.cbz")

        try ZipFixture.makeZip(at: zipURL, files: [
            ("第1话/001.png", Data("a".utf8)),
            ("第1话/002.png", Data("b".utf8)),
            ("说明.txt", Data("ignore".utf8))
        ])

        let parsed = try ComicParser.parse(archiveURL: zipURL, fileName: "嵌套.cbz")
        XCTAssertEqual(parsed.units[0].pages.count, 2)
        XCTAssertEqual(parsed.units[0].pages[0].data, Data("a".utf8))
    }

    func testZipWithoutImagesThrowsEmptyContent() throws {
        let dir = try ZipFixture.tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let zipURL = dir.appendingPathComponent("无图.zip")

        try ZipFixture.makeZip(at: zipURL, files: [("readme.txt", Data("no image".utf8))])

        XCTAssertThrowsError(try ComicParser.parse(archiveURL: zipURL, fileName: "无图.zip")) { error in
            guard case ImportError.emptyContent = error else {
                return XCTFail("期望 emptyContent，实际 \(error)")
            }
        }
    }
}
