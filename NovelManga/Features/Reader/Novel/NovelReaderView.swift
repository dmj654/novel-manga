import SwiftUI

/// 小说阅读器：连续滚动 + 目录 + 字号 + 进度自动保存（AC-05 ~ AC-10）
struct NovelReaderView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.scenePhase) private var scenePhase

    let book: Book
    let units: [Unit]

    @State private var unitIdx: Int
    @State private var charOffset: Int
    @State private var paragraphs: [NovelTextLayout.Paragraph] = []
    @State private var topIndex: Int = 0
    @State private var textCount: Int = 0
    @State private var loadError: String?
    @State private var showTOC = false
    @State private var showSettings = false
    @State private var saveTask: Task<Void, Never>?

    @AppStorage("novel.fontSize") private var fontSize: Double = 18
    @AppStorage("novel.lineSpacing") private var lineSpacing: Double = 8

    init(book: Book, units: [Unit], startUnitIdx: Int, startCharOffset: Int) {
        self.book = book
        self.units = units
        let safeIndex = min(max(startUnitIdx, 0), max(units.count - 1, 0))
        _unitIdx = State(initialValue: safeIndex)
        _charOffset = State(initialValue: startCharOffset)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: lineSpacing + 8) {
                    if let loadError {
                        Text(loadError)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(paragraphs) { paragraph in
                        Text(paragraph.text)
                            .font(.system(size: fontSize))
                            .lineSpacing(lineSpacing)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(paragraph.id)
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(
                                        key: TopVisibleKey.self,
                                        value: [paragraph.id: geo.frame(in: .named("novelScroll")).minY]
                                    )
                                }
                            )
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.vertical, Theme.Spacing.xl)
            }
            .coordinateSpace(name: "novelScroll")
            .onPreferenceChange(TopVisibleKey.self) { values in
                updateTopParagraph(values)
            }
            .onAppear {
                loadChapter(at: unitIdx, restoreOffset: charOffset)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    proxy.scrollTo(initialParagraphIndex, anchor: .top)
                }
            }
            .onChange(of: unitIdx) { _, newValue in
                loadChapter(at: newValue, restoreOffset: 0)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    proxy.scrollTo(0, anchor: .top)
                }
            }
        }
        .navigationTitle(units[safe: unitIdx]?.title ?? book.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: Theme.Spacing.l) {
                    Button { showTOC = true } label: {
                        Image(systemName: "list.bullet")
                    }
                    .accessibilityLabel("目录")
                    Button { showSettings = true } label: {
                        Image(systemName: "textformat.size")
                    }
                    .accessibilityLabel("阅读设置")
                }
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
                        showTOC = false
                    } label: {
                        HStack {
                            Text(unit.title ?? "第 \(unit.idx + 1) 章")
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
        .sheet(isPresented: $showSettings) {
            settingsSheet
                .presentationDetents([.height(240)])
        }
        .onDisappear { saveNow() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { saveNow() }
        }
    }

    private var initialParagraphIndex: Int {
        NovelTextLayout.paragraphIndex(forCharOffset: charOffset, in: paragraphs)
    }

    private var bottomBar: some View {
        HStack {
            Button("上一章") { go(-1) }
                .disabled(unitIdx <= 0)
            Spacer()
            Text("\(unitIdx + 1)/\(max(units.count, 1))")
                .font(.caption)
                .foregroundStyle(Theme.Palette.secondaryText)
            Spacer()
            Button("下一章") { go(1) }
                .disabled(unitIdx >= units.count - 1)
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.s)
        .background(.ultraThinMaterial)
    }

    private var settingsSheet: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            Text("正文字号 \(Int(fontSize))")
                .font(.subheadline)
            Slider(value: $fontSize, in: 14...28, step: 1)

            Text("行距 \(Int(lineSpacing))")
                .font(.subheadline)
            Slider(value: $lineSpacing, in: 4...16, step: 1)

            Button("恢复默认") {
                fontSize = 18
                lineSpacing = 8
            }
            .font(.footnote)

            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.l)
    }

    private func go(_ delta: Int) {
        let next = unitIdx + delta
        guard next >= 0, next < units.count else { return }
        unitIdx = next
    }

    private func loadChapter(at index: Int, restoreOffset: Int) {
        guard let unit = units[safe: index] else {
            paragraphs = []
            loadError = "找不到这一章"
            return
        }
        do {
            let text = try ChapterTextStore().text(for: unit)
            let parsed = NovelTextLayout.paragraphs(from: text)
            paragraphs = parsed
            textCount = text.count
            let target = NovelTextLayout.paragraphIndex(forCharOffset: restoreOffset, in: parsed)
            topIndex = target
            charOffset = restoreOffset
            loadError = parsed.isEmpty ? "这一章没有正文" : nil
        } catch {
            paragraphs = []
            textCount = 0
            loadError = "读取失败：\(error.localizedDescription)"
        }
    }

    private func updateTopParagraph(_ values: [Int: CGFloat]) {
        guard !paragraphs.isEmpty else { return }
        let visible = values.filter { $0.value <= 24 }
        let chosen: Int?
        if let lastAbove = visible.max(by: { $0.value < $1.value }) {
            chosen = lastAbove.key
        } else {
            chosen = values.min(by: { abs($0.value) < abs($1.value) })?.key
        }
        guard let chosen, chosen != topIndex else { return }
        topIndex = chosen
        charOffset = NovelTextLayout.charOffset(forParagraph: chosen, in: paragraphs)
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
        let safeOffset = NovelProgress.clampOffset(charOffset, charCount: textCount)
        let percent = NovelProgress.percent(unitIdx: unitIdx,
                                            charOffset: safeOffset,
                                            currentCharCount: textCount,
                                            totalUnits: units.count)
        env.saveProgress(ReadingProgress(bookID: book.id,
                                         unitIdx: unitIdx,
                                         charOffset: safeOffset,
                                         pageIdx: 0,
                                         percent: percent))
    }
}

private struct TopVisibleKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
