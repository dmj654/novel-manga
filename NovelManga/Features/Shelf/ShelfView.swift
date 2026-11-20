import SwiftUI

/// 书架骨架。M1 出最简网格，M5 补分组/排序/多选（PRD §2.4）。
struct ShelfView: View {
    var body: some View {
        EmptyStateView(
            symbol: "books.vertical",
            title: "书架还是空的",
            message: "支持 TXT、EPUB、图片文件夹、ZIP/CBZ 和 PDF，可以一次选多个。",
            primaryTitle: "导入本地文件",
            primaryAction: {},
            secondaryTitle: "去发现逛逛",
            secondaryAction: {}
        )
        .navigationTitle("书架")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("导入")
            }
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack { ShelfView() }
}
#endif
