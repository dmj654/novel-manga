import SwiftUI
import UniformTypeIdentifiers

/// 书架：M1 出可用的列表 + 移出/删除，M5 补分组/排序/多选（PRD §2.4）。
struct ShelfView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var showImporter = false
    @State private var pendingDelete: Book?

    var body: some View {
        Group {
            if env.shelfBooks.isEmpty {
                EmptyStateView(
                    symbol: "books.vertical",
                    title: "书架还是空的",
                    message: "支持 TXT、EPUB、ZIP/CBZ，可以一次选多个。导入后自动加入书架。",
                    primaryTitle: "导入本地文件",
                    primaryAction: { showImporter = true },
                    secondaryTitle: "去发现逛逛",
                    secondaryAction: {}
                )
            } else {
                List {
                    ForEach(env.shelfBooks) { book in
                        BookRow(book: book)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    pendingDelete = book
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                                Button {
                                    env.removeFromShelf(bookID: book.id)
                                } label: {
                                    Label("移出", systemImage: "heart.slash")
                                }
                                .tint(.orange)
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("书架")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showImporter = true } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("导入")
            }
        }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: ImportTypes.allowed,
                      allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { env.importFiles(at: urls) }
        }
        .alert("导入结果", isPresented: Binding(
            get: { env.importAlertMessage != nil },
            set: { if !$0 { env.importAlertMessage = nil } }
        )) {
            Button("好", role: .cancel) { env.importAlertMessage = nil }
        } message: {
            Text(env.importAlertMessage ?? "")
        }
        .alert("删除这本书？",
               isPresented: Binding(get: { pendingDelete != nil },
                                    set: { if !$0 { pendingDelete = nil } }),
               presenting: pendingDelete) { book in
            Button("删除", role: .destructive) {
                env.delete(bookID: book.id)
                pendingDelete = nil
            }
            Button("取消", role: .cancel) { pendingDelete = nil }
        } message: { book in
            Text("《\(book.title)》的正文文件和阅读进度会一起删掉。")
        }
        .onAppear { env.reload() }
    }
}

#if DEBUG
#Preview {
    NavigationStack { ShelfView() }
        .environmentObject(AppEnvironment.shared)
}
#endif
