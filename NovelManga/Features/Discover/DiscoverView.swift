import SwiftUI

/// 发现文件夹骨架。M4 接书源后才有分类/榜单（PRD §2.5）。
struct DiscoverView: View {
    var body: some View {
        EmptyStateView(
            symbol: "safari",
            title: "还没添加书源",
            message: "发现页是按单个书源浏览分类和榜单的，先添加一个书源规则才能用。",
            primaryTitle: "去添加书源",
            primaryAction: {},
            secondaryTitle: nil,
            secondaryAction: nil
        )
        .navigationTitle("发现")
    }
}

#if DEBUG
#Preview {
    NavigationStack { DiscoverView() }
}
#endif
