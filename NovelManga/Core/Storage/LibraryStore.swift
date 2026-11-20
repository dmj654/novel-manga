import Foundation
import GRDB

/// 数据访问收口：书架、目录、进度都从这里读写。
final class LibraryStore {
    let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue) throws {
        self.dbQueue = dbQueue
        try AppDatabase.migrate(dbQueue)
    }

    static func makeDefault() throws -> LibraryStore {
        try AppPaths.ensureDirectories()
        let queue = try AppDatabase.makeQueue(at: AppPaths.databaseURL)
        return try LibraryStore(dbQueue: queue)
    }

    static func makeInMemory() throws -> LibraryStore {
        let queue = try AppDatabase.makeInMemoryQueue()
        return try LibraryStore(dbQueue: queue)
    }

    // MARK: - Book

    func allBooks() throws -> [Book] {
        try dbQueue.read { db in
            try Book.fetchAll(db, sql: "SELECT * FROM books ORDER BY created_at DESC")
        }
    }

    func booksInShelf() throws -> [Book] {
        try dbQueue.read { db in
            try Book.fetchAll(db, sql: """
            SELECT * FROM books
            WHERE in_shelf = 1
            ORDER BY COALESCE(last_opened_at, favorited_at, created_at) DESC
            """)
        }
    }

    func book(id: String) throws -> Book? {
        try dbQueue.read { db in
            try Book.fetchOne(db, sql: "SELECT * FROM books WHERE id = ?", arguments: [id])
        }
    }

    func insert(_ book: Book) throws {
        try dbQueue.write { db in
            try book.insert(db)
        }
    }

    func update(_ book: Book) throws {
        try dbQueue.write { db in
            try book.update(db)
        }
    }

    /// 加入书架（D4：只有显式收藏才入书架）
    func addToShelf(bookID: String, now: Date = Date()) throws {
        try dbQueue.write { db in
            try db.execute(sql: """
            UPDATE books SET in_shelf = 1, favorited_at = ?, updated_at = ? WHERE id = ?
            """, arguments: [Int64(now.timeIntervalSince1970), Int64(now.timeIntervalSince1970), bookID])
        }
    }

    func removeFromShelf(bookID: String, now: Date = Date()) throws {
        try dbQueue.write { db in
            try db.execute(sql: """
            UPDATE books SET in_shelf = 0, updated_at = ? WHERE id = ?
            """, arguments: [Int64(now.timeIntervalSince1970), bookID])
        }
    }

    /// 删除书及其目录、页面、进度与本地文件
    func deleteBook(id: String) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM books WHERE id = ?", arguments: [id])
            try db.execute(sql: "DELETE FROM units WHERE book_id = ?", arguments: [id])
            try db.execute(sql: "DELETE FROM pages WHERE book_id = ?", arguments: [id])
            try db.execute(sql: "DELETE FROM progress WHERE book_id = ?", arguments: [id])
        }
        let folder = AppPaths.bookFolder(bookID: id)
        if FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.removeItem(at: folder)
        }
    }

    func touchOpened(bookID: String, now: Date = Date()) throws {
        try dbQueue.write { db in
            try db.execute(sql: "UPDATE books SET last_opened_at = ? WHERE id = ?",
                           arguments: [Int64(now.timeIntervalSince1970), bookID])
        }
    }

    // MARK: - Unit / Page

    func units(bookID: String) throws -> [Unit] {
        try dbQueue.read { db in
            try Unit.fetchAll(db, sql: "SELECT * FROM units WHERE book_id = ? ORDER BY idx ASC",
                              arguments: [bookID])
        }
    }

    func insertUnits(_ units: [Unit]) throws {
        guard !units.isEmpty else { return }
        try dbQueue.write { db in
            for unit in units { try unit.insert(db) }
        }
    }

    func pages(bookID: String, unitIdx: Int) throws -> [ComicPage] {
        try dbQueue.read { db in
            try ComicPage.fetchAll(db, sql: """
            SELECT * FROM pages WHERE book_id = ? AND unit_idx = ? ORDER BY page_idx ASC
            """, arguments: [bookID, unitIdx])
        }
    }

    func insertPages(_ pages: [ComicPage]) throws {
        guard !pages.isEmpty else { return }
        try dbQueue.write { db in
            for page in pages {
                try db.execute(sql: """
                INSERT OR REPLACE INTO pages (book_id, unit_idx, page_idx, url, local_path, width, height)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """, arguments: [page.bookID, page.unitIdx, page.pageIdx, page.url, page.localPath, page.width, page.height])
            }
        }
    }

    /// 一次性写入整本书的目录与页面（同一事务）
    func saveBook(book: Book, units: [Unit], pages: [ComicPage]) throws {
        try dbQueue.write { db in
            try book.insert(db)
            for unit in units { try unit.insert(db) }
            for page in pages {
                try db.execute(sql: """
                INSERT OR REPLACE INTO pages (book_id, unit_idx, page_idx, url, local_path, width, height)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """, arguments: [page.bookID, page.unitIdx, page.pageIdx, page.url, page.localPath, page.width, page.height])
            }
        }
    }

    // MARK: - Progress

    func progress(bookID: String) throws -> ReadingProgress? {
        try dbQueue.read { db in
            try ReadingProgress.fetchOne(db, sql: "SELECT * FROM progress WHERE book_id = ?",
                                         arguments: [bookID])
        }
    }

    func save(progress: ReadingProgress) throws {
        try dbQueue.write { db in
            try db.execute(sql: """
            INSERT INTO progress (book_id, unit_idx, char_offset, page_idx, percent, updated_at)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(book_id) DO UPDATE SET
              unit_idx = excluded.unit_idx,
              char_offset = excluded.char_offset,
              page_idx = excluded.page_idx,
              percent = excluded.percent,
              updated_at = excluded.updated_at
            """, arguments: [progress.bookID, progress.unitIdx, progress.charOffset,
                              progress.pageIdx, progress.percent, progress.updatedAt])
        }
    }
}
