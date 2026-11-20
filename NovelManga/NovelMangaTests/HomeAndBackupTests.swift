import XCTest
@testable import NovelManga

final class HomeCardTests: XCTestCase {

    func testDefaultCardsAreSeededOnce() throws {
        let store = try LibraryStore.makeInMemory()
        try store.ensureDefaultCards()
        let cards = try store.cards()
        XCTAssertEqual(cards.count, 3)
        XCTAssertEqual(cards.map { $0.cardType }, [.continueReading, .newBooks, .recommend])

        try store.ensureDefaultCards()
        XCTAssertEqual(try store.cards().count, 3, "重复调用不应重复插入")
    }

    func testSaveCardsAppliesOrderAndRemoval() throws {
        let store = try LibraryStore.makeInMemory()
        try store.ensureDefaultCards()

        var cards = try store.cards()
        cards.removeAll { $0.cardType == .recommend }
        cards.insert(HomeCard(type: .category, sort: 99), at: 0)
        try store.saveCards(cards)

        let saved = try store.cards()
        XCTAssertEqual(saved.map { $0.cardType }, [.category, .continueReading, .newBooks])
        XCTAssertEqual(saved.map { $0.sort }, [0, 1, 2], "sort 应连续，拖动后顺序稳定")
    }

    func testContinueReadingIsOrderedByProgressTime() throws {
        let store = try LibraryStore.makeInMemory()
        let first = Book.makeLocal(title: "先读的", author: nil, kind: .novel, coverPath: nil, unitCount: 1)
        let second = Book.makeLocal(title: "后读的", author: nil, kind: .novel, coverPath: nil, unitCount: 1)
        try store.insert(first)
        try store.insert(second)

        try store.save(progress: ReadingProgress(bookID: first.id, unitIdx: 0,
                                                 updatedAt: Date(timeIntervalSince1970: 100)))
        try store.save(progress: ReadingProgress(bookID: second.id, unitIdx: 0,
                                                 updatedAt: Date(timeIntervalSince1970: 200)))

        let books = try store.continueReading()
        XCTAssertEqual(books.map { $0.title }, ["后读的", "先读的"])
    }

    func testUnstartedShelfBooksExcludesProgressAndNonShelf() throws {
        let store = try LibraryStore.makeInMemory()
        let read = Book.makeLocal(title: "读过的", author: nil, kind: .novel, coverPath: nil, unitCount: 1)
        var notStarted = Book.makeLocal(title: "没读过的", author: nil, kind: .novel, coverPath: nil, unitCount: 1)
        notStarted.inShelf = true
        var notInShelf = Book.makeLocal(title: "不在书架", author: nil, kind: .novel, coverPath: nil, unitCount: 1)

        try store.insert(read)
        try store.insert(notStarted)
        try store.insert(notInShelf)
        try store.addToShelf(bookID: read.id)
        try store.save(progress: ReadingProgress(bookID: read.id, unitIdx: 0))

        let books = try store.unstartedShelfBooks()
        XCTAssertEqual(books.map { $0.title }, ["没读过的"])
        _ = notInShelf.id
    }
}

final class BackupServiceTests: XCTestCase {

    private func makeLibraryRoot() throws -> URL {
        let root = try ZipFixture.tempDirectory()
        try Data("sqlite-bytes".utf8).write(to: root.appendingPathComponent("library.sqlite"))
        let books = root.appendingPathComponent("Books")
        try FileManager.default.createDirectory(at: books, withIntermediateDirectories: true)
        try Data("chapter".utf8).write(to: books.appendingPathComponent("1.txt"))
        let covers = root.appendingPathComponent("Covers")
        try FileManager.default.createDirectory(at: covers, withIntermediateDirectories: true)
        try Data("cover".utf8).write(to: covers.appendingPathComponent("c.jpg"))
        return root
    }

    func testExportProducesArchiveWithManifestAndData() throws {
        let root = try makeLibraryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let archiveURL = root.deletingLastPathComponent()
            .appendingPathComponent("backup-\(UUID().uuidString).nmbak")

        let manifest = BackupManifest(schemaVersion: 1, exportTime: 123, bookCount: 2, includesBooks: true)
        try BackupService(root: root).export(to: archiveURL, manifest: manifest)

        let inspected = try BackupService.inspect(archiveURL: archiveURL)
        XCTAssertEqual(inspected.bookCount, 2)
        XCTAssertEqual(inspected.schemaVersion, 1)

        let restoreRoot = try ZipFixture.tempDirectory()
        defer { try? FileManager.default.removeItem(at: restoreRoot) }
        _ = try BackupService.extract(archiveURL: archiveURL, to: restoreRoot)

        XCTAssertTrue(FileManager.default.fileExists(atPath: restoreRoot.appendingPathComponent("library.sqlite").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: restoreRoot.appendingPathComponent("Books/1.txt").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: restoreRoot.appendingPathComponent("Covers/c.jpg").path))
        let sqlite = try String(contentsOf: restoreRoot.appendingPathComponent("library.sqlite"), encoding: .utf8)
        XCTAssertEqual(sqlite, "sqlite-bytes")
    }

    func testInspectRejectsArchiveWithoutManifest() throws {
        let dir = try ZipFixture.tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("bad.nmbak")
        try ZipFixture.makeZip(at: url, files: [("library.sqlite", Data("x".utf8))])

        XCTAssertThrowsError(try BackupService.inspect(archiveURL: url))
    }

    func testInspectRejectsUnsupportedSchemaVersion() throws {
        let dir = try ZipFixture.tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("v9.nmbak")
        let json = #"{"schemaVersion":9,"exportTime":0,"bookCount":0,"includesBooks":false}"#
        try ZipFixture.makeZip(at: url, files: [("manifest.json", Data(json.utf8))])

        XCTAssertThrowsError(try BackupService.inspect(archiveURL: url))
    }
}
