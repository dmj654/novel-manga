import XCTest
@testable import NovelManga

final class EpubParserTests: XCTestCase {

    private func makeEpub(at url: URL) throws {
        let container = """
        <?xml version="1.0"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
          <rootfiles>
            <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
        """
        let opf = """
        <?xml version="1.0" encoding="utf-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="2.0">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:title>测试之书</dc:title>
            <dc:creator>某作者</dc:creator>
            <dc:description>一段简介</dc:description>
          </metadata>
          <manifest>
            <item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/>
            <item id="ch2" href="ch2.xhtml" media-type="application/xhtml+xml"/>
          </manifest>
          <spine>
            <itemref idref="ch1"/>
            <itemref idref="ch2"/>
          </spine>
        </package>
        """
        let ch1 = "<html><head><title>第一章</title></head><body><h1>第一章 启程</h1><p>正文一</p><p>第二段</p></body></html>"
        let ch2 = "<html><head><title>第二章</title></head><body><h1>第二章 抵达</h1><p>正文二</p></body></html>"

        try ZipFixture.makeZip(at: url, files: [
            ("mimetype", Data("application/epub+zip".utf8)),
            ("META-INF/container.xml", Data(container.utf8)),
            ("OEBPS/content.opf", Data(opf.utf8)),
            ("OEBPS/ch1.xhtml", Data(ch1.utf8)),
            ("OEBPS/ch2.xhtml", Data(ch2.utf8))
        ])
    }

    func testParsesMetadataAndChaptersInSpineOrder() throws {
        let dir = try ZipFixture.tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("测试.epub")
        try makeEpub(at: url)

        let parsed = try EpubParser.parse(archiveURL: url, fileName: "测试.epub")
        XCTAssertEqual(parsed.kind, .novel)
        XCTAssertEqual(parsed.title, "测试之书")
        XCTAssertEqual(parsed.author, "某作者")
        XCTAssertEqual(parsed.units.count, 2)
        XCTAssertEqual(parsed.units[0].title, "第一章 启程")
        XCTAssertTrue(parsed.units[0].text?.contains("正文一") == true)
        XCTAssertFalse(parsed.units[0].text?.contains("<p>") == true)
        XCTAssertEqual(parsed.units[1].title, "第二章 抵达")
    }

    func testBrokenArchiveThrows() throws {
        let dir = try ZipFixture.tempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("坏.epub")
        try ZipFixture.makeZip(at: url, files: [("readme.txt", Data("nothing".utf8))])

        XCTAssertThrowsError(try EpubParser.parse(archiveURL: url, fileName: "坏.epub"))
    }
}
