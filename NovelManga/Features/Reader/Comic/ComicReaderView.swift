import SwiftUI
import UIKit

/// 漫画阅读器：上下连续滚动，页面进度自动保存（AC-11 ~ AC-13）
struct ComicReaderView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.scenePhase) private var scenePhase

    let book: Book
    let units: [Unit]

    @State private var unitIdx: Int
    @State private var pageIdx: Int
    @State private var pages: [ComicPage] = []
    @State private var topPage: Int = 0
    @State private var showTOC = false
    @State private var saveTask: Task<Void, Never>?

    init(book: Book, units: [Unit], startUnitIdx: Int, startPageIdx: Int) {
        self.book = book
        self.units = units
        let safeIndex = min(max(startUnitIdx, 0), max(units.count - 1, 0))
        _unitIdx = State(initialValue: safeIndex)
        _pageIdx = State(initialValue: max(startPageIdx, 0))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(pages.enumerated()), id: \.element.pageIdx) { index, page in
                        ComicPageImageView(page: page)
                            .id(index)
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(
                                        key: TopPageKey.self,
                                        value: [index: geo.frame(in: .named("comicScroll")).minY]
                                    )
                                }
                            )
                    }
                }
            }
            .coordinateSpace(name: "comicScroll")
            .onPreferenceChange(TopPageKey.self) { values in
                updateTopPage(values)
            }
            .onAppear {
                loadPages(at: unitIdx)
                let start = min(max(pageIdx, 0), max(pages.count - 1, 0))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    proxy.scrollTo(start, anchor: .top)
                }
            }
            .onChange(of: unitIdx) { _, newValue in
                loadPages(at: newValue)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    proxy.scrollTo(0, anchor: .top)
                }
            }
        }
        .navigationTitle(unitTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showTOC = true } label: {
                    Image(systemName: "list.bullet")
                }
                .accessibilityLabel("目录")
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .sheet(isPresented: $showTOC) {
            NavigationStack {
                List(units) { unit in
                    Button {
                        unitIdx = unit.idx
                        pageIdx = 0
                        showTOC = false
                    } label: {
                        HStack {
                            Text(unit.title ?? "第 \(unit.idx + 1) 话")
                            Spacer()
                            if unit.idx == unitIdx {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Theme.Palette.accent)
                            }
                        }
                    }
                }
                .navigationTitle("目录")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .onDisappear { saveNow() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { saveNow() }
        }
    }

    private var unitTitle: String {
        guard unitIdx >= 0, unitIdx < units.count else { return book.title }
        return units[unitIdx].title ?? book.title
    }

    private var bottomBar: some View {
        HStack {
            Button("上一页") { goPage(-1) }
                .disabled(unitIdx == 0 && pageIdx == 0)
            Spacer()
            Text("\(min(pageIdx + 1, max(pages.count, 1)))/\(max(pages.count, 1))")
                .font(.caption)
                .foregroundStyle(Theme.Palette.secondaryText)
            Spacer()
            Button("下一页") { goPage(1) }
                .disabled(pages.isEmpty)
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.s)
        .background(.ultraThinMaterial)
    }

    private func loadPages(at index: Int) {
        guard let unit = units[safe: index] else {
            pages = []
            return
        }
        pages = env.pages(bookID: book.id, unitIdx: unit.idx)
        topPage = 0
    }

    private func goPage(_ delta: Int) {
        let next = pageIdx + delta
        if next < 0 {
            if unitIdx > 0 {
                unitIdx -= 1
                pageIdx = 0
            }
            return
        }
        if next >= pages.count {
            if unitIdx < units.count - 1 {
                unitIdx += 1
                pageIdx = 0
            }
            return
        }
        pageIdx = next
        saveNow()
    }

    private func updateTopPage(_ values: [Int: CGFloat]) {
        guard !pages.isEmpty else { return }
        let visible = values.filter { $0.value <= 24 }
        let chosen = visible.max(by: { $0.value < $1.value })?.key
            ?? values.min(by: { abs($0.value) < abs($1.value) })?.key
        guard let chosen, chosen != topPage else { return }
        topPage = chosen
        pageIdx = chosen
        scheduleSave()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            saveNow()
        }
    }

    private func saveNow() {
        guard !units.isEmpty else { return }
        let clampedPage = min(max(pageIdx, 0), max(pages.count - 1, 0))
        let percent = ComicProgress.percent(unitIdx: unitIdx,
                                            pageIdx: clampedPage,
                                            pageCount: pages.count,
                                            totalUnits: units.count)
        env.saveProgress(ReadingProgress(bookID: book.id,
                                         unitIdx: unitIdx,
                                         charOffset: 0,
                                         pageIdx: clampedPage,
                                         percent: percent))
    }
}

private struct TopPageKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct ComicPageImageView: View {
    let page: ComicPage
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else if failed {
                VStack(spacing: Theme.Spacing.s) {
                    Image(systemName: "exclamationmark.triangle")
                    Text("这一页读不出来")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
                .foregroundStyle(Theme.Palette.secondaryText)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 200)
            }
        }
        .frame(maxWidth: .infinity)
        .task(id: page.localPath) {
            guard image == nil else { return }
            guard let path = page.localPath else {
                failed = true
                return
            }
            let url = AppPaths.absoluteURL(forRelativePath: path)
            if let loaded = UIImage(contentsOfFile: url.path) {
                image = loaded
            } else {
                failed = true
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
