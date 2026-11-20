# NovelManga · 自用 iOS 小说 / 漫画阅读器

本地优先的阅读器：导入 TXT / EPUB / CBK 漫画包就能读，也可以接 `JSON 书源` 搜在线书。
数据全部存在 App 自己的 `Application Support/NovelManga` 里，可整包导出 `.nmbak` 备份。

## 现在能做什么

| 模块 | 状态 |
|---|---|
| 四个 Tab（主页 / 书架 / 发现 / 搜索），各自独立导航栈 | ✅ |
| 本地导入：TXT、EPUB、ZIP/CBZ 漫画包；多选导入 + 成功失败汇总 | ✅ |
| 书架：列表、移出书架、删除（连同正文与进度） | ✅ |
| 详情页：封面 / 作者 / 简介 / 目录 / 继续阅读入口 | ✅ |
| 小说阅读器：连续滚动、目录、字号行距、段落级进度保存 | ✅ |
| 漫画阅读器：上下连续滚动、页码、页面级进度保存 | ✅ |
| 主页卡片流：继续阅读 / 最近入库 / 推荐 / 榜单 / 分类，可增删拖动排序并持久化 | ✅ |
| 搜索：本地 / 在线双 Tab，共用关键词，在线按源分组（同源串行、全局并发 3） | ✅ |
| 书源：JSON 规则导入、启用停用、删除；搜索 / 详情 / 目录 / 正文 / 图片 / 分类 / 榜单 | ✅ |
| 设置：导出 `.nmbak`、从备份恢复（下次启动生效） | ✅ |
| 自动化测试：42 条 XCTest，覆盖解析、规则、进度、卡片、备份 | ✅ |

## 明确还没做（下一步）

- 详情页「换源」（D5 已定方案，UI 未接）
- 书源「测试」按钮（可用性 + 耗时）
- 书架长按多选删除
- 备份的「合并」模式、恢复前自动备份、清理缓存
- 导入进度条（目前是导入完成才汇总）
- 直接导入图片文件夹（目前只认 ZIP/CBZ）

## 目录结构

```
NovelManga/
├── App/
│   ├── NovelMangaApp.swift       @main，注入 AppEnvironment
│   ├── RootTabView.swift         四 Tab + 各自 NavigationStack
│   └── AppEnvironment.swift      依赖容器（DB / 导入 / 书源 / 备份）
├── Core/
│   ├── Models/                   Book / Unit / ComicPage / ReadingProgress / Source / HomeCard
│   ├── Storage/                  AppDatabase(DDL v1) / LibraryStore / AppPaths
│   ├── Import/                   TXT / EPUB / 漫画解析 + ImportService
│   ├── Reader/                   章节读取、段落偏移、进度百分比、节流
│   ├── Source/                   规则模型、正则抽取、规则引擎、网络客户端
│   ├── Backup/                   .nmbak 导出 / 校验 / 暂存恢复
│   ├── DesignSystem/             Theme / EmptyStateView / BookCoverView
│   └── Extensions/               NaturalSort
├── Features/
│   ├── Home/ Shelf/ Discover/ Search/
│   ├── Detail/                   本地详情 + 在线详情
│   ├── Reader/Novel|Comic/       本地与在线阅读器
│   └── Settings/                 书源管理 / 备份
└── NovelMangaTests/              42 条单测
```

## 构建（本机 Windows，用 GitHub Actions 出包）

```bash
# 在 CI 里做的事，本地 macOS 等价手动步骤
brew install xcodegen
cd NovelManga && xcodegen generate
xcodebuild test -project NovelManga.xcodeproj -scheme NovelManga \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
```

CI（`.github/workflows/ios.yml`，`runs-on: macos-15`）跑完会产出两个工件：
- `test-log`：单元测试日志
- `NovelManga-unsigned-ipa`：未签名 ipa，用 Sideloadly / AltStore 自签安装（免费 Apple ID 7 天一签）

## 书源规则

格式见 `开发计划.md` §6。最小示例已内置在「设置 → 书源管理 → 添加书源」的编辑框里。
要点：`{{base}} {{key}} {{page}} {{detail}} {{chapterUrl}}` 五种模板变量；`list` 是切块标记；其余字段是取第 1 个捕获组的正则。

## 数据与备份

- 主库：`library.sqlite`（GRDB，WAL）
- 正文 / 页面：`Books/<bookID>/`，封面 `Covers/`
- 备份：`.nmbak` = `library.sqlite` + `manifest.json` + `Books/` + `Covers/`

## 进度保存策略

滚动停止 1.5s 后落库；进入后台 / 退出阅读器立即落库；小说存「段落字符偏移」，漫画存「页序号」，改字号不丢位置。
