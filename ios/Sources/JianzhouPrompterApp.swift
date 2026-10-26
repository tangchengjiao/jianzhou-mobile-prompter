import SwiftUI
import UniformTypeIdentifiers

@main
struct JianzhouPrompterApp: App {
    @StateObject private var model = PrompterModel()
    @StateObject private var pip = PiPController()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            PromptHome().environmentObject(model).environmentObject(pip)
                .tint(Brand.purple)
                .onAppear { pip.configure(model) }
                .onChange(of: phase) { _, value in
                    if value == .background && model.voiceMode {
                        model.pause(); model.message = "已离开全屏语音练习，麦克风已释放。"
                    } else if value == .background && !pip.isActive && !pip.pending { model.pause() }
                }
                .alert("见舟提词", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
                    Button("知道了", role: .cancel) { model.message = nil }
                } message: { Text(model.message ?? "") }
        }
    }
}

enum Brand {
    static let purple = Color(red: 0.376, green: 0.329, blue: 0.808)
    static let pale = Color(red: 0.91, green: 0.89, blue: 1)
    static let background = Color(red: 0.98, green: 0.98, blue: 0.995)
    static let ink = Color(red: 0.13, green: 0.12, blue: 0.18)
}

struct PromptHome: View {
    @EnvironmentObject private var model: PrompterModel
    @EnvironmentObject private var pip: PiPController
    @State private var library = false
    @State private var settings = false
    @State private var importing = false
    @State private var exporting = false
    @State private var exportAfterSettings = false
    @State private var exportDocument = PromptTextFile(text: "")
    @State private var exportFilename = "口播稿.txt"
    @State private var practice = false
    @State private var route: Route?
    @FocusState private var field: Field?
    enum Field: Hashable { case title, body }
    enum Route: Hashable { case prepare, read }

    private func beginExport() {
        field = nil
        model.pause()
        let snapshot = PromptExport(script: model.selected)
        exportDocument = PromptTextFile(text: snapshot.text)
        exportFilename = snapshot.filename
        exporting = true
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("这次，想讲什么？").font(.system(size: 29, weight: .bold))
                        Text("稿子放这里，拍摄还用你熟悉的 App").font(.subheadline).foregroundStyle(.secondary)
                    }
                    VStack(spacing: 10) {
                        TextField("稿件标题", text: Binding(get: { model.selected.title }, set: { model.update(title: $0) }))
                            .font(.headline).accessibilityLabel("稿件标题")
                            .focused($field, equals: .title)
                        TextEditor(text: Binding(get: { model.selected.text }, set: { model.update(text: $0) }))
                            .font(.system(size: 16)).lineSpacing(7).scrollContentBackground(.hidden)
                            .frame(height: 215).accessibilityLabel("稿件正文")
                            .focused($field, equals: .body)
                        Divider()
                        HStack {
                            Text("\(model.selected.text.filter { !$0.isWhitespace }.count) 字 · 约 \(Int(ceil(Double(model.units.characters.count) / model.speed * 60))) 秒")
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button { model.pause(); route = .read } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                                .accessibilityLabel("全屏查看稿件").disabled(!model.hasText)
                        }
                        HStack {
                            Label("已保存到本机", systemImage: "checkmark.circle").font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            Button("保存副本") { field = nil; model.saveCopy() }
                            Button("导出 TXT") { beginExport() }.disabled(model.selected.text.isEmpty)
                        }.font(.caption)
                    }
                    .padding(20).background(.white, in: RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.gray.opacity(0.14)))
                    Picker("提词模式", selection: $practice) {
                        Label("悬浮提词", systemImage: "text.bubble").tag(false)
                        Label("全屏练习", systemImage: "rectangle.inset.filled").tag(true)
                    }.pickerStyle(.segmented)
                    Button {
                        field = nil; model.pause(); route = practice ? .read : .prepare
                    } label: { HStack { Spacer(); Text(practice ? "开始全屏练习" : "准备悬浮提词"); Spacer(); Image(systemName: "arrow.right") } }
                        .buttonStyle(MainButton()).disabled(!model.hasText).accessibilityIdentifier("prepare-prompt")
                    Button("从文件导入") { model.pause(); importing = true }.frame(maxWidth: .infinity)
                    Divider()
                    HStack { Text("最近使用").foregroundStyle(.secondary); Spacer(); Button("全部稿件") { model.pause(); library = true } }.font(.subheadline)
                    ForEach(model.scripts.filter { $0.id != model.selectedID }.prefix(3)) { script in
                        Button { model.select(script) } label: { HStack { Text(script.title); Spacer(); Image(systemName: "chevron.right") } }.foregroundStyle(Brand.ink)
                    }
                    Button { model.create() } label: { Label("新建一份稿子", systemImage: "plus") }
                    Text("原生实验版 · 跨 App 录像兼容性尚待真机验证").font(.caption2).foregroundStyle(.secondary)
                }.padding(22)
            }
            .background(Brand.background).foregroundStyle(Brand.ink)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("见舟提词").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button { field = nil; model.pause(); settings = true } label: { Image(systemName: "gearshape") }.accessibilityLabel("设置") }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("完成输入") { field = nil } }
            }
            .navigationDestination(item: $route) { target in
                switch target { case .prepare: PromptPreparation(); case .read: PromptReader() }
            }
            .sheet(isPresented: $library) {
                NavigationStack { List {
                    Button { model.create(); library = false } label: { Label("新建稿件", systemImage: "plus") }
                    ForEach(model.scripts) { script in Button { model.select(script); library = false } label: { Text(script.title) } }
                }.navigationTitle("我的稿件").toolbar { Button("完成") { library = false } } }
            }
            .sheet(isPresented: $settings, onDismiss: {
                if exportAfterSettings { exportAfterSettings = false; beginExport() }
            }) { PromptSettings(export: { exportAfterSettings = true; settings = false }) }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.plainText, UTType(filenameExtension: "md") ?? .plainText]) { result in
                do {
                    let url = try result.get(); let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let text = try String(contentsOf: url, encoding: .utf8)
                    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { model.message = "这份稿件是空的。"; return }
                    model.create(title: url.deletingPathExtension().lastPathComponent, text: text)
                } catch { model.message = "无法读取这份稿件，请用 UTF-8 TXT 或直接粘贴文字。" }
            }
            .fileExporter(isPresented: $exporting, document: exportDocument, contentType: .plainText, defaultFilename: exportFilename) { result in
                if case .failure(let error) = result { model.message = error.localizedDescription }
            }
        }
    }
}

