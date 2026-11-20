import Foundation
import ZIPFoundation

/// ZIP / CBZ / EPUB 解压到临时目录
enum ZipExtractor {
    static func extractAll(_ archiveURL: URL, to directory: URL) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let archive = Archive(url: archiveURL, accessMode: .read) else {
            throw ImportError.brokenArchive(archiveURL.lastPathComponent)
        }
        var extracted = 0
        for entry in archive {
            guard entry.type == .file else { continue }
            let destination = directory.appendingPathComponent(entry.path)
            try fm.createDirectory(at: destination.deletingLastPathComponent(),
                                   withIntermediateDirectories: true)
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            _ = try archive.extract(entry, to: destination)
            extracted += 1
        }
        guard extracted > 0 else { throw ImportError.brokenArchive(archiveURL.lastPathComponent) }
        return directory
    }

    static func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("nm-import-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func removeTempDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
