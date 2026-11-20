# NovelManga（小说漫画）

自用的 iOS 小说 + 漫画阅读器。产品定义见 `../PRD.md`，页面细节见 `../页面结构与交互设计.md`，排期见 `../开发计划.md`。

## 当前进度

- **M0 骨架**：四 Tab（主页 / 书架 / 发现 / 搜索），每个 Tab 独立 `NavigationStack`；设计系统与空态组件；`NaturalSort`（漫画页序、章节排序用）。
- 单测：`NaturalSortTests`（7 条）。
- CI：`.github/workflows/ios.yml`，在 macOS runner 上 `xcodegen generate` → `xcodebuild test` → 出未签名 IPA。

## 工程说明

- 项目文件由 **XcodeGen** 从 `project.yml` 生成，`NovelManga.xcodeproj` 不入库。
- 依赖（后续里程碑）：GRDB（SQLite）、ZIPFoundation、SwiftSoup、Kingfisher；M0 阶段为零依赖，先验证流水线。

## 本地构建（需要 macOS + Xcode 15+）

```bash
brew install xcodegen
xcodegen generate
open NovelManga.xcodeproj      # 或用下面的命令行
```

跑测试：

```bash
SIM=$(xcrun simctl list devices available | grep -m1 -o 'iPhone [0-9A-Za-z ]*' | head -1 | tr -d ' ')
xcodebuild test -project NovelManga.xcodeproj -scheme NovelManga \
  -destination "platform=iOS Simulator,name=$SIM" CODE_SIGNING_ALLOWED=NO
```

## 在 Windows 上工作

本机没有 Swift/Xcode，**无法本地编译**。流程是：改代码 → 推 GitHub → Actions 跑测试 → 看日志修。CI 失败会在 `test.log` 工件里保留完整 `xcodebuild` 输出。

## 目录

```
App/            入口与根 Tab
Features/       各页面（Home / Shelf / Discover / Search / Detail / Reader / Import / Settings）
Core/           设计系统、纯逻辑扩展
NovelMangaTests/ 单测
```
