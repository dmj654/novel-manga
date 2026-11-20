import Foundation
import SwiftUI

/// 依赖容器：数据库、仓储、导入服务集中在这里，视图只读环境。
@MainActor
final class AppEnvironment: ObservableObject {
    static let shared = AppEnvironment()

    let store: LibraryStore?
    let importService: ImportService?
    let startupError: String?

    @Published var shelfBooks: [Book] = []
    @Published var recentBooks: [Book] = []
    @Published var homeCards: [HomeCard] = []
    @Published var continueBooks: [Book] = []
    @Published var unstartedBooks: [Book] = []
    @Published var isImporting = false
    @Published var importAlertMessage: String?
    @Published var lastImportedBook: Book?

    init() {
        do {
            try PendingRestore.applyIfNeeded()
            let store = try LibraryStore.makeDefault()
            self.store = store
            self.importService = ImportService(store: store)
            self.startupError = nil
        } catch {
            self.store = nil
            self.importService = nil
            self.startupError = error.localizedDescription
        }
        reload()
    }

    /// 测试 / 预览用：注入一个现成 store
    init(store: LibraryStore) {
        self.store = store
        self.importService = ImportService(store: store)
        self.startupError = nil
        reload()
    }

    func reload() {
        guard let store else { return }
        do {
            shelfBooks = try store.booksInShelf()
            recentBooks = try store.allBooks()
            try store.ensureDefaultCards()
            homeCards = try store.cards()
            continueBooks = try store.continueReading()
            unstartedBooks = try store.unstartedShelfBooks()
        } catch {
            importAlertMessage = "读取书库失败：\(error.localizedDescription)"
        }
    }

    func saveCards(_ cards: [HomeCard]) {
        try? store?.saveCards(cards)
        reload()
    }

    func importFiles(at urls: [URL]) {
        guard let service = importService else {
            importAlertMessage = startupError ?? "数据层未就绪"
            return
        }
        isImporting = true
        var succeeded: [Book] = []
        var failures: [String] = []

        for url in urls {
            do {
                let book = try service.importFile(at: url)
                succeeded.append(book)
            } catch {
                failures.append("\(url.lastPathComponent)：\(error.localizedDescription)")
            }
        }

        isImporting = false
        lastImportedBook = succeeded.last
        reload()

        if failures.isEmpty {
            importAlertMessage = succeeded.isEmpty ? nil : "已导入 \(succeeded.count) 本"
        } else if succeeded.isEmpty {
            importAlertMessage = "导入失败\n" + failures.joined(separator: "\n")
        } else {
            importAlertMessage = "成功 \(succeeded.count) 本，失败 \(failures.count) 本\n" + failures.joined(separator: "\n")
        }
    }

    func addToShelf(bookID: String) {
        try? store?.addToShelf(bookID: bookID)
        reload()
    }

    func removeFromShelf(bookID: String) {
        try? store?.removeFromShelf(bookID: bookID)
        reload()
    }

    func delete(bookID: String) {
        try? store?.deleteBook(id: bookID)
        reload()
    }

    // MARK: - 阅读

    func units(bookID: String) -> [Unit] {
        (try? store?.units(bookID: bookID)) ?? []
    }

    func pages(bookID: String, unitIdx: Int) -> [ComicPage] {
        (try? store?.pages(bookID: bookID, unitIdx: unitIdx)) ?? []
    }

    func progress(bookID: String) -> ReadingProgress? {
        try? store?.progress(bookID: bookID)
    }

    func saveProgress(_ progress: ReadingProgress) {
        try? store?.save(progress: progress)
    }

    func touchOpened(bookID: String) {
        try? store?.touchOpened(bookID: bookID)
        reload()
    }

    // MARK: - 书源 / 搜索

    let sourceClient = SourceClient()

    func sources(enabledOnly: Bool = true) -> [Source] {
        guard let store else { return [] }
        return (try? (enabledOnly ? store.enabledSources() : store.sources())) ?? []
    }

    func addSource(json: String) throws {
        let rule = try SourceRule.decode(from: json)
        let source = try Source(rule: rule)
        try store?.save(source: source)
    }

    func deleteSource(id: String) {
        try? store?.deleteSource(id: id)
    }

    func setSourceEnabled(id: String, enabled: Bool) {
        try? store?.setSourceEnabled(id: id, enabled: enabled)
    }

    func localSearch(_ keyword: String) -> [Book] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let all = recentBooks
        let lowered = trimmed.lowercased()
        return all.filter { book in
            book.title.lowercased().contains(lowered)
                || (book.author?.lowercased().contains(lowered) ?? false)
        }
    }

    /// 在线书入库（D4：只有用户点收藏才进书架）
    func addOnlineBook(detail: OnlineDetail,
                       rule: SourceRule,
                       detailPath: String,
                       chapters: [OnlineChapter],
                       toShelf: Bool) throws -> Book {
        var book = Book.makeLocal(title: detail.name,
                                  author: detail.author,
                                  kind: rule.isComic ? .comic : .novel,
                                  coverPath: detail.coverURL,
                                  unitCount: chapters.count)
        book.origin = BookOrigin.online.rawValue
        book.sourceID = rule.id
        book.remoteKey = detailPath
        book.intro = detail.intro
        book.category = detail.category
        book.serialStatus = detail.serialStatus?.rawValue
        book.inShelf = toShelf
        book.favoritedAt = toShelf ? book.createdAt : nil

        let units = chapters.enumerated().map { index, chapter in
            Unit(bookID: book.id,
                 idx: index,
                 title: chapter.title,
                 url: chapter.path,
                 pageCount: nil,
                 cached: false)
        }
        try store?.saveBook(book: book, units: units, pages: [])
        reload()
        return book
    }

    // MARK: - 备份

    func exportBackup() throws -> URL {
        guard let store else { throw ImportError.unreadable("数据层未就绪") }
        try store.dbQueue.write { db in
            try db.execute(sql: "PRAGMA wal_checkpoint(TRUNCATE)")
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        let name = "NovelManga-\(formatter.string(from: Date())).nmbak"
        let destination = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(name)
        let manifest = BackupManifest(schemaVersion: 1,
                                      exportTime: Int64(Date().timeIntervalSince1970),
                                      bookCount: recentBooks.count,
                                      includesBooks: true)
        try BackupService().export(to: destination, manifest: manifest)
        return destination
    }

    func stageRestore(from url: URL) throws -> BackupManifest {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        return try PendingRestore.stage(archiveURL: url)
    }
}
