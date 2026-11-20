import SwiftUI

/// 搜索页骨架。M5 拆成本地 / 在线两个 Tab（PRD §2.6、决策 D2）。
struct SearchView: View {
    @State private var keyword: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.Palette.secondaryText)
                TextField("搜索书名、作者", text: $keyword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(Theme.Spacing.m)
            .background(Theme.Palette.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            .padding(Theme.Spacing.l)

            EmptyStateView(
                symbol: "magnifyingglass",
                title: "搜点什么",
                message: "M5 之后这里会分「本地」和「在线」两个 Tab。"
            )
        }
        .background(Theme.Palette.screenBackground)
        .navigationTitle("搜索")
    }
}

#if DEBUG
#Preview {
    NavigationStack { SearchView() }
}
#endif
