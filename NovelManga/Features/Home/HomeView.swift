import SwiftUI

/// 主页骨架。M0 只有空态；M5 换成可自定义卡片流（PRD §2.3）。
struct HomeView: View {
    var body: some View {
        EmptyStateView(
            symbol: "house",
            title: "还没有阅读记录",
            message: "导入一本本地书，或者先加一个书源，之后这里会出现「继续阅读」。",
            primaryTitle: "导入本地文件",
            primaryAction: {},
            secondaryTitle: "去添加书源",
            secondaryAction: {}
        )
        .navigationTitle("主页")
    }
}

#if DEBUG
#Preview {
    NavigationStack { HomeView() }
}
#endif
