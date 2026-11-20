import Foundation

/// EPUB 解析：container.xml → .opf（元数据 + manifest + spine）→ 逐章抽正文
enum EpubParser {

    struct ManifestItem {
        var href: String
        var mediaType: String
        var properties: String
    }

    static func parse(archiveURL: URL, fileName: String) throws -> ParsedBook {
        let temp = try ZipExtractor.makeTempDirectory()
        defer { ZipExtractor.removeTempDirectory(temp) }
        try ZipExtractor.extractAll(archiveURL, to: temp)

        guard let opfPath = findRootFilePath(in: temp) else {
            throw ImportError.brokenArchive(fileName)
        }
        let opfURL = temp.appendingPathComponent(opfPath)
        let opf = try parseOPF(at: opfURL)
        let baseDir = opfURL.deletingLastPathComponent()

        var units: [ParsedUnit] = []
        var index = 0
        for idref in opf.spineOrder {
            guard let item = opf.manifest[idref] else { continue }
            let media = item.mediaType.lowercased()
            guard media.contains("html") || media.contains("xml") || media == "text/plain" else { continue }
            if item.properties.contains("nav") { continue }
            index += 1

            let fileURL = resolve(item.href, base: baseDir)
            guard let raw = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
            let body = HTMLTextExtractor.plainText(from: raw)
            guard !body.isEmpty else { continue }
            let title = HTMLTextExtractor.title(from: raw) ?? "第\(index)章"
            units.append(ParsedUnit(title: title, text: body, pages: []))
        }

        if units.isEmpty {
            // 兜底：spine 不可用时按文件顺序扫所有 html
            var allFiles: [URL] = []
            if let enumerator = FileManager.default.enumerator(at: temp,
                                                             includingPropertiesForKeys: nil,
                                                             options: [.skipsHiddenFiles]) {
                for case let url as URL in enumerator { allFiles.append(url) }
            }
            let htmlFiles = allFiles
                .filter { ["html", "xhtml", "htm"].contains($0.pathExtension.lowercased()) }
                .sorted { NaturalSort.isOrderedBefore($0.lastPathComponent, $1.lastPathComponent) }
            for (offset, fileURL) in htmlFiles.enumerated() {
                guard let raw = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
                let body = HTMLTextExtractor.plainText(from: raw)
                guard !body.isEmpty else { continue }
                let title = HTMLTextExtractor.title(from: raw) ?? "第\(offset + 1)章"
                units.append(ParsedUnit(title: title, text: body, pages: []))
            }
        }

        guard !units.isEmpty else { throw ImportError.emptyContent }

        let cover = loadCover(opf: opf, base: baseDir)

        return ParsedBook(title: opf.title ?? TxtParser.bookTitle(fileName: fileName, text: ""),
                          author: opf.creator,
                          kind: .novel,
                          units: units,
                          coverData: cover,
                          intro: opf.description)
    }

    // MARK: - container.xml

    private static func findRootFilePath(in directory: URL) -> String? {
        let containerURL = directory.appendingPathComponent("META-INF/container.xml")
        guard let data = try? Data(contentsOf: containerURL) else { return nil }
        let delegate = ContainerDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.rootPath
    }

    private final class ContainerDelegate: NSObject, XMLParserDelegate {
        var rootPath: String?
        func parser(_ parser: XMLParser, didStartElement elementName: String,
                    namespaceURI: String?, qualifiedName qName: String?,
                    attributes attributeDict: [String: String] = [:]) {
            if elementName == "rootfile", rootPath == nil {
                rootPath = attributeDict["full-path"]
            }
        }
    }

    // MARK: - OPF

    struct OPF {
        var title: String?
        var creator: String?
        var description: String?
        var manifest: [String: ManifestItem]
        var spineOrder: [String]
    }

    private static func parseOPF(at url: URL) throws -> OPF {
        guard let data = try? Data(contentsOf: url) else { throw ImportError.brokenArchive(url.lastPathComponent) }
        let delegate = OpfDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return OPF(title: delegate.title,
                   creator: delegate.creator,
                   description: delegate.summary,
                   manifest: delegate.manifest,
                   spineOrder: delegate.spineOrder)
    }

    private final class OpfDelegate: NSObject, XMLParserDelegate {
        var title: String?
        var creator: String?
        var summary: String?
        var manifest: [String: ManifestItem] = [:]
        var spineOrder: [String] = []

        private var currentText = ""
        private var capturing = false

        func parser(_ parser: XMLParser, didStartElement elementName: String,
                    namespaceURI: String?, qualifiedName qName: String?,
                    attributes attributeDict: [String: String] = [:]) {
            let local = elementName.components(separatedBy: ":").last ?? elementName
            currentText = ""
            capturing = ["title", "creator", "description"].contains(local)

            switch local {
            case "item":
                if let id = attributeDict["id"], let href = attributeDict["href"] {
                    manifest[id] = ManifestItem(href: href,
                                                mediaType: attributeDict["media-type"] ?? "",
                                                properties: attributeDict["properties"] ?? "")
                }
            case "itemref":
                if let idref = attributeDict["idref"] { spineOrder.append(idref) }
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            if capturing { currentText += string }
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String,
                    namespaceURI: String?, qualifiedName qName: String?) {
            let local = elementName.components(separatedBy: ":").last ?? elementName
            let value = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { capturing = false; return }

            switch local {
            case "title" where title == nil: title = value
            case "creator" where creator == nil: creator = value
            case "description" where summary == nil: summary = value
            default: break
            }
            capturing = false
        }
    }

    // MARK: - 辅助

    private static func resolve(_ href: String, base: URL) -> URL {
        let decoded = href.removingPercentEncoding ?? href
        if decoded.hasPrefix("/") {
            return base.appendingPathComponent(String(decoded.dropFirst()))
        }
        return base.appendingPathComponent(decoded).standardizedFileURL
    }

    private static func loadCover(opf: OPF, base: URL) -> Data? {
        let coverItem = opf.manifest.values.first { $0.properties.contains("cover-image") }
            ?? opf.manifest.first { $0.key.lowercased().contains("cover") && $0.value.mediaType.hasPrefix("image/") }?.value
            ?? opf.manifest.values.first { $0.mediaType.hasPrefix("image/") && $0.href.lowercased().contains("cover") }
        guard let item = coverItem else { return nil }
        return try? Data(contentsOf: resolve(item.href, base: base))
    }
}
