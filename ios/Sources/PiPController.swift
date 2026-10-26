// Adapted from Reeb's MIT-licensed PiPController/PipFrameRenderer architecture.
// Copyright (c) 2026 Enoch Ansong. License text: ../ThirdParty/Reeb-LICENSE.txt.
// Jianzhou adaptation: Chinese layout, actual playback controls, no microphone
// in PiP, reusable text layout, interruption reporting and explicit shutdown.
import AVKit
import Combine
import SwiftUI
import UIKit

@MainActor
final class PiPController: NSObject, ObservableObject {
    @Published private(set) var possible = false
    @Published private(set) var isActive = false
    @Published private(set) var pending = false
    @Published private(set) var status = "等待画中画预览就绪"
    @Published private(set) var events: [String] = []
    let layer = AVSampleBufferDisplayLayer()
    let supported = AVPictureInPictureController.isPictureInPictureSupported()
    private var controller: AVPictureInPictureController?
    private weak var model: PrompterModel?
    private var observation: NSKeyValueObservation?
    private var frameTimer: Timer?
    private var subscriptions = Set<AnyCancellable>()
    private var frameSize = CGSize(width: 720, height: 420)
    private let renderer = PromptFrameRenderer()

    override init() {
        super.init()
        layer.videoGravity = .resizeAspect
        var timebase: CMTimebase?
        CMTimebaseCreateWithSourceClock(allocator: kCFAllocatorDefault, sourceClock: CMClockGetHostTimeClock(), timebaseOut: &timebase)
        if let timebase {
            CMTimebaseSetTime(timebase, time: .zero); CMTimebaseSetRate(timebase, rate: 1)
            layer.controlTimebase = timebase
        }
    }

    func configure(_ model: PrompterModel) {
        self.model = model
        guard controller == nil, supported else { return }
        let source = AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer: layer, playbackDelegate: self)
        let controller = AVPictureInPictureController(contentSource: source)
        controller.delegate = self
        controller.requiresLinearPlayback = false
        controller.canStartPictureInPictureAutomaticallyFromInline = false
        self.controller = controller
        observation = controller.observe(\.isPictureInPicturePossible, options: [.initial, .new]) { [weak self] observed, _ in
            let possible = observed.isPictureInPicturePossible
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.possible = possible
                if possible && self.pending { self.controller?.startPictureInPicture() }
                if possible && !self.isActive { self.status = "画中画可启动；录像兼容性仍需实测" }
            }
        }
        model.$playing.sink { [weak self] _ in
            DispatchQueue.main.async { self?.controller?.invalidatePlaybackState() }
        }.store(in: &subscriptions)
        frameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.render() }
        }
        render()
    }

    func start() {
        guard supported, let model, model.hasText else { status = "当前设备暂不支持画中画，或稿件为空"; return }
        model.prepareForPiP()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback, options: .mixWithOthers)
            try session.setActive(true)
        } catch { record("音频会话准备失败：\(error.localizedDescription)"); return }
        pending = true; render()
        if possible { controller?.startPictureInPicture() }
        else { record("等待系统允许画中画；请保持预览可见") }
    }

    func stop() {
        pending = false
        if isActive { controller?.stopPictureInPicture() }
        model?.pause()
    }

    func record(_ text: String) {
        status = text
        let time = Date().formatted(date: .omitted, time: .standard)
        events.append("\(time) \(text)")
        if events.count > 40 { events.removeFirst(events.count - 40) }
    }

    private func render() {
        guard let model, layer.superlayer != nil || isActive || pending else { return }
        let time = layer.controlTimebase.map { CMTimebaseGetTime($0) } ?? CMClockGetTime(CMClockGetHostTimeClock())
        guard let buffer = renderer.frame(text: model.selected.text, sourceOffset: model.sourceOffset, fontSize: model.fontSize, mirrored: model.mirror, size: frameSize, timestamp: time) else { return }
        if layer.status == .failed { layer.flush() }
        layer.enqueue(buffer)
    }
}

extension PiPController: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
        isActive = true; pending = false; record("画中画已启动；请切到拍摄 App 开始录像测试")
        model?.play()
    }
    func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        isActive = false; pending = false; model?.pause(); record("画中画已停止")
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    func pictureInPictureController(_ controller: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        pending = false; isActive = false; record("画中画启动失败：\(error.localizedDescription)")
    }
    func pictureInPictureController(_ controller: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        completionHandler(true)
    }
}

extension PiPController: AVPictureInPictureSampleBufferPlaybackDelegate {
    func pictureInPictureController(_ controller: AVPictureInPictureController, setPlaying playing: Bool) {
        guard let model else { return }
        if playing { model.resumeImmediately() } else { model.pause() }
        controller.invalidatePlaybackState()
    }
    func pictureInPictureControllerTimeRangeForPlayback(_ controller: AVPictureInPictureController) -> CMTimeRange {
        CMTimeRange(start: .negativeInfinity, duration: .positiveInfinity)
    }
    func pictureInPictureControllerIsPlaybackPaused(_ controller: AVPictureInPictureController) -> Bool { model?.playing != true }
    func pictureInPictureController(_ controller: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
        guard newRenderSize.width > 0, newRenderSize.height > 0 else { return }
        let scale = 720.0 / Double(newRenderSize.width)
        frameSize = CGSize(width: 720, height: min(1200, max(240, Double(newRenderSize.height) * scale)))
        render()
    }
    func pictureInPictureController(_ controller: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) {
        model?.skip(skipInterval.seconds > 0 ? 1 : -1); render(); completionHandler()
    }
}

