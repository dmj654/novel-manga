import SwiftUI
import UniformTypeIdentifiers

/// 主页：可自定义卡片流（D1、AC-03 ~ AC-04）
struct HomeView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var showImporter = false
    @State private var showCardEditor = false

    var body: some View {
        Group {
            if env.recentBooks.isEmpty {
                EmptyStateView(
                    symbol: "house",
                    title: "还没有书",
                    message: "导入本地 TXT / EPUB / 漫画包，或者在「发现」里加个书源。",
                    primaryTitle: "导入本地文件",
                    primaryAction: { showImporter = true },
                    secondaryTitle: "编辑卡片流",
                    secondaryAction: { showCardEditor = true }
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                        ForEach(env.homeCards) { card in
                            cardSection(card)
                        }
                    }
                    .padding(Theme.Spacing.l)
                }
            }
        }
        .navigationTitle("主页")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: Theme.Spacing.l) {
                    Button { showImporter = true } label: {
                        Image(systemName: "tray.and.arrow.down")
                    }
                    .accessibilityLabel("导入本地文件")
                    Button { showCardEditor = true } label: {
                        Image(systemName: "rectangle.3.group")
                    }
                    .accessibilityLabel("编辑卡片流")
                }
            }
        }
        .sheet(isPresented: $showCardEditor) {
            CardEditorView()
                .environmentObject(env)
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
        .onAppear { env.reload() }
    }

    @ViewBuilder
    private func cardSection(_ card: HomeCard) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(card.cardType.title).font(.headline)

            switch card.cardType {
            case .continueReading:
                if env.continueBooks.isEmpty {
                    placeholder("还没有阅读记录，随便挑一本开始吧。")
                } else {
                    horizontalBooks(env.continueBooks)
                }
            case .newBooks:
                if env.recentBooks.isEmpty {
                    placeholder("还没有书，先导入一本。")
                } else {
                    VStack(spacing: 0) {
                        ForEach(env.recentBooks.prefix(5)) { book in
                            NavigationLink { BookDetailView(book: book) } label: {
                                BookRow(book: book)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .background(Theme.Palette.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
                }
            case .recommend:
                if env.unstartedBooks.isEmpty {
                    placeholder("书架里的书都读过了，去「发现」找新书。")
                } else {
                    VStack(spacing: 0) {
                        ForEach(env.unstartedBooks.prefix(5)) { book in
                            NavigationLink { BookDetailView(book: book) } label: {
                                BookRow(book: book)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .background(Theme.Palette.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
                }
            case .rank, .category:
                placeholder("在「发现」页选书源后，这里会显示\(card.cardType.title)。")
            }
        }
    }

    private func horizontalBooks(_ books: [Book]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.m) {
                ForEach(books) { book in
                    NavigationLink { BookDetailView(book: book) } label: {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            BookCoverView(book: book, size: 84)
                            Text(book.title)
                                .font(.caption)
                                .lineLimit(1)
                                .frame(width: 84, alignment: .leading)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Theme.Palette.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.m)
            .background(Theme.Palette.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
    }
}

/// 卡片流编辑：开关 + 拖动排序（D1）
struct CardEditorView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var cards: [HomeCard] = []

    var body: some View {
        NavigationStack {
            List {
                Section("显示顺序") {
                    ForEach(cards) { card in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(card.cardType.title)
                                Text(card.cardType.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(Theme.Palette.secondaryText)
                            }
                            Spacer()
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(Theme.Palette.secondaryText)
                        }
                    }
                    .onMove { from, to in
                        cards.move(fromOffsets: from, toOffset: to)
                    }
                    .onDelete { indexSet in
                        cards.remove(atOffsets: indexSet)
                    }
                }

                if !availableToAdd.isEmpty {
                    Section("可添加") {
                        ForEach(availableToAdd) { type in
                            Button {
                                cards.append(HomeCard(type: type, sort: cards.count))
                            } label: {
                                Label(type.title, systemImage: "plus.circle")
                            }
                        }
                    }
                }

                Section {
                    Button("恢复默认") {
                        cards = LibraryStore.defaultCardTypes.enumerated()
                            .map { HomeCard(type: $0.element, sort: $0.offset) }
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("编辑卡片流")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        env.saveCards(cards)
                        dismiss()
                    }
                    .bold()
                }
            }
            .onAppear {
                cards = env.homeCards.isEmpty
                    ? LibraryStore.defaultCardTypes.enumerated().map { HomeCard(type: $0.element, sort: $0.offset) }
                    : env.homeCards
            }
        }
    }

    private var availableToAdd: [HomeCardType] {
        let existing = Set(cards.map { $0.cardType })
        return HomeCardType.allCases.filter { !existing.contains($0) }
    }
}

#if DEBUG
#Preview {
    NavigationStack { HomeView() }
        .environmentObject(AppEnvironment.shared)
}
#endif
