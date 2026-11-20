import Foundation

/// 读章节正文：本地缓存文件优先
struct ChapterTextStore {
    let root: URL

    init(root: URL = AppPaths.libraryRoot) {
        self.root = root
    }

    func text(for unit: Unit) throws -> String {
        guard let relative = unit.url else { throw ImportError.emptyContent }
        let url = AppPaths.absoluteURL(forRelativePath: relative, root: root)
        guard let data = try? Data(contentsOf: url) else {
            throw ImportError.unreadable(relative)
        }
        guard let text = TxtParser.decode(data) else {
            throw ImportError.unreadable(relative)
        }
        return text
    }
}
