import XCTest
@testable import NovelManga

final class ImportServiceTests: XCTestCase {

    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = try ZipFixture.tempDirectory()
    }

    override func tearDownWithError() throws {
        if let tempRoot { try? FileManager.default.removeItem(at: tempRoot) }
        tempRoot = nil
    }

    func testImportTxtCreatesShelfBookWithChapterFiles() throws {
        let store = try LibraryStore.makeInMemory()
        let service = ImportService(store: store, libraryRoot: tempRoot)

        let txtURL = tempRoot.appendingPathComponent("测试小说.txt")
        let content = """
        第一章 起
        第一章的内容。
        第二章 承
        第二章的内容。
        """
        try content.write(to: txtURL, atomically: true, encoding: .utf8)

        let book = try service.importFile(at: txtURL)
        XCTAssertEqual(book.title, "测试小说")
        XCTAssertEqual(book.kind, .novel)
        XCTAssertEqual(book.unitCount, 2)
        XCTAssertTrue(book.inShelf, "本地导入应自动入书架")

        let shelf = try store.booksInShelf()
        XCTAssertEqual(shelf.count, 1)

        let units = try store.units(bookID: book.id)
        XCTAssertEqual(units.count, 2)
        XCTAssertEqual(units[0].title, "第一章 起")

        let firstURL = try XCTUnwrap(units[0].url)
        let absolute = AppPaths.absoluteURL(forRelativePath: firstURL, root: tempRoot)
        XCTAssertTrue(FileManager.default.fileExists(atPath: absolute.path))
        let savedText = try String(contentsOf: absolute, encoding: .utf8)
        XCTAssertTrue(savedText.contains("第一章的内容"))
    }

    func testImportComicCreatesPages() throws {
        let store = try LibraryStore.makeInMemory()
        let service = ImportService(store: store, libraryRoot: tempRoot)

        let zipURL = tempRoot.appendingPathComponent("测试漫画.cbz")
        try ZipFixture.makeZip(at: zipURL, files: [
            ("1.jpg", Data("p1".utf8)),
            ("2.jpg", Data("p2".utf8))
        ])

        let book = try service.importFile(at: zipURL)
        XCTAssertEqual(book.kind, .comic)
        XCTAssertEqual(book.unitCount, 1)

        let pages = try store.pages(bookID: book.id, unitIdx: 0)
        XCTAssertEqual(pages.count, 2)
        for page in pages {
            let path = try XCTUnwrap(page.localPath)
            let absolute = AppPaths.absoluteURL(forRelativePath: path, root: tempRoot)
            XCTAssertTrue(FileManager.default.fileExists(atPath: absolute.path), "页面文件应已落盘")
        }
    }

    func testUnsupportedExtensionThrows() throws {
        let store = try LibraryStore.makeInMemory()
        let service = ImportService(store: store, libraryRoot: tempRoot)

        let url = tempRoot.appendingPathComponent("文档.docx")
        try Data("x".utf8).write(to: url)

        XCTAssertThrowsError(try service.importFile(at: url)) { error in
            guard case ImportError.unsupportedFormat = error else {
                return XCTFail("期望 unsupportedFormat，实际 \(error)")
            }
        }
    }

    func testBrokenZipThrowsAndLeavesLibraryEmpty() throws {
        let store = try LibraryStore.makeInMemory()
        let service = ImportService(store: store, libraryRoot: tempRoot)

        let url = tempRoot.appendingPathComponent("坏包.zip")
        try Data("not a zip".utf8).write(to: url)

        XCTAssertThrowsError(try service.importFile(at: url))
        XCTAssertTrue(try store.allBooks().isEmpty)
    }
}
