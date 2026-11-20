import SwiftUI

/// 在线书详情页：抓详情 + 目录，可收藏、可直接读
struct OnlineBookDetailView: View {
    @EnvironmentObject private var env: AppEnvironment

    let onlineBook: OnlineBook
    let rule: SourceRule

    @State private var detail: OnlineDetail?
    @State private var chapters: [OnlineChapter] = []
    @State private var book: Book?
    @State private var units: [Unit] = []
    @State private var loading = true
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                if loading {
                    ProgressView("正在读取详情…")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else if let errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(Theme.Palette.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else {
                    header
                    if let book {
                        NavigationLink {
                            reader(for: book, unitIdx: startUnitIdx)
                        } label: {
                            Label(startTitle, systemImage: "book")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Theme.Spacing.m)
                                .background(Theme.Palette.accent.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
                        }
                    }
                    chapterList
                }
            }
            .padding(Theme.Spacing.l)
        }
        .navigationTitle(detail?.name ?? onlineBook.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let book {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if book.inShelf {
                            env.removeFromShelf(bookID: book.id)
                        } else {
                            env.addToShelf(bookID: book.id)
                        }
                        self.book = env.recentBooks.first { $0.id == book.id }
                    } label: {
                        Image(systemName: book.inShelf ? "heart.fill" : "heart")
                    }
                    .accessibilityLabel(book.inShelf ? "移出书架" : "加入书架")
                }
            }
        }
        .task { await load() }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.l) {
            coverView
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text(detail?.name ?? onlineBook.title).font(.title3).bold()
                if let author = detail?.author ?? onlineBook.author, !author.isEmpty {
                    Text(author).font(.subheadline).foregroundStyle(Theme.Palette.secondaryText)
                }
                HStack(spacing: Theme.Spacing.s) {
                    Text(rule.name).font(.caption)
                    if let category = detail?.category {
                        Text(category).font(.caption)
                    }
                    if let raw = detail?.serialStatus {
                        Text(raw == .ongoing ? "连载中" : "已完结").font(.caption)
                    }
                }
                .foregroundStyle(Theme.Palette.secondaryText)
                if let intro = detail?.intro, !intro.isEmpty {
                    Text(intro).font(.footnote).lineLimit(5)
                }
            }
        }
    }

    @ViewBuilder
    private var coverView: some View {
        if let urlString = detail?.coverURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    Color.clear
                }
            }
            .frame(width: 96, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.cover))
        } else {
            RoundedRectangle(cornerRadius: Theme.Radius.cover)
                .fill(Theme.Palette.separator.opacity(0.15))
                .frame(width: 96, height: 96)
                .overlay(Image(systemName: "book.closed").foregroundStyle(Theme.Palette.secondaryText))
        }
    }

    private var chapterList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(rule.isComic ? "分话" : "目录")
                .font(.headline)
                .padding(.bottom, Theme.Spacing.s)
            ForEach(units) { unit in
                if let book {
                    NavigationLink {
                        reader(for: book, unitIdx: unit.idx)
                    } label: {
                        HStack {
                            Text(unit.title ?? "第 \(unit.idx + 1) 章").lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, Theme.Spacing.m)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
        }
    }

    private var startTitle: String {
        env.progress(bookID: book?.id ?? "") == nil ? "开始阅读" : "继续阅读"
    }

    private var startUnitIdx: Int {
        guard let book, let progress = env.progress(bookID: book.id),
              progress.unitIdx >= 0, progress.unitIdx < units.count else { return 0 }
        return progress.unitIdx
    }

    private func load() async {
        loading = true
        errorText = nil
        do {
            let (fetchedDetail, fetchedChapters) = try await env.sourceClient
                .detailAndChapters(for: onlineBook, rule: rule)
            detail = fetchedDetail
            chapters = fetchedChapters

            let target: Book
            if let existing = env.recentBooks.first(where: {
                $0.sourceID == rule.id && $0.remoteKey == onlineBook.detailPath
            }) {
                target = existing
            } else {
                let fallback = OnlineDetail(name: onlineBook.title,
                                            author: onlineBook.author,
                                            intro: fetchedDetail?.intro,
                                            coverURL: fetchedDetail?.coverURL ?? onlineBook.coverURL,
                                            category: fetchedDetail?.category,
                                            serialStatus: fetchedDetail?.serialStatus)
                target = try env.addOnlineBook(detail: fetchedDetail ?? fallback,
                                               rule: rule,
                                               detailPath: onlineBook.detailPath,
                                               chapters: fetchedChapters,
                                               toShelf: false)
            }
            book = target
            units = env.units(bookID: target.id)
        } catch {
            errorText = error.localizedDescription
        }
        loading = false
    }

    @ViewBuilder
    private func reader(for book: Book, unitIdx: Int) -> some View {
        if rule.isComic {
            OnlineComicReaderView(book: book,
                                  units: units,
                                  startUnitIdx: unitIdx,
                                  startPageIdx: 0,
                                  client: env.sourceClient,
                                  rule: rule)
        } else {
            NovelReaderView(book: book,
                            units: units,
                            startUnitIdx: unitIdx,
                            startCharOffset: startOffset(for: book, unitIdx: unitIdx),
                            provider: OnlineChapterProvider(client: env.sourceClient, rule: rule))
        }
    }

    private func startOffset(for book: Book, unitIdx: Int) -> Int {
        guard let progress = env.progress(bookID: book.id), progress.unitIdx == unitIdx else { return 0 }
        return progress.charOffset
    }
}
