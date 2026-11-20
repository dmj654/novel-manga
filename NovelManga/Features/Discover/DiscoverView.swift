import SwiftUI

/// 发现：书源 + 分类/榜单入口（AC-15 ~ AC-18）
struct DiscoverView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var showSourceManager = false
    @State private var showSettings = false

    var body: some View {
        Group {
            if env.sources(enabledOnly: false).isEmpty {
                EmptyStateView(
                    symbol: "safari",
                    title: "还没有书源",
                    message: "书源是一份 JSON 规则。添加后这里会列出分类和榜单，也能搜索在线书。",
                    primaryTitle: "添加书源",
                    primaryAction: { showSourceManager = true }
                )
            } else {
                List {
                    Section("书源") {
                        ForEach(env.sources(enabledOnly: false)) { source in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(source.name)
                                    Text(source.type == 1 ? "漫画源" : "小说源")
                                        .font(.caption)
                                        .foregroundStyle(Theme.Palette.secondaryText)
                                }
                                Spacer()
                                if !source.enabled {
                                    Text("已停用")
                                        .font(.caption)
                                        .foregroundStyle(Theme.Palette.secondaryText)
                                }
                            }
                        }
                        Button("管理书源") { showSourceManager = true }
                    }

                    ForEach(env.sources()) { source in
                        if let rule = try? source.decodedRule() {
                            if let categories = rule.categories, !categories.isEmpty {
                                Section("\(source.name) · 分类") {
                                    ForEach(categories, id: \.name) { category in
                                        NavigationLink {
                                            CategoryListView(title: category.name,
                                                             urlString: SourceEngine.expand(category.url, rule: rule),
                                                             rule: rule)
                                        } label: {
                                            Label(category.name, systemImage: "square.grid.2x2")
                                        }
                                    }
                                }
                            }
                            if let ranks = rule.ranks, !ranks.isEmpty {
                                Section("\(source.name) · 榜单") {
                                    ForEach(ranks, id: \.name) { rank in
                                        NavigationLink {
                                            CategoryListView(title: rank.name,
                                                             urlString: SourceEngine.expand(rank.url, rule: rule),
                                                             rule: rule)
                                        } label: {
                                            Label(rank.name, systemImage: "chart.bar")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("发现")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: Theme.Spacing.l) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("设置")
                    Button { showSourceManager = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("添加书源")
                }
            }
        }
        .sheet(isPresented: $showSourceManager) {
            NavigationStack {
                SourceManageView()
                    .environmentObject(env)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(env)
        }
        .onAppear { env.reload() }
    }
}

/// 分类 / 榜单列表页
struct CategoryListView: View {
    @EnvironmentObject private var env: AppEnvironment

    let title: String
    let urlString: String
    let rule: SourceRule

    @State private var books: [OnlineBook] = []
    @State private var loading = true
    @State private var errorText: String?

    var body: some View {
        Group {
            if loading {
                ProgressView("读取列表…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorText {
                EmptyStateView(symbol: "exclamationmark.triangle",
                               title: "列表读不到",
                               message: errorText)
            } else if books.isEmpty {
                EmptyStateView(symbol: "tray", title: "这里没有书", message: "换个书源或稍后再试。")
            } else {
                List(books) { book in
                    NavigationLink {
                        OnlineBookDetailView(onlineBook: book, rule: rule)
                    } label: {
                        OnlineBookRow(book: book)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do {
                books = try await env.sourceClient.listBooks(at: urlString, rule: rule)
            } catch {
                errorText = error.localizedDescription
            }
            loading = false
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack { DiscoverView() }
        .environmentObject(AppEnvironment.shared)
}
#endif
