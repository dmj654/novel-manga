import Foundation

enum AppPaths {
    static let appFolderName = "NovelManga"

    /// 应用数据根目录（Application Support/NovelManga）
    static var libraryRoot: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent(appFolderName, isDirectory: true)
    }

    static var databaseURL: URL { libraryRoot.appendingPathComponent("library.sqlite") }
    static var booksRoot: URL { libraryRoot.appendingPathComponent("Books", isDirectory: true) }
    static var coversRoot: URL { libraryRoot.appendingPathComponent("Covers", isDirectory: true) }

    static func ensureDirectories() throws {
        let fm = FileManager.default
        for dir in [libraryRoot, booksRoot, coversRoot] {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    static func bookFolder(bookID: String) -> URL {
        booksRoot.appendingPathComponent(bookID, isDirectory: true)
    }

    /// 把绝对路径转成相对 libraryRoot 的存储路径，便于整包备份/换机恢复
    static func relativePath(for url: URL, root: URL = libraryRoot) -> String {
        let rootPath = root.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        if path.hasPrefix(rootPath) {
            var sub = String(path.dropFirst(rootPath.count))
            if sub.hasPrefix("/") { sub.removeFirst() }
            return sub
        }
        return path
    }

    static func absoluteURL(forRelativePath path: String, root: URL = libraryRoot) -> URL {
        if path.hasPrefix("/") { return URL(fileURLWithPath: path) }
        return root.appendingPathComponent(path)
    }
}
