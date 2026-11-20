import SwiftUI

/// 空态组件：文案统一"发生了什么 + 你能做什么"两段式（PRD §2.4）。
struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var primaryTitle: String? = nil
    var primaryAction: (() -> Void)? = nil
    var secondaryTitle: String? = nil
    var secondaryAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            Image(systemName: symbol)
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(Theme.Palette.secondaryText)

            VStack(spacing: Theme.Spacing.s) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.Palette.primaryText)

                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Palette.secondaryText)
                    .padding(.horizontal, Theme.Spacing.xl)
            }

            VStack(spacing: Theme.Spacing.s) {
                if let primaryTitle, let primaryAction {
                    Button(primaryTitle, action: primaryAction)
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.Palette.accent)
                }
                if let secondaryTitle, let secondaryAction {
                    Button(secondaryTitle, action: secondaryAction)
                        .buttonStyle(.borderless)
                        .foregroundStyle(Theme.Palette.secondaryText)
                }
            }
            .padding(.top, Theme.Spacing.s)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.Spacing.xl)
        .background(Theme.Palette.screenBackground)
    }
}

#if DEBUG
#Preview {
    EmptyStateView(
        symbol: "books.vertical",
        title: "书架还是空的",
        message: "导入本地文件，或者先去发现里加一个书源。",
        primaryTitle: "导入本地文件",
        primaryAction: {},
        secondaryTitle: "去发现逛逛",
        secondaryAction: {}
    )
}
#endif
