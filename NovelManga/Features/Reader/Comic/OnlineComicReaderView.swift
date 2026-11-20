import SwiftUI

/// 在线漫画阅读器：按章节抓图片地址，逐张加载（AC-13 的在线分支）
struct OnlineComicReaderView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.scenePhase) private var scenePhase

    let book: Book
    let units: [Unit]
    let client: SourceClient
    let rule: SourceRule

    @State private var unitIdx: Int
    @State private var pageIdx: Int
    @State private var imageURLs: [String] = []
    @State private var topPage = 0
    @State private var loadError: String?
    @State private var isLoading = false
    @State private var showTOC = false

    init(book: Book, units: [Unit], startUnitIdx: Int, startPageIdx: Int,
         client: SourceClient, rule: SourceRule) {
        self.book = book
        self.units = units
        self.client = client
        self.rule = rule
        let safeIndex = min(max(startUnitIdx, 0), max(units.count - 1, 0))
        _unitIdx = State(initialValue: safeIndex)
        _pageIdx = State(initialValue: max(startPageIdx, 0))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if isLoading {
                    ProgressView("正在取图…").padding(.top, 80)
                } else if let loadError {
                    Text(loadError)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 80)
                        .frame(maxWidth: .infinity)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, urlString in
                            RemoteImageView(urlString: urlString)
                                .id(index)
                                .background(
                                    GeometryReader { geo in
                                        Color.clear.preference(
                                            key: OnlinePageKey.self,
                                            value: [index: geo.frame(in: .named("onlineComic")).minY]
                                        )
                                    }
                                )
                        }
                    }
                }
            }
            .coordinateSpace(name: "onlineComic")
            .onPreferenceChange(OnlinePageKey.self) { values in
                updateTopPage(values)
            }
            .onAppear {
                load()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    proxy.scrollTo(pageIdx, anchor: .top)
                }
            }
            .onChange(of: unitIdx) { _, _ in
                load()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    proxy.scrollTo(0, anchor: .top)
                }
            }
        }
        .navigationTitle(units[safe: unitIdx]?.title ?? book.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showTOC = true } label: { Image(systemName: "list.bullet") }
                    .accessibilityLabel("目录")
            }
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
                                Image(systemName: "checkmark").foregroundStyle(Theme.Palette.accent)
                            }
                        }
                    }
                }
                .navigationTitle("目录")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button("上一话") { switchUnit(-1) }.disabled(unitIdx <= 0)
                Spacer()
                Text("\(min(pageIdx + 1, max(imageURLs.count, 1)))/\(max(imageURLs.count, 1))")
                    .font(.caption)
                    .foregroundStyle(Theme.Palette.secondaryText)
                Spacer()
                Button("下一话") { switchUnit(1) }.disabled(unitIdx >= units.count - 1)
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.s)
            .background(.ultraThinMaterial)
        }
        .onDisappear { saveNow() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { saveNow() }
        }
    }

    private func switchUnit(_ delta: Int) {
        let next = unitIdx + delta
        guard next >= 0, next < units.count else { return }
        unitIdx = next
        pageIdx = 0
        saveNow()
    }

    private func load() {
        guard let unit = units[safe: unitIdx] else { return }
        isLoading = true
        loadError = nil
        Task {
            do {
                let urls = try await client.imageURLs(for: OnlineChapter(title: unit.title ?? "", path: unit.url ?? ""),
                                                      rule: rule)
                imageURLs = urls
                isLoading = false
            } catch {
                imageURLs = []
                isLoading = false
                loadError = "取图失败：\(error.localizedDescription)"
            }
        }
    }

    private func updateTopPage(_ values: [Int: CGFloat]) {
        guard !imageURLs.isEmpty else { return }
        let visible = values.filter { $0.value <= 24 }
        let chosen = visible.max(by: { $0.value < $1.value })?.key
            ?? values.min(by: { abs($0.value) < abs($1.value) })?.key
        guard let chosen, chosen != topPage else { return }
        topPage = chosen
        pageIdx = chosen
        saveNow()
    }

    private func saveNow() {
        guard !units.isEmpty else { return }
        let percent = ComicProgress.percent(unitIdx: unitIdx,
                                            pageIdx: pageIdx,
                                            pageCount: imageURLs.count,
                                            totalUnits: units.count)
        env.saveProgress(ReadingProgress(bookID: book.id,
                                         unitIdx: unitIdx,
                                         charOffset: 0,
                                         pageIdx: pageIdx,
                                         percent: percent))
    }
}

private struct OnlinePageKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct RemoteImageView: View {
    let urlString: String

    var body: some View {
        AsyncImage(url: URL(string: urlString)) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFit()
            case .failure:
                VStack(spacing: Theme.Spacing.s) {
                    Image(systemName: "exclamationmark.triangle")
                    Text("图片加载失败").font(.caption)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
                .foregroundStyle(Theme.Palette.secondaryText)
            default:
                ProgressView().frame(maxWidth: .infinity, minHeight: 200)
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
