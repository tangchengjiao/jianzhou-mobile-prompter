import AVFoundation
import Speech

/// Foreground, on-device Mandarin practice. PiP switches to timed mode so it
/// does not compete with the user's filming app for the microphone.
@MainActor
final class SpeechFollower {
    var onTranscript: ((String) -> Void)?
    var onFailure: ((String) -> Void)?
    var onState: ((String) -> Void)?
    var onUtteranceStart: (() -> Void)?
    private let engine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var installedTap = false
    private nonisolated let audioRequest = AudioRequestSlot()
    private var ownsAudioSession = false
    private var active = false
    private var generation = 0
    private var recognitionGeneration = 0
    private var retryCount = 0
    private var context: [String] = []
    private var restartTask: Task<Void, Never>?
    private var rotationTask: Task<Void, Never>?
    private var interruption: NSObjectProtocol?

    init() {
        interruption = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            let type = (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt).flatMap { AVAudioSession.InterruptionType(rawValue: $0) }
            if type == .began {
                Task { @MainActor [weak self] in
                    guard let self, self.active else { return }
                    self.stop(); self.onFailure?("麦克风被其他应用占用，语音练习已暂停。")
                }
            }
        }
    }

    func authorize() async -> Bool {
        let authorization = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard authorization == .authorized else { onFailure?("请允许语音识别，或使用匀速提词。"); return false }
        let microphone = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
        guard microphone else { onFailure?("请允许麦克风，或使用匀速提词。"); return false }
        return true
    }

    nonisolated func appendCapturedAudio(_ buffer: CMSampleBuffer) {
        audioRequest.append(buffer)
    }

    func start(usingCapturedAudio: Bool = false, context: [String] = []) async -> Bool {
        stop()
        let token = generation
        guard await authorize(), generation == token, !Task.isCancelled else { return false }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN")), recognizer.supportsOnDeviceRecognition else {
            onFailure?("这台手机暂未提供可用的中文端侧识别。可以先用匀速模式；本应用不会改用收费云接口。")
            return false
        }
        self.recognizer = recognizer
        self.context = Array(context.prefix(100))
        retryCount = 0
        if usingCapturedAudio {
            active = true
            armRecognition()
            return true
        }
        do {
            let audio = AVAudioSession.sharedInstance()
            try audio.setCategory(.record, mode: .measurement)
            try audio.setActive(true)
            ownsAudioSession = true
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                stop(); onFailure?("麦克风还没有准备好，请检查接麦方式后重试。"); return false
            }
            active = true
            armRecognition()
            let slot = audioRequest
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in slot.append(buffer) }
            installedTap = true
            engine.prepare()
            try engine.start()
            return true
        } catch {
            stop(); onFailure?("语音练习无法启动：\(error.localizedDescription)"); return false
        }
    }

    private func armRecognition() {
        guard active, let recognizer else { return }
        rotationTask?.cancel()
        recognitionGeneration += 1
        let token = recognitionGeneration
        audioRequest.set(nil)
        request?.endAudio(); task?.cancel()
        let next = SFSpeechAudioBufferRecognitionRequest()
        next.requiresOnDeviceRecognition = true
        next.shouldReportPartialResults = true
        next.taskHint = .dictation
        next.contextualStrings = context
        request = next
        audioRequest.set(next)
        onUtteranceStart?()
        onState?("正在听，请按稿朗读")
        task = recognizer.recognitionTask(with: next) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self, self.active, self.recognitionGeneration == token else { return }
                if let result, !result.bestTranscription.formattedString.isEmpty {
                    self.retryCount = 0
                    self.onTranscript?(result.bestTranscription.formattedString)
                }
                if result?.isFinal == true {
                    self.armRecognition()
                } else if let error {
                    self.recoverRecognition(error)
                }
            }
        }
        // Roll over long live requests while retaining the camera's microphone
        // session. A completed or restarted request never stops the movie writer.
        rotationTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(45)) } catch { return }
            guard let self, self.active, self.recognitionGeneration == token else { return }
            self.armRecognition()
        }
    }

    private func recoverRecognition(_ error: Error) {
        guard active else { return }
        recognitionGeneration += 1
        rotationTask?.cancel()
        audioRequest.set(nil); request?.endAudio(); task?.cancel(); task = nil
        guard retryCount < 3 else {
            stop(); onFailure?("识别暂时不可用，可点“重新跟读”恢复：\(error.localizedDescription)"); return
        }
        retryCount += 1
        onState?("识别正在恢复，提词保持当前位置")
        restartTask?.cancel()
        restartTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
            guard let self, self.active else { return }
            self.armRecognition()
        }
    }

    func stop() {
        generation += 1; active = false
        recognitionGeneration += 1
        restartTask?.cancel(); restartTask = nil
        rotationTask?.cancel(); rotationTask = nil
        if engine.isRunning { engine.stop() }
        if installedTap { engine.inputNode.removeTap(onBus: 0); installedTap = false }
        audioRequest.set(nil)
        request?.endAudio(); task?.cancel(); task = nil; request = nil
        // Do not deactivate another app's audio session when already stopped.
        if ownsAudioSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        ownsAudioSession = false; recognizer = nil
    }
}

private final class AudioRequestSlot: @unchecked Sendable {
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    func set(_ next: SFSpeechAudioBufferRecognitionRequest?) { lock.lock(); request = next; lock.unlock() }
    func append(_ buffer: AVAudioPCMBuffer) { lock.lock(); defer { lock.unlock() }; request?.append(buffer) }
    func append(_ buffer: CMSampleBuffer) { lock.lock(); defer { lock.unlock() }; request?.appendAudioSampleBuffer(buffer) }
}
