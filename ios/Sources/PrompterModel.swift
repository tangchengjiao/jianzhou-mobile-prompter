import Foundation
import Combine
import NaturalLanguage

struct PromptScript: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var text: String
}

/** A fixed copy of the wording at the moment the user taps Export. */
struct PromptExport {
    let filename: String
    let text: String

    init(script: PromptScript, date: Date = Date()) {
        let title = script.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let visibleTitle = title.isEmpty ? "未命名口播" : title
        let safeTitle = visibleTitle.replacingOccurrences(of: "[\\\\/:*?\"<>|\\r\\n]", with: " ", options: .regularExpression)
        let time = DateFormatter()
        time.dateFormat = "yyyyMMdd-HHmmss"
        filename = "\(safeTitle)-\(time.string(from: date)).txt"
        text = visibleTitle + "\n\n" + script.text
    }
}

enum PromptFileStore {
    static func write(_ snapshot: PromptExport, in documentsDirectory: URL? = nil) throws -> URL {
        let documents = documentsDirectory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = documents.appendingPathComponent("导出稿件", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let stem = (snapshot.filename as NSString).deletingPathExtension
        var destination = folder.appendingPathComponent(snapshot.filename)
        var copy = 2
        while FileManager.default.fileExists(atPath: destination.path) {
            destination = folder.appendingPathComponent("\(stem)-\(copy).txt")
            copy += 1
        }
        try snapshot.text.write(to: destination, atomically: true, encoding: .utf8)
        return destination
    }
}

@MainActor
final class PrompterModel: ObservableObject {
    @Published var scripts: [PromptScript] { didSet { save() } }
    @Published var selectedID: UUID { didSet { defaults.set(selectedID.uuidString, forKey: selectedKey) } }
    @Published var fontSize: Double = 32 { didSet { saveSettings() } }
    @Published var speed: Double = 180 { didSet { saveSettings() } }
    @Published var mirror = false { didSet { saveSettings() } }
    @Published var countdown = 3 { didSet { saveSettings() } }
    @Published private(set) var cursor: Double = 0
    @Published private(set) var playing = false
    @Published private(set) var counting: Int?
    @Published var message: String?
    @Published var voiceMode = false
    @Published var cameraOpacity: Double = 0.6 { didSet { saveSettings() } }
    @Published var cameraPreviewMirror = true { didSet { saveSettings() } }
    @Published var cameraVideoMirror = false { didSet { saveSettings() } }
    @Published private(set) var heardText = ""
    @Published private(set) var voiceStatus = "等待开始"
    var useCapturedAudio = false
    private var ticker: AnyCancellable?
    private var countdownTask: Task<Void, Never>?
    private var playGeneration = 0
    private var cachedText: String?
    private var cachedUnits = ScriptUnits("")
    private var cachedSentences: [(range: NSRange, text: String)] = []
    private var recognitionHints: [String] = []
    private var lastTime: TimeInterval = 0
    let speech = SpeechFollower()
    private let defaults: UserDefaults
    private let storeKey = "jianzhou.prompter.scripts.v1"
    private let selectedKey = "jianzhou.prompter.selected-script.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let restored = defaults.data(forKey: "jianzhou.prompter.scripts.v1").flatMap { try? JSONDecoder().decode([PromptScript].self, from: $0) }
        let initial = restored?.isEmpty == false ? restored! : [PromptScript(title: "为什么我要自己做提词器", text: "我拍视频的时候，最怕的不是忘词。\n\n而是刚找到状态，提词却没跟上。\n\n所以这一次，我想做一个真正顺手的工具。")]
        let previousID = defaults.string(forKey: "jianzhou.prompter.selected-script.v1").flatMap(UUID.init(uuidString:))
        scripts = initial; selectedID = initial.first(where: { $0.id == previousID })?.id ?? initial[0].id
        if let saved = defaults.dictionary(forKey: "jianzhou.prompter.settings.v1") {
            fontSize = saved["font"] as? Double ?? 32; speed = saved["speed"] as? Double ?? 180
            mirror = saved["mirror"] as? Bool ?? false; countdown = saved["countdown"] as? Int ?? 3
            cameraOpacity = saved["cameraOpacity"] as? Double ?? 0.6
            cameraPreviewMirror = saved["cameraPreviewMirror"] as? Bool ?? true
            cameraVideoMirror = saved["cameraVideoMirror"] as? Bool ?? false
        }
        speech.onTranscript = { [weak self] text in
            guard let self, self.voiceMode, self.playing else { return }
            self.heardText = text
            let result = ScriptAligner(script: self.units).align(text, near: Int(self.cursor))
            if result.matched { self.cursor = Double(result.cursor) }
            self.voiceStatus = result.matched ? "跟读中" : "听到了，正在匹配稿件"
        }
        speech.onState = { [weak self] text in self?.voiceStatus = text }
        speech.onFailure = { [weak self] text in
            guard let self else { return }
            self.pause(); self.voiceStatus = text
            if !self.useCapturedAudio { self.message = text }
        }
        ticker = Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect().sink { [weak self] _ in self?.tick() }
    }

