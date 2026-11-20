import Foundation

/// 漫画压缩包（ZIP/CBZ）解析：按自然页序收集图片
enum ComicParser {

    static let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "heic", "heif", "bmp", "tiff"]

    static func parse(archiveURL: URL, fileName: String) throws -> ParsedBook {
        let temp = try ZipExtractor.makeTempDirectory()
        defer { ZipExtractor.removeTempDirectory(temp) }
        try ZipExtractor.extractAll(archiveURL, to: temp)

        var images: [URL] = []
        if let enumerator = FileManager.default.enumerator(at: temp,
                                                         includingPropertiesForKeys: nil,
                                                         options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
            for case let url as URL in enumerator where imageExtensions.contains(url.pathExtension.lowercased()) {
                images.append(url)
            }
        }

        guard !images.isEmpty else { throw ImportError.emptyContent }

        let basePath = temp.path
        let relative: [(String, URL)] = images.map { url in
            var path = url.path
            if path.hasPrefix(basePath) { path = String(path.dropFirst(basePath.count)) }
            if path.hasPrefix("/") { path.removeFirst() }
            return (path, url)
        }
        let sorted = relative.sorted { NaturalSort.isOrderedBefore($0.0, $1.0) }

        let pages: [ParsedPage] = try sorted.enumerated().map { index, item in
            let data = try Data(contentsOf: item.1)
            let name = "\(String(format: "%04d", index + 1)).\(item.1.pathExtension.lowercased())"
            return ParsedPage(data: data, fileName: name, width: nil, height: nil)
        }

        let title = TxtParser.bookTitle(fileName: fileName, text: "")
        return ParsedBook(title: title,
                          author: nil,
                          kind: .comic,
                          units: [ParsedUnit(title: "全一册", text: nil, pages: pages)],
                          coverData: pages.first?.data,
                          intro: nil)
    }
}
