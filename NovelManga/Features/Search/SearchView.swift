import SwiftUI

enum SearchTab: String, CaseIterable, Identifiable {
    case local = "本地"
    case online = "在线"

    var id: String { rawValue }
}

struct OnlineSearchGroup: Identifiable {
    var id: String { source.id }
    let source: Source
    let books: [OnlineBook]
    let error: String?
}

/// 搜索：本地 / 在线双 Tab 共用输入框（D2、AC-19 ~ AC-21）
struct SearchView: View {
    @EnvironmentObject private var env: AppEnvironment

    @State private var tab: SearchTab = .local
    @State private var keyword = ""
    @State private var localResults: [Book] = []
    @State private var onlineGroups: [OnlineSearchGroup] = []
    @State private var searching = false
    @State private var hint: String?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Picker("搜索范围", selection: $tab) {
                ForEach(SearchTab.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.s)
            .onChange(of: tab) { _, _ in
                if !keyword.isEmpty { runSearch() }
            }

            content
        }
        .navigationTitle("搜索")
        .onAppear { localResults = env.localSearch(keyword) }
    }

    private var searchBar: some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.Palette.secondaryText)
            TextField(tab == .local ? "搜书名或作者" : "搜在线书名", text: $keyword)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit(runSearch)
            if !keyword.isEmpty {
                Button {
                    keyword = ""
                    localResults = []
                    onlineGroups = []
                    hint = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.Palette.secondaryText)
                }
            }
        }
        .padding(Theme.Spacing.m)
        .background(Theme.Palette.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        .padding(Theme.Spacing.l)
    }

    @ViewBuilder
    private var content: some View {
        if searching {
            ProgressView("正在搜索…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let hint {
            EmptyStateView(symbol: "magnifyingglass", title: "换个词试试", message: hint)
        } else if tab == .local {
            localList
        } else {
            onlineList
        }
    }

    @ViewBuilder
    private var localList: some View {
        if keyword.isEmpty {
            EmptyStateView(symbol: "magnifyingglass", title: "搜本地书库",
                            message: "输入书名或作者，回车开始搜索。")
        } else if localResults.isEmpty {
            EmptyStateView(symbol: "tray", title: "本地没有匹配",
                            message: "换个关键词，或者切到「在线」搜书源。")
        } else {
            List(localResults) { book in
                NavigationLink {
                    BookDetailView(book: book)
                } label: {
                    BookRow(book: book)
                }
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private var onlineList: some View {
        if keyword.isEmpty {
            EmptyStateView(symbol: "antenna.radiowaves.left.and.right", title: "搜在线书源",
                            message: "先在设置里添加书源，再回来搜索。")
        } else if onlineGroups.isEmpty {
            EmptyStateView(symbol: "tray", title: "在线没有结果",
                            message: "换个关键词，或者检查书源是否可用。")
        } else {
            List {
                ForEach(onlineGroups) { group in
                    Section {
                        if let error = group.error {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(Theme.Palette.secondaryText)
                        } else {
                            ForEach(group.books) { book in
                                if let rule = try? group.source.decodedRule() {
                                    NavigationLink {
                                        OnlineBookDetailView(onlineBook: book, rule: rule)
                                    } label: {
                                        OnlineBookRow(book: book)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text(group.source.name)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private func runSearch() {
        let key = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        if tab == .local {
            localResults = env.localSearch(key)
            hint = localResults.isEmpty ? "本地书库里没有匹配的书。" : nil
            return
        }

        let sources = env.sources()
        guard !sources.isEmpty else {
            hint = "还没有启用的书源，先去「设置 → 书源」添加。"
            return
        }

        searchTask?.cancel()
        searching = true
        hint = nil
        onlineGroups = []
        searchTask = Task { @MainActor in
            var groups: [OnlineSearchGroup] = []
            let batches = stride(from: 0, to: sources.count, by: 3).map {
                Array(sources[$0..<min($0 + 3, sources.count)])
            }
            for batch in batches {
                guard !Task.isCancelled else { break }
                var batchResults: [OnlineSearchGroup] = []
                await withTaskGroup(of: OnlineSearchGroup.self) { group in
                    for source in batch {
                        group.addTask { @MainActor in
                            do {
                                let rule = try source.decodedRule()
                                let books = try await env.sourceClient.search(keyword: key, rule: rule)
                                return OnlineSearchGroup(source: source, books: books, error: nil)
                            } catch {
                                return OnlineSearchGroup(source: source, books: [],
                                                         error: error.localizedDescription)
                            }
                        }
                    }
                    for await result in group { batchResults.append(result) }
                }
                groups.append(contentsOf: batchResults)
            }
            guard !Task.isCancelled else { return }
            onlineGroups = groups
            searching = false
            if groups.allSatisfy({ $0.books.isEmpty }) {
                hint = "各书源都没有结果：\(groups.compactMap { $0.error }.first ?? "换个关键词试试")"
            }
        }
    }
}

struct OnlineBookRow: View {
    let book: OnlineBook

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            if let cover = book.coverURL, let url = URL(string: cover) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        Color.clear
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.cover))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(book.title).lineLimit(1)
                Text(book.author ?? "未知作者")
                    .font(.caption)
                    .foregroundStyle(Theme.Palette.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }
}
