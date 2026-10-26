import AVFoundation
import Combine
import Photos
import UIKit

/// The capture session produces each microphone sample once. The same sample is
/// sent to the movie writer and SpeechFollower; no second audio engine is opened.
@MainActor
final class CameraRecorder: ObservableObject {
    let pipeline = CameraPipeline()
    @Published private(set) var ready = false
    @Published private(set) var recording = false
    @Published private(set) var finishing = false
    @Published private(set) var device: AVCaptureDevice?
    @Published private(set) var lastVideo: URL?
    @Published private(set) var status = "正在准备镜头"
    @Published private(set) var startedAt: Date?
    var captureAngle: CGFloat = 90
    var onInterruption: (() -> Void)?
    private var observers: [NSObjectProtocol] = []

    init() {
        for name in [AVCaptureSession.wasInterruptedNotification, AVCaptureSession.runtimeErrorNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: pipeline.session, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.onInterruption?()
                    if self.recording { self.stop() }
                    self.status = "拍摄被系统中断，请回到本页重新准备镜头。"
                }
            })
        }
    }

    deinit { for observer in observers { NotificationCenter.default.removeObserver(observer) } }

    func prepare(speech: SpeechFollower) async {
        let camera = await AVCaptureDevice.requestAccess(for: .video)
        let microphone = await AVAudioApplication.requestRecordPermission()
        guard camera, microphone else { status = "请在系统设置中允许相机和麦克风。"; return }
        do {
            device = try await pipeline.prepare { sample in speech.appendCapturedAudio(sample) }
            ready = true; status = "镜头已就绪 · 提词文字不会录进视频"
        } catch { status = error.localizedDescription }
    }

    func start() async -> Bool {
        guard ready, !recording, !finishing else { return false }
        do {
            let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("拍摄视频", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let label = DateFormatter(); label.dateFormat = "yyyyMMdd-HHmmss"
            var url = folder.appendingPathComponent("见舟口播-\(label.string(from: Date())).mov")
            var number = 2
            while FileManager.default.fileExists(atPath: url.path) {
                url = folder.appendingPathComponent("见舟口播-\(label.string(from: Date()))-\(number).mov"); number += 1
            }
            try await pipeline.start(url: url, angle: captureAngle)
            recording = true; startedAt = Date(); status = "正在录像"
            return true
        } catch { status = "无法录像：\(error.localizedDescription)"; return false }
    }

    func stop() {
        guard recording, !finishing else { return }
        recording = false; finishing = true; status = "正在保存视频"
        Task {
            do {
                lastVideo = try await pipeline.finish()
                status = "视频已保存到本机，可保存到相册或分享给剪映。"
            } catch { status = "视频未保存：\(error.localizedDescription)" }
            finishing = false
        }
    }

    func flip() async {
        guard !recording, !finishing else { return }
        do { device = try await pipeline.flip() }
        catch { status = error.localizedDescription }
    }

    func close() {
        if recording { stop() }
        pipeline.close()
        ready = false
    }

    func saveToPhotos() async {
        guard let url = lastVideo else { return }
        let permission = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard permission == .authorized || permission == .limited else {
            status = "未允许写入相册；视频仍在“文件 → 见舟提词 → 拍摄视频”中。"; return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }
            status = "已保存到相册。"
        } catch { status = "保存相册失败：\(error.localizedDescription)；本机视频仍保留。" }
    }
}