struct PiPPreview: UIViewRepresentable {
    @ObservedObject var controller: PiPController
    func makeUIView(context: Context) -> UIView {
        PiPPreviewHost(displayLayer: controller.layer)
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        controller.layer.frame = uiView.bounds
        CATransaction.commit()
        DispatchQueue.main.async { controller.layer.frame = uiView.bounds }
    }
}

private final class PiPPreviewHost: UIView {
    let displayLayer: AVSampleBufferDisplayLayer
    init(displayLayer: AVSampleBufferDisplayLayer) {
        self.displayLayer = displayLayer
        super.init(frame: .zero)
        backgroundColor = .black; layer.addSublayer(displayLayer)
    }
    required init?(coder: NSCoder) { fatalError("Use init(displayLayer:)") }
    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        displayLayer.frame = bounds; CATransaction.commit()
    }
}

@MainActor
private final class PromptFrameRenderer {
    private var key = ""
    private var layout: NSLayoutManager?
    private var storage: NSTextStorage?
    private var offset: CGFloat = 0

    func frame(text: String, sourceOffset: Int, fontSize: Double, mirrored: Bool, size: CGSize, timestamp: CMTime) -> CMSampleBuffer? {
        let width = Int(size.width); let height = Int(size.height)
        var pixels: CVPixelBuffer?
        let options: [CFString: Any] = [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true, kCVPixelBufferIOSurfacePropertiesKey: [:]]
        guard CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, options as CFDictionary, &pixels) == kCVReturnSuccess, let pixels else { return nil }
        CVPixelBufferLockBaseAddress(pixels, [])
        defer { CVPixelBufferUnlockBaseAddress(pixels, []) }
        guard let cg = CGContext(data: CVPixelBufferGetBaseAddress(pixels), width: width, height: height, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixels), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { return nil }
        cg.setFillColor(UIColor(red: 0.11, green: 0.10, blue: 0.14, alpha: 1).cgColor); cg.fill(CGRect(origin: .zero, size: size))
        cg.translateBy(x: 0, y: size.height); cg.scaleBy(x: 1, y: -1)
        if mirrored { cg.translateBy(x: size.width, y: 0); cg.scaleBy(x: -1, y: 1) }
        let font = CGFloat(fontSize) * size.width / 393
        let newKey = "\(text)|\(font)|\(width)"
        if key != newKey {
            key = newKey; offset = 0
            let style = NSMutableParagraphStyle(); style.lineSpacing = font * 0.28; style.paragraphSpacing = font * 0.7
            let store = NSTextStorage(string: text, attributes: [.font: UIFont.systemFont(ofSize: font, weight: .semibold), .foregroundColor: UIColor(white: 0.68, alpha: 1), .paragraphStyle: style])
            let manager = NSLayoutManager()
            let container = NSTextContainer(size: CGSize(width: size.width - 64, height: .greatestFiniteMagnitude)); container.lineFragmentPadding = 0
            manager.addTextContainer(container); store.addLayoutManager(manager)
            manager.ensureLayout(for: container); storage = store; layout = manager
        }
        guard let layout, let storage, layout.numberOfGlyphs > 0 else { return nil }
        let char = max(0, min(storage.length - 1, sourceOffset))
        let glyph = layout.glyphIndexForCharacter(at: char)
        var lineRange = NSRange()
        let line = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: &lineRange)
        let target = max(0, line.minY - font * 0.5)
        offset += (target - offset) * 0.32
        layout.removeTemporaryAttribute(.foregroundColor, forCharacterRange: NSRange(location: 0, length: storage.length))
        if char > 0 { layout.addTemporaryAttribute(.foregroundColor, value: UIColor(white: 0.35, alpha: 1), forCharacterRange: NSRange(location: 0, length: char)) }
        let current = layout.characterRange(forGlyphRange: lineRange, actualGlyphRange: nil)
        layout.addTemporaryAttribute(.foregroundColor, value: UIColor(red: 0.93, green: 0.9, blue: 1, alpha: 1), forCharacterRange: current)
        UIGraphicsPushContext(cg)
        layout.drawGlyphs(forGlyphRange: NSRange(location: 0, length: layout.numberOfGlyphs), at: CGPoint(x: 32, y: 25 - offset))
        UIGraphicsPopContext()
        var format: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixels, formatDescriptionOut: &format)
        guard let format else { return nil }
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 15), presentationTimeStamp: timestamp, decodeTimeStamp: .invalid)
        var buffer: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixels, formatDescription: format, sampleTiming: &timing, sampleBufferOut: &buffer)
        return buffer
    }
}
