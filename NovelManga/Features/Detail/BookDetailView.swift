import SwiftUI

/// 详情页：继续阅读 + 目录。M4 补换源，M5 补分组/简介折叠。
struct BookDetailView: View {
    @EnvironmentObject private var env: AppEnvironment
    let book: Book

    @State private var units: [Unit] = []
    @State private var progress: ReadingProgress?
    @State private var loaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                header

                if let progress {
                    Text(progressText(progress))
                        .font(.footnote)
                        .foregroundStyle(Theme.Palette.secondaryText)
                }

                NavigationLink(value: ReaderRoute(bookID: book.id, unitIdx: startUnitIdx)) {
                    Label(startButtonTitle, systemImage: "book")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.m)
                        .background(Theme.Palette.accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
                }

                Text(book.kind == .novel ? "目录" : "分话")
                    .font(.headline)

                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(units) { unit in
                        NavigationLink(value: ReaderRoute(bookID: book.id, unitIdx: unit.idx)) {
                            HStack {
                                Text(unit.title ?? "第 \(unit.idx + 1) \(book.kind == .novel ? "章" : "话")")
                                    .lineLimit(1)
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
            .padding(Theme.Spacing.l)
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: ReaderRoute.self) { route in
            reader(for: route)
        }
        .onAppear(perform: load)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.l) {
            BookCoverView(book: book, size: 96)
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text(book.title).font(.title3).bold()
                if let author = book.author, !author.isEmpty {
                    Text(author).font(.subheadline).foregroundStyle(Theme.Palette.secondaryText)
                }
                Text("\(book.kind.displayName) · \(units.count) \(book.kind == .novel ? "章" : "话")")
                    .font(.caption)
                    .foregroundStyle(Theme.Palette.secondaryText)
                if let intro = book.intro, !intro.isEmpty {
                    Text(intro)
                        .font(.footnote)
                        .lineLimit(4)
                        .foregroundStyle(Theme.Palette.secondaryText)
                }
            }
        }
    }

    private var startUnitIdx: Int {
        guard let progress, progress.unitIdx >= 0, progress.unitIdx < units.count else { return 0 }
        return progress.unitIdx
    }

    private var startButtonTitle: String {
        progress == nil ? "开始阅读" : "继续阅读"
    }

    private func progressText(_ progress: ReadingProgress) -> String {
        let percent = Int(progress.percent * 100)
        if book.kind == .novel {
            return "上次读到第 \(progress.unitIdx + 1) 章 · \(percent)%"
        }
        return "上次读到第 \(progress.unitIdx + 1) 话 第 \(progress.pageIdx + 1) 页 · \(percent)%"
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        units = env.units(bookID: book.id)
        progress = env.progress(bookID: book.id)
        env.touchOpened(bookID: book.id)
    }

    @ViewBuilder
    private func reader(for route: ReaderRoute) -> some View {
        if book.kind == .novel {
            NovelReaderView(book: book,
                            units: units,
                            startUnitIdx: route.unitIdx,
                            startCharOffset: startOffset(for: route.unitIdx),
                            provider: textProvider())
        } else if book.bookOrigin == .online, let rule = onlineRule() {
            OnlineComicReaderView(book: book,
                                  units: units,
                                  startUnitIdx: route.unitIdx,
                                  startPageIdx: startPage(for: route.unitIdx),
                                  client: env.sourceClient,
                                  rule: rule)
        } else {
            ComicReaderView(book: book,
                            units: units,
                            startUnitIdx: route.unitIdx,
                            startPageIdx: startPage(for: route.unitIdx))
        }
    }

    private func onlineRule() -> SourceRule? {
        guard let sourceID = book.sourceID,
              let source = env.sources(enabledOnly: false).first(where: { $0.id == sourceID }) else {
            return nil
        }
        return try? source.decodedRule()
    }

    private func textProvider() -> any ChapterProviding {
        if let rule = onlineRule() {
            return OnlineChapterProvider(client: env.sourceClient, rule: rule)
        }
        return LocalChapterProvider()
    }

    private func startOffset(for unitIdx: Int) -> Int {
        guard let progress, progress.unitIdx == unitIdx else { return 0 }
        return progress.charOffset
    }

    private func startPage(for unitIdx: Int) -> Int {
        guard let progress, progress.unitIdx == unitIdx else { return 0 }
        return progress.pageIdx
    }
}

struct ReaderRoute: Hashable {
    let bookID: String
    let unitIdx: Int
}
