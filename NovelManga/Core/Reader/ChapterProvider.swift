import Foundation

protocol ChapterProviding {
    func text(for unit: Unit) async throws -> String
}

struct LocalChapterProvider: ChapterProviding {
    let root: URL

    init(root: URL = AppPaths.libraryRoot) {
        self.root = root
    }

    func text(for unit: Unit) async throws -> String {
        try ChapterTextStore(root: root).text(for: unit)
    }
}

struct OnlineChapterProvider: ChapterProviding {
    let client: SourceClient
    let rule: SourceRule

    func text(for unit: Unit) async throws -> String {
        guard let path = unit.url else { throw SourceError.emptyResult("章节地址缺失") }
        return try await client.content(for: OnlineChapter(title: unit.title ?? "", path: path), rule: rule)
    }
}
