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
    @Published var isImporting = false
    @Published var importAlertMessage: String?
    @Published var lastImportedBook: Book?

    init() {
        do {
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
        } catch {
            importAlertMessage = "读取书库失败：\(error.localizedDescription)"
        }
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
}
