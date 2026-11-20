import Foundation
import ZIPFoundation

struct BackupManifest: Codable, Hashable {
    var schemaVersion: Int
    var exportTime: Int64
    var bookCount: Int
    var includesBooks: Bool
}

/// .nmbak 备份：sqlite + 封面 + 可选正文，整包可搬运（AC-22 ~ AC-24）
struct BackupService {
    let root: URL

    init(root: URL = AppPaths.libraryRoot) {
        self.root = root
    }

    func export(to destination: URL, manifest: BackupManifest) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }

        let archive = try Archive(url: destination, accessMode: .create)

        // sqlite（调用方应已 checkpoint）
        let dbURL = root.appendingPathComponent("library.sqlite")
        if fm.fileExists(atPath: dbURL.path) {
            try addFile(dbURL, as: "library.sqlite", to: archive)
        }

        // manifest
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        try archive.addEntry(with: "manifest.json",
                             type: .file,
                             uncompressedSize: Int64(data.count),
                             provider: { position, size in
            let start = Int(position)
            let end = min(start + size, data.count)
            guard start < end else { return Data() }
            return data.subdata(in: start..<end)
        })

        for folder in ["Covers", "Books"] {
            let folderURL = root.appendingPathComponent(folder)
            guard fm.fileExists(atPath: folderURL.path) else { continue }
            guard let enumerator = fm.enumerator(at: folderURL, includingPropertiesForKeys: [.isRegularFileKey]) else { continue }
            for case let fileURL as URL in enumerator {
                let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                guard values.isRegularFile == true else { continue }
                let relative = "\(folder)/" + fileURL.lastPathComponent
                try addFile(fileURL, as: relative, to: archive)
            }
        }
    }

    static func inspect(archiveURL: URL) throws -> BackupManifest {
        guard let archive = Archive(url: archiveURL, accessMode: .read) else {
            throw ImportError.brokenArchive(archiveURL.lastPathComponent)
        }
        guard let entry = archive["manifest.json"] else {
            throw ImportError.brokenArchive("缺少 manifest.json")
        }
        var buffer = Data()
        _ = try archive.extract(entry) { chunk in buffer.append(chunk) }
        guard let manifest = try? JSONDecoder().decode(BackupManifest.self, from: buffer) else {
            throw ImportError.brokenArchive("manifest.json 无法解析")
        }
        guard manifest.schemaVersion == 1 else {
            throw ImportError.brokenArchive("备份版本不支持：\(manifest.schemaVersion)")
        }
        return manifest
    }

    /// 解压到目标目录（覆盖同名文件）
    static func extract(archiveURL: URL, to directory: URL) throws -> BackupManifest {
        let manifest = try inspect(archiveURL: archiveURL)
        guard let archive = Archive(url: archiveURL, accessMode: .read) else {
            throw ImportError.brokenArchive(archiveURL.lastPathComponent)
        }
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)

        for entry in archive where entry.type == .file {
            let destination = directory.appendingPathComponent(entry.path)
            try fm.createDirectory(at: destination.deletingLastPathComponent(),
                                   withIntermediateDirectories: true)
            if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
            _ = try archive.extract(entry, to: destination)
        }
        return manifest
    }

    private func addFile(_ url: URL, as path: String, to archive: Archive) throws {
        let data = try Data(contentsOf: url)
        try archive.addEntry(with: path,
                             type: .file,
                             uncompressedSize: Int64(data.count),
                             provider: { position, size in
            let start = Int(position)
            let end = min(start + size, data.count)
            guard start < end else { return Data() }
            return data.subdata(in: start..<end)
        })
    }
}

/// 恢复先落到暂存目录，下次启动再替换，避免数据库开着被覆盖
enum PendingRestore {
    static var stagingURL: URL {
        AppPaths.libraryRoot.deletingLastPathComponent()
            .appendingPathComponent("NovelManga-restore", isDirectory: true)
    }

    static func stage(archiveURL: URL) throws -> BackupManifest {
        let manifest = try BackupService.extract(archiveURL: archiveURL, to: stagingURL)
        return manifest
    }

    static func applyIfNeeded() throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: stagingURL.path) else { return }
        guard fm.fileExists(atPath: stagingURL.appendingPathComponent("library.sqlite").path) else { return }

        let root = AppPaths.libraryRoot
        if fm.fileExists(atPath: root.path) {
            try fm.removeItem(at: root)
        }
        try fm.createDirectory(at: root.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.moveItem(at: stagingURL, to: root)
    }
}
