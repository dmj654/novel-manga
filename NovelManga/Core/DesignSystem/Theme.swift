import SwiftUI
import UIKit

/// 全站视觉基线（PRD §2.4 全局交互约定：统一颜色、间距、字号）。
enum Theme {
    enum Palette {
        static let accent = Color(red: 0.20, green: 0.42, blue: 0.86)
        static let screenBackground = Color(.systemGroupedBackground)
        static let cardBackground = Color(.secondarySystemGroupedBackground)
        static let primaryText = Color(.label)
        static let secondaryText = Color(.secondaryLabel)
        static let separator = Color(.separator)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
    }

    enum Radius {
        static let card: CGFloat = 12
        static let cover: CGFloat = 6
    }
}
