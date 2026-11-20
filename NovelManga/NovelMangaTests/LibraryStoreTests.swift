import XCTest
@testable import NovelManga

final class LibraryStoreTests: XCTestCase {

    private func makeStore() throws -> LibraryStore {
        try LibraryStore.makeInMemory()
    }

    func testInsertedBookIsNotInShelfUntilFavorited() throws {
        let store = try makeStore()
        let book = Book.makeLocal(title: "测试书", author: "作者", kind: .novel, coverPath: nil, unitCount: 3)
        try store.insert(book)

        XCTAssertTrue(try store.booksInShelf().isEmpty)
        XCTAssertEqual(try store.allBooks().count, 1)

        try store.addToShelf(bookID: book.id)
        let shelf = try store.booksInShelf()
        XCTAssertEqual(shelf.count, 1)
        XCTAssertEqual(shelf.first?.id, book.id)

        try store.removeFromShelf(bookID: book.id)
        XCTAssertTrue(try store.booksInShelf().isEmpty)
        XCTAssertEqual(try store.allBooks().count, 1, "移出书架不应删书")
    }

    func testUnitsAreOrderedByIndex() throws {
        let store = try makeStore()
        let book = Book.makeLocal(title: "章节书", author: nil, kind: .novel, coverPath: nil, unitCount: 3)
        try store.saveBook(book: book, units: [
            Unit(bookID: book.id, idx: 2, title: "第三章"),
            Unit(bookID: book.id, idx: 0, title: "第一章"),
            Unit(bookID: book.id, idx: 1, title: "第二章")
        ], pages: [])

        let units = try store.units(bookID: book.id)
        XCTAssertEqual(units.map { $0.idx }, [0, 1, 2])
        XCTAssertEqual(units.map { $0.title }, ["第一章", "第二章", "第三章"])
    }

    func testProgressRoundTripAndOverwrite() throws {
        let store = try makeStore()
        let book = Book.makeLocal(title: "进度书", author: nil, kind: .novel, coverPath: nil, unitCount: 10)
        try store.insert(book)

        try store.save(progress: ReadingProgress(bookID: book.id, unitIdx: 3, charOffset: 120, percent: 0.31))
        var progress = try XCTUnwrap(try store.progress(bookID: book.id))
        XCTAssertEqual(progress.unitIdx, 3)
        XCTAssertEqual(progress.charOffset, 120)

        try store.save(progress: ReadingProgress(bookID: book.id, unitIdx: 7, charOffset: 40, percent: 0.72))
        progress = try XCTUnwrap(try store.progress(bookID: book.id))
        XCTAssertEqual(progress.unitIdx, 7, "同一本书只应有一条进度")
        XCTAssertEqual(progress.charOffset, 40)
    }

    func testDeleteBookRemovesRelatedRows() throws {
        let store = try makeStore()
        let book = Book.makeLocal(title: "待删书", author: nil, kind: .comic, coverPath: nil, unitCount: 1)
        try store.saveBook(book: book,
                           units: [Unit(bookID: book.id, idx: 0, title: "全一册", pageCount: 2, cached: true)],
                           pages: [
                            ComicPage(bookID: book.id, unitIdx: 0, pageIdx: 0, url: nil, localPath: "a", width: nil, height: nil),
                            ComicPage(bookID: book.id, unitIdx: 0, pageIdx: 1, url: nil, localPath: "b", width: nil, height: nil)
                           ])
        try store.save(progress: ReadingProgress(bookID: book.id, unitIdx: 0, pageIdx: 1))

        try store.deleteBook(id: book.id)

        XCTAssertNil(try store.book(id: book.id))
        XCTAssertTrue(try store.units(bookID: book.id).isEmpty)
        XCTAssertTrue(try store.pages(bookID: book.id, unitIdx: 0).isEmpty)
        XCTAssertNil(try store.progress(bookID: book.id))
    }

    func testPagesAreOrderedByPageIndex() throws {
        let store = try makeStore()
        let book = Book.makeLocal(title: "漫画", author: nil, kind: .comic, coverPath: nil, unitCount: 1)
        try store.saveBook(book: book,
                           units: [Unit(bookID: book.id, idx: 0, title: "全一册", pageCount: 3, cached: true)],
                           pages: [
                            ComicPage(bookID: book.id, unitIdx: 0, pageIdx: 2, url: nil, localPath: "3", width: nil, height: nil),
                            ComicPage(bookID: book.id, unitIdx: 0, pageIdx: 0, url: nil, localPath: "1", width: nil, height: nil),
                            ComicPage(bookID: book.id, unitIdx: 0, pageIdx: 1, url: nil, localPath: "2", width: nil, height: nil)
                           ])

        let pages = try store.pages(bookID: book.id, unitIdx: 0)
        XCTAssertEqual(pages.map { $0.pageIdx }, [0, 1, 2])
        XCTAssertEqual(pages.map { $0.localPath }, ["1", "2", "3"])
    }
}
