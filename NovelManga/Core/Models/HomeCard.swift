import Foundation
import GRDB

enum HomeCardType: Int, CaseIterable, Identifiable {
    case continueReading = 0
    case newBooks = 1
    case recommend = 2
    case rank = 3
    case category = 4

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .continueReading: return "继续阅读"
        case .newBooks: return "最近入库"
        case .recommend: return "推荐"
        case .rank: return "榜单"
        case .category: return "分类"
        }
    }

    var subtitle: String {
        switch self {
        case .continueReading: return "最近打开过的书，接着上次的位置"
        case .newBooks: return "最新导入或收藏的书"
        case .recommend: return "书架里还没开始读的收藏"
        case .rank: return "来自书源的榜单"
        case .category: return "来自书源的分类入口"
        }
    }
}

struct HomeCard: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable {
    static let databaseTableName = "cards"

    var id: String
    var type: Int
    var params: String?
    var sort: Int

    var cardType: HomeCardType { HomeCardType(rawValue: type) ?? .continueReading }

    init(type: HomeCardType, sort: Int) {
        self.id = "card-\(type.rawValue)"
        self.type = type.rawValue
        self.params = nil
        self.sort = sort
    }
}
