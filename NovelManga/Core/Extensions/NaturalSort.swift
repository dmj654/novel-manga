import Foundation

/// 自然排序：让 "第2章" 排在 "第10章" 前面，让漫画页 "1.jpg, 2.jpg, 10.jpg" 按真实数字排。
/// 导入解析（T1-5 漫画页序）和目录排序都用它，所以单独抽成纯逻辑，便于单测。
enum NaturalSort {

    static func isOrderedBefore(_ lhs: String, _ rhs: String) -> Bool {
        let left = tokenize(lhs)
        let right = tokenize(rhs)

        var i = 0
        while i < left.count && i < right.count {
            let l = left[i]
            let r = right[i]

            if l.isNumber && r.isNumber {
                let ln = l.number ?? 0
                let rn = r.number ?? 0
                if ln != rn { return ln < rn }
                // 数字相同（如 "01" 与 "1"），继续比较后面
            } else if !l.isNumber && !r.isNumber {
                let order = l.text.compare(r.text, options: [.caseInsensitive, .literal])
                if order == .orderedAscending { return true }
                if order == .orderedDescending { return false }
            } else {
                // 数字块优先于文本块，保证 "2" 排在 "a" 前，行为稳定可预期
                return l.isNumber
            }
            i += 1
        }

        if left.count != right.count { return left.count < right.count }
        // 完全等价时用原串做最终裁决，保证排序稳定且不丢元素
        return lhs.compare(rhs, options: [.caseInsensitive, .literal]) == .orderedAscending
    }

    static func sorted(_ values: [String]) -> [String] {
        values.sorted(by: isOrderedBefore)
    }

    // MARK: - Tokenizing

    private struct Token {
        let text: String
        let isNumber: Bool
        let number: UInt64?
    }

    private static func tokenize(_ input: String) -> [Token] {
        var tokens: [Token] = []
        var buffer = String()
        var bufferIsNumber = false

        func flush() {
            guard !buffer.isEmpty else { return }
            tokens.append(Token(text: buffer,
                                isNumber: bufferIsNumber,
                                number: bufferIsNumber ? UInt64(buffer) : nil))
            buffer = ""
        }

        for scalar in input.unicodeScalars {
            let isDigit = CharacterSet.decimalDigits.contains(scalar)
            if buffer.isEmpty {
                bufferIsNumber = isDigit
                buffer.append(Character(scalar))
            } else if isDigit == bufferIsNumber {
                buffer.append(Character(scalar))
            } else {
                flush()
                bufferIsNumber = isDigit
                buffer.append(Character(scalar))
            }
        }
        flush()
        return tokens
    }
}
