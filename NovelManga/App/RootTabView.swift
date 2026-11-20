import SwiftUI

/// 四个底层 Tab，每个 Tab 持有自己的 NavigationStack（PRD §2.1：切 Tab 不重置位置）。
struct RootTabView: View {
    enum Tab: Hashable, CaseIterable {
        case home, shelf, discover, search

        var title: String {
            switch self {
            case .home: return "主页"
            case .shelf: return "书架"
            case .discover: return "发现"
            case .search: return "搜索"
            }
        }

        var symbol: String {
            switch self {
            case .home: return "house"
            case .shelf: return "books.vertical"
            case .discover: return "safari"
            case .search: return "magnifyingglass"
            }
        }
    }

    @State private var selection: Tab = .home

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                HomeView()
            }
            .tabItem { Label(Tab.home.title, systemImage: Tab.home.symbol) }
            .tag(Tab.home)

            NavigationStack {
                ShelfView()
            }
            .tabItem { Label(Tab.shelf.title, systemImage: Tab.shelf.symbol) }
            .tag(Tab.shelf)

            NavigationStack {
                DiscoverView()
            }
            .tabItem { Label(Tab.discover.title, systemImage: Tab.discover.symbol) }
            .tag(Tab.discover)

            NavigationStack {
                SearchView()
            }
            .tabItem { Label(Tab.search.title, systemImage: Tab.search.symbol) }
            .tag(Tab.search)
        }
    }
}

#if DEBUG
#Preview {
    RootTabView()
}
#endif
