import Foundation

/// 导入调度：按扩展名分发解析器，落盘正文 / 页面，写入数据库
struct ImportService {
    let store: LibraryStore
    /// 数据根目录，默认 Application Support/NovelManga；测试可注入临时目录
    let libraryRoot: URL

    init(store: LibraryStore, libraryRoot: URL = AppPaths.libraryRoot) {
        self.store = store
        self.libraryRoot = libraryRoot
    }

    private var booksRoot: URL {
        libraryRoot.appendingPathComponent("Books", isDirectory: true)
    }

    private func bookFolder(bookID: String) -> URL {
        booksRoot.appendingPathComponent(bookID, isDirectory: true)
    }

    /// 解析 + 入库 + 落盘。返回入库后的书。
    @discardableResult
    func importFile(at url: URL) throws -> Book {
        let ext = url.pathExtension.lowercased()
        let fileName = url.lastPathComponent

        let parsed: ParsedBook
        switch ext {
        case "txt", "text":
            let data = try readData(at: url, fileName: fileName)
            parsed = try TxtParser.parse(data: data, fileName: fileName)
        case "epub":
            parsed = try EpubParser.parse(archiveURL: url, fileName: fileName)
        case "zip", "cbz":
            parsed = try ComicParser.parse(archiveURL: url, fileName: fileName)
        case "cbr":
            throw ImportError.unsupportedFormat("cbr（暂支持 zip/cbz）")
        default:
            throw ImportError.unsupportedFormat(ext.isEmpty ? "无扩展名" : ext)
        }

        guard !parsed.units.isEmpty else { throw ImportError.emptyContent }
        return try persist(parsed)
    }

    private func readData(at url: URL, fileName: String) throws -> Data {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            return try Data(contentsOf: url)
        } catch {
            throw ImportError.unreadable(fileName)
        }
    }

    private func persist(_ parsed: ParsedBook) throws -> Book {
        let fm = FileManager.default
        try fm.createDirectory(at: booksRoot, withIntermediateDirectories: true)

        var book = Book.makeLocal(title: parsed.title,
                                  author: parsed.author,
                                  kind: parsed.kind,
                                  coverPath: nil,
                                  unitCount: parsed.units.count)
        // 本地导入即入书架（D4 只约束在线书）
        book.inShelf = true
        book.favoritedAt = book.createdAt
        book.intro = parsed.intro

        let folder = bookFolder(bookID: book.id)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)

        if let coverData = parsed.coverData {
            let coverURL = folder.appendingPathComponent("cover.img")
            try coverData.write(to: coverURL)
            book.coverPath = AppPaths.relativePath(for: coverURL, root: libraryRoot)
        }

        var units: [Unit] = []
        var pages: [ComicPage] = []

        switch parsed.kind {
        case .novel:
            for (index, item) in parsed.units.enumerated() {
                let text = item.text ?? ""
                let fileName = String(format: "%04d.txt", index + 1)
                let fileURL = folder.appendingPathComponent(fileName)
                try text.write(to: fileURL, atomically: true, encoding: .utf8)
                units.append(Unit(bookID: book.id,
                                  idx: index,
                                  title: item.title,
                                  url: AppPaths.relativePath(for: fileURL, root: libraryRoot),
                                  pageCount: nil,
                                  cached: true))
            }
        case .comic:
            for (index, item) in parsed.units.enumerated() {
                units.append(Unit(bookID: book.id,
                                  idx: index,
                                  title: item.title,
                                  url: nil,
                                  pageCount: item.pages.count,
                                  cached: true))
                for (pageIndex, page) in item.pages.enumerated() {
                    let pageFileName = "\(String(format: "%02d", index + 1))-\(page.fileName)"
                    let fileURL = folder.appendingPathComponent(pageFileName)
                    try page.data.write(to: fileURL)
                    pages.append(ComicPage(bookID: book.id,
                                           unitIdx: index,
                                           pageIdx: pageIndex,
                                           url: nil,
                                           localPath: AppPaths.relativePath(for: fileURL, root: libraryRoot),
                                           width: page.width,
                                           height: page.height))
                }
            }
        }

        try store.saveBook(book: book, units: units, pages: pages)
        return book
    }
}
