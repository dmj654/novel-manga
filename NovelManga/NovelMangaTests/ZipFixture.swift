import Foundation
import XCTest
import ZIPFoundation

/// 测试用的最小 ZIP 打包器
enum ZipFixture {
    static func makeZip(at url: URL, files: [(path: String, data: Data)]) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) { try fm.removeItem(at: url) }
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let archive = try Archive(url: url, accessMode: .create)
        for file in files {
            let payload = file.data
            try archive.addEntry(with: file.path,
                                 type: .file,
                                 uncompressedSize: Int64(payload.count),
                                 provider: { position, size in
                let start = Int(position)
                let end = min(start + size, payload.count)
                guard start < end else { return Data() }
                return payload.subdata(in: start..<end)
            })
        }
    }

    static func tempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("nm-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
