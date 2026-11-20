import Foundation

/// 章节/页面的纯逻辑：段落切分、字符偏移换算、百分比计算。全部可单测。
enum NovelTextLayout {

    struct Paragraph: Identifiable, Hashable {
        let id: Int
        let text: String
        /// 该段第一个字符在整章中的偏移
        let charOffset: Int
    }

    /// 按空行/换行切段，记录每段起始字符偏移
    static func paragraphs(from text: String) -> [Paragraph] {
        var result: [Paragraph] = []
        var offset = 0
        var index = 0
        for rawLine in text.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            defer { offset += rawLine.count + 1 }
            guard !line.isEmpty else { continue }
            result.append(Paragraph(id: index, text: line, charOffset: offset))
            index += 1
        }
        return result
    }

    /// 找到覆盖该字符偏移的段落（用于恢复阅读位置）
    static func paragraphIndex(forCharOffset offset: Int, in paragraphs: [Paragraph]) -> Int {
        guard !paragraphs.isEmpty else { return 0 }
        var candidate = 0
        for paragraph in paragraphs where paragraph.charOffset <= offset {
            candidate = paragraph.id
        }
        return candidate
    }

    static func charOffset(forParagraph index: Int, in paragraphs: [Paragraph]) -> Int {
        guard index >= 0, index < paragraphs.count else { return 0 }
        return paragraphs[index].charOffset
    }
}

enum NovelProgress {
    /// 百分比 =（已完成章数 + 本章内偏移占比）/ 总章数，0...1
    static func percent(unitIdx: Int, charOffset: Int, currentCharCount: Int, totalUnits: Int) -> Double {
        guard totalUnits > 0 else { return 0 }
        let chapterFraction: Double
        if currentCharCount > 0 {
            chapterFraction = min(max(Double(charOffset) / Double(currentCharCount), 0), 1)
        } else {
            chapterFraction = 0
        }
        let completed = Double(max(0, min(unitIdx, totalUnits - 1)))
        return min(max((completed + chapterFraction) / Double(totalUnits), 0), 1)
    }

    static func clampOffset(_ offset: Int, charCount: Int) -> Int {
        min(max(offset, 0), max(charCount, 0))
    }
}

enum ComicProgress {
    /// 漫画按「已完成话 + 本话内页占比」折算
    static func percent(unitIdx: Int, pageIdx: Int, pageCount: Int, totalUnits: Int) -> Double {
        guard totalUnits > 0 else { return 0 }
        let pageFraction: Double
        if pageCount > 0 {
            pageFraction = min(max(Double(pageIdx) / Double(pageCount), 0), 1)
        } else {
            pageFraction = 0
        }
        let completed = Double(max(0, min(unitIdx, totalUnits - 1)))
        return min(max((completed + pageFraction) / Double(totalUnits), 0), 1)
    }
}

/// 进度写入节流：滚动停止 1.5s 才落库，避免每帧写
struct ProgressThrottle {
    let minimumInterval: TimeInterval
    private var lastSave: Date?

    init(minimumInterval: TimeInterval = 1.5) {
        self.minimumInterval = minimumInterval
    }

    mutating func shouldSave(at now: Date = Date()) -> Bool {
        if let lastSave, now.timeIntervalSince(lastSave) < minimumInterval { return false }
        lastSave = now
        return true
    }
}
