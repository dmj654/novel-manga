import SwiftUI
import UniformTypeIdentifiers

/// 主页：M1 先给出「最近导入 + 导入入口」的可用版本，M5 换成可自定义卡片流（PRD §2.3）。
struct HomeView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var showImporter = false

    var body: some View {
        Group {
            if env.recentBooks.isEmpty {
                EmptyStateView(
                    symbol: "house",
                    title: "还没有阅读记录",
                    message: "导入一本本地书，或者先加一个书源，之后这里会出现「继续阅读」。",
                    primaryTitle: "导入本地文件",
                    primaryAction: { showImporter = true },
                    secondaryTitle: "去添加书源",
                    secondaryAction: {}
                )
            } else {
                List {
                    Section("最近导入") {
                        ForEach(env.recentBooks.prefix(6)) { book in
                            NavigationLink {
                                BookDetailView(book: book)
                            } label: {
                                BookRow(book: book)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("主页")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showImporter = true } label: {
                    Image(systemName: "tray.and.arrow.down")
                }
                .accessibilityLabel("导入本地文件")
            }
        }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: ImportTypes.allowed,
                      allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                env.importFiles(at: urls)
            case .failure:
                break
            }
        }
        .alert("导入结果", isPresented: Binding(
            get: { env.importAlertMessage != nil },
            set: { if !$0 { env.importAlertMessage = nil } }
        )) {
            Button("好", role: .cancel) { env.importAlertMessage = nil }
        } message: {
            Text(env.importAlertMessage ?? "")
        }
        .onAppear { env.reload() }
    }
}

#if DEBUG
#Preview {
    NavigationStack { HomeView() }
        .environmentObject(AppEnvironment.shared)
}
#endif