    var selected: PromptScript { scripts.first { $0.id == selectedID } ?? scripts[0] }
    var units: ScriptUnits {
        let text = selected.text
        if cachedText != text {
            cachedText = text; cachedUnits = ScriptUnits(text)
            let source = text as NSString
            let regex = try! NSRegularExpression(pattern: "[^。！？\\n]+[。！？]?")
            cachedSentences = regex.matches(in: text, range: NSRange(location: 0, length: source.length)).map { ($0.range, source.substring(with: $0.range)) }
            let tokenizer = NLTokenizer(unit: .word); tokenizer.string = text
            var hints = Set<String>()
            recognitionHints = []
            tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
                let word = String(text[range])
                if (2...12).contains(word.count), hints.insert(word).inserted { self.recognitionHints.append(word) }
                return self.recognitionHints.count < 80
            }
        }
        return cachedUnits
    }
    var hasText: Bool { !units.characters.isEmpty }
    var sourceOffset: Int {
        let map = units
        guard !map.characters.isEmpty else { return 0 }
        if Int(cursor) >= map.characters.count { return selected.text.utf16.count }
        return map.sourceOffsets[max(0, Int(cursor))]
    }
    var progress: Double { min(1, cursor / Double(max(1, units.characters.count))) }
    var sentences: [(range: NSRange, text: String)] {
        _ = units
        return cachedSentences
    }
    var sentenceIndex: Int { sentences.lastIndex { $0.range.location <= sourceOffset } ?? 0 }

    func update(title: String? = nil, text: String? = nil) {
        pause()
        guard let index = scripts.firstIndex(where: { $0.id == selectedID }) else { return }
        if let title { scripts[index].title = title }
        if let text { scripts[index].text = text; cursor = 0 }
    }
    func select(_ script: PromptScript) { pause(); selectedID = script.id; cursor = 0 }
    func create(title: String = "未命名口播", text: String = "") {
        let next = PromptScript(title: title, text: text); scripts.insert(next, at: 0); select(next)
    }
    func saveCopy(date: Date = Date()) {
        let original = selected
        let label = DateFormatter()
        label.dateFormat = "MM-dd HH:mm"
        create(title: original.title + " · " + label.string(from: date), text: original.text)
    }
    func seek(sourceOffset: Int) {
        pause()
        if sourceOffset == 0 { heardText = "" }
        cursor = Double(units.sourceOffsets.firstIndex { $0 >= sourceOffset } ?? units.characters.count)
    }
    func skip(_ direction: Int) {
        let phrases = sentences
        guard !phrases.isEmpty else { return }
        let target = max(0, min(phrases.count - 1, sentenceIndex + direction))
        seek(sourceOffset: phrases[target].range.location)
    }
    func play() {
        guard hasText else { return }
        playGeneration += 1
        let generation = playGeneration
        if progress >= 1 { cursor = 0 }
        if countdown > 0 {
            counting = countdown
            countdownTask?.cancel()
            countdownTask = Task { [weak self] in
                guard let self else { return }
                for value in stride(from: self.countdown, through: 1, by: -1) {
                    guard !Task.isCancelled else { return }; self.counting = value
                    do { try await Task.sleep(for: .seconds(1)) } catch { return }
                }
                guard !Task.isCancelled else { return }; self.counting = nil; await self.begin(generation: generation)
            }
        } else { Task { await begin(generation: generation) } }
    }
    func resumeImmediately() {
        playGeneration += 1
        let generation = playGeneration
        if progress >= 1 { cursor = 0 }
        Task { await begin(generation: generation) }
    }
    private func begin(generation: Int) async {
        guard generation == playGeneration, !Task.isCancelled else { return }
        if voiceMode {
            let ready = await speech.start(usingCapturedAudio: useCapturedAudio, context: recognitionHints)
            if !ready { return }
        }
        guard generation == playGeneration, !Task.isCancelled else { speech.stop(); return }
        playing = true; lastTime = ProcessInfo.processInfo.systemUptime
    }
    func pause() {
        playGeneration += 1
        countdownTask?.cancel(); countdownTask = nil; counting = nil
        playing = false; speech.stop()
        if voiceMode { voiceStatus = "已暂停" }
    }
    func toggle() { if playing || counting != nil { pause() } else { play() } }
    func prepareForPiP() { pause(); voiceMode = false }
    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let delta = min(0.1, max(0, now - lastTime)); lastTime = now
        guard playing, !voiceMode else { return }
        cursor = min(Double(units.characters.count), cursor + delta * speed / 60)
        if progress >= 1 { pause() }
    }
    private func save() {
        if let data = try? JSONEncoder().encode(scripts) { defaults.set(data, forKey: storeKey) }
    }
    private func saveSettings() {
        defaults.set(["font": fontSize, "speed": speed, "mirror": mirror, "countdown": countdown, "cameraOpacity": cameraOpacity,
                      "cameraPreviewMirror": cameraPreviewMirror, "cameraVideoMirror": cameraVideoMirror], forKey: "jianzhou.prompter.settings.v1")
    }
}