final class CameraPipeline: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate,
    AVCaptureAudioDataOutputSampleBufferDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "jianzhou.camera.capture", qos: .userInitiated)
    private let video = AVCaptureVideoDataOutput()
    private let audio = AVCaptureAudioDataOutput()
    private var cameraInput: AVCaptureDeviceInput?
    private var audioSink: (@Sendable (CMSampleBuffer) -> Void)?
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var firstFrame: CMTime?
    private var videoSamples = 0
    private var audioSamples = 0

    private func failure(_ text: String) -> NSError {
        NSError(domain: "JianzhouCamera", code: 1, userInfo: [NSLocalizedDescriptionKey: text])
    }

    func prepare(audioSink: @escaping @Sendable (CMSampleBuffer) -> Void) async throws -> AVCaptureDevice {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    self.audioSink = audioSink
                    if let camera = self.cameraInput?.device {
                        let audioSession = AVAudioSession.sharedInstance()
                        try audioSession.setCategory(.playAndRecord, mode: .videoRecording, options: .defaultToSpeaker)
                        try audioSession.setActive(true)
                        if !self.session.isRunning { self.session.startRunning() }
                        continuation.resume(returning: camera)
                        return
                    }
                    self.session.beginConfiguration()
                    var configuring = true
                    do {
                        self.session.sessionPreset = .hd1920x1080
                        self.session.automaticallyConfiguresApplicationAudioSession = false
                        let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                        guard let camera, let mic = AVCaptureDevice.default(for: .audio) else {
                            throw self.failure("当前设备没有可用的相机或麦克风。")
                        }
                        let input = try AVCaptureDeviceInput(device: camera)
                        let microphone = try AVCaptureDeviceInput(device: mic)
                        guard self.session.canAddInput(input), self.session.canAddInput(microphone) else {
                            throw self.failure("无法连接相机和麦克风。")
                        }
                        self.session.addInput(input); self.session.addInput(microphone)
                        self.video.alwaysDiscardsLateVideoFrames = true
                        self.video.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
                        guard self.session.canAddOutput(self.video), self.session.canAddOutput(self.audio) else {
                            throw self.failure("无法建立录像输出。")
                        }
                        self.session.addOutput(self.video); self.session.addOutput(self.audio)
                        self.video.setSampleBufferDelegate(self, queue: self.queue)
                        self.audio.setSampleBufferDelegate(self, queue: self.queue)
                        if let connection = self.video.connection(with: .video), connection.isVideoMirroringSupported {
                            connection.automaticallyAdjustsVideoMirroring = false; connection.isVideoMirrored = false
                        }
                        self.session.commitConfiguration()
                        configuring = false
                        self.cameraInput = input
                        let audioSession = AVAudioSession.sharedInstance()
                        try audioSession.setCategory(.playAndRecord, mode: .videoRecording, options: .defaultToSpeaker)
                        try audioSession.setActive(true)
                        self.session.startRunning()
                        continuation.resume(returning: camera)
                    } catch {
                        if configuring { self.session.commitConfiguration() }
                        throw error
                    }
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    func flip() async throws -> AVCaptureDevice {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    guard let previous = self.cameraInput else { throw self.failure("镜头尚未就绪。") }
                    let position: AVCaptureDevice.Position = previous.device.position == .front ? .back : .front
                    guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
                        throw self.failure("这个镜头暂不可用。")
                    }
                    let input = try AVCaptureDeviceInput(device: device)
                    self.session.beginConfiguration(); self.session.removeInput(previous)
                    guard self.session.canAddInput(input) else {
                        self.session.addInput(previous); self.session.commitConfiguration()
                        throw self.failure("无法切换镜头。")
                    }
                    self.session.addInput(input); self.cameraInput = input
                    if let connection = self.video.connection(with: .video), connection.isVideoMirroringSupported {
                        connection.automaticallyAdjustsVideoMirroring = false; connection.isVideoMirrored = false
                    }
                    self.session.commitConfiguration()
                    continuation.resume(returning: device)
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    func start(url: URL, angle: CGFloat) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    guard self.session.isRunning, self.writer == nil else { throw self.failure("请先准备好镜头。") }
                    let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
                    guard let videoSettings = self.video.recommendedVideoSettingsForAssetWriter(writingTo: .mov),
                          let audioSettings = self.audio.recommendedAudioSettingsForAssetWriter(writingTo: .mov) else {
                        throw self.failure("无法取得录像编码设置。")
                    }
                    let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                    let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
                    videoInput.expectsMediaDataInRealTime = true; audioInput.expectsMediaDataInRealTime = true
                    videoInput.transform = CGAffineTransform(rotationAngle: angle * .pi / 180)
                    guard writer.canAdd(videoInput), writer.canAdd(audioInput) else { throw self.failure("无法建立音视频文件。") }
                    writer.add(videoInput); writer.add(audioInput)
                    guard writer.startWriting() else { throw writer.error ?? self.failure("无法开始写入视频。") }
                    self.writer = writer; self.videoInput = videoInput; self.audioInput = audioInput
                    self.firstFrame = nil; self.videoSamples = 0; self.audioSamples = 0
                    continuation.resume()
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }
        let isVideo = output === video
        if !isVideo { audioSink?(sampleBuffer) }
        guard let writer, writer.status == .writing else { return }
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if firstFrame == nil {
            guard isVideo else { return }
            writer.startSession(atSourceTime: timestamp); firstFrame = timestamp
        }
        guard let firstFrame, CMTimeCompare(timestamp, firstFrame) >= 0 else { return }
        let input = isVideo ? videoInput : audioInput
        if let input, input.isReadyForMoreMediaData, input.append(sampleBuffer) {
            if isVideo { videoSamples += 1 } else { audioSamples += 1 }
        }
    }

    func finish() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                guard let writer = self.writer else { continuation.resume(throwing: self.failure("没有正在录制的视频。")); return }
                let hasSamples = self.videoSamples > 0 && self.audioSamples > 0
                self.writer = nil
                guard writer.status == .writing else {
                    continuation.resume(throwing: writer.error ?? self.failure("录像已中断。")); return
                }
                self.videoInput?.markAsFinished(); self.audioInput?.markAsFinished()
                self.videoInput = nil; self.audioInput = nil
                guard hasSamples else {
                    writer.cancelWriting()
                    try? FileManager.default.removeItem(at: writer.outputURL)
                    continuation.resume(throwing: self.failure("没有收齐画面和声音，请确认镜头已打开后再录制。")); return
                }
                writer.finishWriting {
                    if writer.status == .completed { continuation.resume(returning: writer.outputURL) }
                    else { continuation.resume(throwing: writer.error ?? self.failure("视频写入失败。")) }
                }
            }
        }
    }

    func close() {
        queue.async {
            self.audioSink = nil
            if self.session.isRunning { self.session.stopRunning() }
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}