struct PromptPreparation: View {
    @EnvironmentObject private var model: PrompterModel
    @EnvironmentObject private var pip: PiPController
    @State private var reading = false
    @State private var logs = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("iPhone · 画中画提词").font(.caption).foregroundStyle(Brand.purple)
                Text("调到舒服，再开拍。").font(.system(size: 25, weight: .bold))
                PiPPreview(controller: pip).frame(height: 230).clipShape(RoundedRectangle(cornerRadius: 18))
                PromptAdjustments()
                Label("匀速悬浮 · 不使用麦克风", systemImage: "mic.slash").font(.caption).foregroundStyle(.secondary)
                Button { pip.isActive ? pip.stop() : pip.start() } label: { Text(pip.isActive ? "停止悬浮提词" : "启动系统画中画").frame(maxWidth: .infinity) }
                    .buttonStyle(MainButton()).disabled(!pip.supported || !model.hasText)
                if pip.pending { Button("取消等待") { pip.stop() }.frame(maxWidth: .infinity) }
                Text(pip.status).font(.footnote).foregroundStyle(.secondary)
                Button("先全屏练一遍") { pip.stop(); reading = true }.frame(maxWidth: .infinity)
                Text("请分别测试开拍、剪映和系统相机的实际录像。画中画能启动，不代表录像时一定持续显示；跨 App 语音跟随尚未验证。").font(.caption).foregroundStyle(.secondary)
                Button("查看本次画中画记录") { logs = true }.font(.caption)
            }.padding(22)
        }.background(Brand.background).navigationTitle("提词准备").navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $reading) { PromptReader() }
            .sheet(isPresented: $logs) {
                NavigationStack { ScrollView { Text(pip.events.joined(separator: "\n\n")).frame(maxWidth: .infinity, alignment: .leading).padding().textSelection(.enabled) }
                    .navigationTitle("画中画实验记录").toolbar { Button("完成") { logs = false } } }
            }
    }
}

