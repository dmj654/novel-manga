import SwiftUI
import UniformTypeIdentifiers

/// 支持导入的文件类型
enum ImportTypes {
    static var allowed: [UTType] {
        var types: [UTType] = [.plainText, .zip, .folder]
        for ext in ["epub", "cbz"] {
            if let type = UTType(filenameExtension: ext) { types.append(type) }
        }
        return types
    }
}
