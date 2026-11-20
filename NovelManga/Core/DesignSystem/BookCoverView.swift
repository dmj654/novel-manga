import SwiftUI
import UIKit

/// 书封面：优先读本地封面文件，没有则用类型图标占位
struct BookCoverView: View {
    let book: Book
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let image = loadImage() {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Rectangle().fill(Palette.separator.opacity(0.15))
                    Image(systemName: book.kind == .comic ? "photo.on.rectangle" : "book.closed")
                        .foregroundStyle(Palette.secondaryText)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: Radius.cover6))
        .accessibilityHidden(true)
    }

    private func loadImage() -> UIImage? {
        guard let path = book.coverPath else { return nil }
        let url = AppPaths.absoluteURL(forRelativePath: path)
        return UIImage(contentsOfFile: url.path)
    }
}

struct BookRow: View {
    let book: Book

    var body: some View {
        HStack(spacing: Spacing.m12) {
            BookCoverView(book: book)
            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.body)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Palette.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Spacing.xs4)
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        var parts: [String] = []
        if let author = book.author, !author.isEmpty { parts.append(author) }
        parts.append(book.kind.displayName)
        if book.unitCount > 0 {
            parts.append(book.kind == .novel ? "\(book.unitCount) 章" : "\(book.unitCount) 话")
        }
        return parts.joined(separator: " · ")
    }
}
