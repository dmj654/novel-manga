import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    @State private var exportedURL: URL?
    @State private var backupMessage: String?
    @State private var showRestorePicker = false

    var body: some View {
        NavigationStack {
            List {
                Section("书源") {
                    NavigationLink {
                        SourceManageView()
                    } label: {
                        Label("书源管理（\(env.sources(enabledOnly: false).count)）", systemImage: "antenna.radiowaves.left.and.right")
                    }
                }

                Section("数据") {
                    Button {
                        do {
                            exportedURL = try env.exportBackup()
                            backupMessage = "备份已生成"
                        } catch {
                            backupMessage = "导出失败：\(error.localizedDescription)"
                        }
                    } label: {
                        Label("导出备份（.nmbak）", systemImage: "square.and.arrow.up")
                    }

                    if let exportedURL {
                        ShareLink(item: exportedURL) {
                            Label("分享备份文件", systemImage: "doc.badge.arrow.up")
                        }
                    }

                    Button {
                        showRestorePicker = true
                    } label: {
                        Label("从备份恢复", systemImage: "arrow.down.doc")
                    }
                }

                Section("说明") {
                    Text("恢复备份会覆盖当前书库，并在下次启动 App 时生效。")
                        .font(.footnote)
                        .foregroundStyle(Theme.Palette.secondaryText)
                    Text("版本 1.0（本地闭环 + 书源搜索）")
                        .font(.footnote)
                        .foregroundStyle(Theme.Palette.secondaryText)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .fileImporter(isPresented: $showRestorePicker,
                      allowedContentTypes: [UTType(filenameExtension: "nmbak") ?? .data],
                      allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                do {
                    let manifest = try env.stageRestore(from: url)
                    backupMessage = "已暂存 \(manifest.bookCount) 本书的备份，下次启动生效。"
                } catch {
                    backupMessage = "恢复失败：\(error.localizedDescription)"
                }
            }
        }
        .alert("备份", isPresented: Binding(
            get: { backupMessage != nil },
            set: { if !$0 { backupMessage = nil } }
        )) {
            Button("好", role: .cancel) { backupMessage = nil }
        } message: {
            Text(backupMessage ?? "")
        }
    }
}

struct SourceManageView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    @State private var sources: [Source] = []
    @State private var showAdd = false
    @State private var pendingDelete: Source?

    var body: some View {
        List {
            if sources.isEmpty {
                Text("还没有书源。点下面的「添加书源」粘贴一份 JSON 规则。")
                    .font(.footnote)
                    .foregroundStyle(Theme.Palette.secondaryText)
            }
            ForEach(sources) { source in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(source.name)
                        Text(source.type == 1 ? "漫画源" : "小说源")
                            .font(.caption)
                            .foregroundStyle(Theme.Palette.secondaryText)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { source.enabled },
                        set: { value in
                            env.setSourceEnabled(id: source.id, enabled: value)
                            refresh()
                        }
                    ))
                    .labelsHidden()
                }
                .swipeActions {
                    Button(role: .destructive) {
                        pendingDelete = source
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
            }

            Section {
                Button {
                    showAdd = true
                } label: {
                    Label("添加书源", systemImage: "plus")
                }
            }
        }
        .navigationTitle("书源管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("完成") { dismiss() }
            }
        }
        .sheet(isPresented: $showAdd) {
            SourceAddView { refresh() }
                .environmentObject(env)
        }
        .alert("删除书源？",
               isPresented: Binding(get: { pendingDelete != nil },
                                    set: { if !$0 { pendingDelete = nil } }),
               presenting: pendingDelete) { source in
            Button("删除", role: .destructive) {
                env.deleteSource(id: source.id)
                pendingDelete = nil
                refresh()
            }
            Button("取消", role: .cancel) { pendingDelete = nil }
        } message: { source in
            Text("《\(source.name)》删除后，已收藏的书还在，但需要换源才能继续更新。")
        }
        .onAppear(perform: refresh)
    }

    private func refresh() {
        sources = env.sources(enabledOnly: false)
    }
}

struct SourceAddView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    let onSaved: () -> Void

    @State private var json = SourceAddView.sampleJSON
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("粘贴书源规则 JSON")
                    .font(.footnote)
                    .foregroundStyle(Theme.Palette.secondaryText)
                TextEditor(text: $json)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxHeight: .infinity)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.card)
                            .stroke(Theme.Palette.separator)
                    )
                if let errorText {
                    Text(errorText)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(Theme.Spacing.l)
            .navigationTitle("添加书源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        do {
                            try env.addSource(json: json)
                            onSaved()
                            dismiss()
                        } catch {
                            errorText = error.localizedDescription
                        }
                    }
                    .bold()
                }
            }
        }
    }

    static let sampleJSON = """
    {
      "id": "src-demo",
      "name": "示例小说源",
      "type": "novel",
      "baseUrl": "https://example.com",
      "headers": { "User-Agent": "Mozilla/5.0" },
      "search": {
        "url": "{{base}}/search?q={{key}}&page={{page}}",
        "list": "<div class=\\"book-item\\">",
        "name": "<h3>(.*?)</h3>",
        "author": "作者：(.*?)<",
        "cover": "src=\\"(.*?)\\"",
        "detail": "href=\\"(.*?)\\""
      },
      "detail": {
        "url": "{{base}}{{detail}}",
        "name": "<h1>(.*?)</h1>",
        "author": "作者：(.*?)<",
        "intro": "<div id=\\"intro\\">(.*?)</div>"
      },
      "toc": {
        "url": "{{base}}{{detail}}",
        "list": "<dd>",
        "title": "<a[^>]*>(.*?)</a>",
        "href": "href=\\"(.*?)\\""
      },
      "content": {
        "url": "{{base}}{{chapterUrl}}",
        "text": "<div id=\\"content\\">(.*?)</div>"
      }
    }
    """
}