struct PromptReader: View {
    @EnvironmentObject private var model: PrompterModel
    @State private var settings = false
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(model.counting.map { "\($0) 秒后开始" } ?? (model.playing ? (model.voiceMode ? "语音跟读中" : "匀速提词中") : "已暂停 · 点句子定位"))
                Spacer(); Text("\(Int(model.progress * 100))%")
            }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 22).padding(.vertical, 10)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 30) {
                        ForEach(Array(model.sentences.enumerated()), id: \.offset) { index, sentence in
                            Button { model.seek(sourceOffset: sentence.range.location) } label: {
                                Text(sentence.text).font(.system(size: model.fontSize, weight: .semibold)).lineSpacing(9)
                                    .foregroundStyle(index == model.sentenceIndex ? Color.white : Color.white.opacity(index < model.sentenceIndex ? 0.32 : 0.58))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }.id(index).buttonStyle(.plain)
                        }
                    }.padding(.horizontal, 25).padding(.top, 35).padding(.bottom, 160).scaleEffect(x: model.mirror ? -1 : 1, y: 1)
                }.background(Color(red: 0.10, green: 0.09, blue: 0.13))
                    .onChange(of: model.sentenceIndex) { _, index in withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(index, anchor: .top) } }
            }
            VStack(spacing: 16) {
                Toggle("语音跟读（本机练习）", isOn: $model.voiceMode).font(.subheadline).onChange(of: model.voiceMode) { _, _ in model.pause() }
                HStack(spacing: 45) {
                    Button { model.skip(-1) } label: { Image(systemName: "backward.end.fill") }.accessibilityLabel("上一句")
                    Button { model.toggle() } label: {
                        Group { if let counting = model.counting { Text("\(counting)") } else { Image(systemName: model.playing ? "pause.fill" : "play.fill") } }.font(.title2).frame(width: 60, height: 60).background(Brand.purple, in: Circle())
                    }.accessibilityLabel(model.counting != nil ? "取消倒计时" : model.playing ? "暂停提词" : "播放提词")
                    Button { model.skip(1) } label: { Image(systemName: "forward.end.fill") }.accessibilityLabel("下一句")
                }.foregroundStyle(.white)
                HStack { Button("从头再来") { model.seek(sourceOffset: 0) }; Spacer(); Button("字号与语速") { model.pause(); settings = true } }.font(.caption)
            }.padding(22).background(Color(red: 0.14, green: 0.13, blue: 0.18)).foregroundStyle(.white)
        }
        .navigationTitle(model.selected.title).navigationBarTitleDisplayMode(.inline)
        .onDisappear { model.pause() }.sheet(isPresented: $settings) { PromptSettings() }
    }
}

struct PromptAdjustments: View {
    @EnvironmentObject private var model: PrompterModel
    var body: some View {
        VStack(spacing: 20) {
            VStack { HStack { Text("字号"); Text("\(Int(model.fontSize))").foregroundStyle(Brand.purple); Spacer() }; Slider(value: $model.fontSize, in: 24...48, step: 1).accessibilityLabel("字号") }
            VStack { HStack { Text("语速"); Text("\(Int(model.speed)) 字/分").foregroundStyle(Brand.purple); Spacer() }; Slider(value: $model.speed, in: 60...300, step: 10).accessibilityLabel("语速") }
        }
    }
}

struct PromptSettings: View {
    @EnvironmentObject private var model: PrompterModel
    @Environment(\.dismiss) private var dismiss
    var export: (() -> Void)?
    var body: some View {
        NavigationStack {
            Form {
                Section { PromptAdjustments() }
                Section { Toggle("镜像文字", isOn: $model.mirror)
                    Picker("开始倒计时", selection: $model.countdown) { Text("关").tag(0); Text("3 秒").tag(3); Text("5 秒").tag(5) }
                }
                if let export { Section { Button("导出当前稿件", action: export) } }
                Section { Text("语音跟读用于全屏练习；悬浮到其他拍摄 App 时使用匀速模式。真实兼容性请以本机录像测试为准。").font(.footnote) }
            }.navigationTitle("按你的习惯来").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("完成") { dismiss() } }
        }.tint(Brand.purple)
    }
}

struct MainButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
            .padding(17).background(Brand.purple.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct PromptTextFile: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws { text = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? "" }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: Data(text.utf8)) }
}
