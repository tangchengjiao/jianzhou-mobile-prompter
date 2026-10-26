import AVFoundation
import SwiftUI

@MainActor
struct CameraView: View {
    @EnvironmentObject private var model: PrompterModel
    @EnvironmentObject private var pip: PiPController
    @Environment(\.scenePhase) private var phase
    @StateObject private var recorder = CameraRecorder()
    @State private var settings = false
    @State private var countdown: Int?
    @State private var starting: Task<Void, Never>?
    @State private var review: RecordedVideo?
    @State private var showRecordingTools = false
    @State private var hideToolsTask: Task<Void, Never>?
    @AppStorage("camera.prompt.x") private var x = 0.5
    @AppStorage("camera.prompt.y") private var y = 0.28
    @AppStorage("camera.prompt.width") private var width = 0.88
    @AppStorage("camera.prompt.height") private var height = 0.26
    @State private var dragOrigin: CGPoint?
    @State private var resizeOrigin: CGRect?
    private var toolsVisible: Bool { !recorder.recording || showRecordingTools }

    var body: some View {
        GeometryReader { geometry in
            let area = CGSize(width: geometry.size.width, height: max(180, geometry.size.height - 210))
            let panelWidth = min(max(180, area.width * width), area.width - 16)
            let panelHeight = min(max(110, area.height * height), area.height)
            let center = CGPoint(x: min(max(panelWidth / 2 + 8, area.width * x), area.width - panelWidth / 2 - 8),
                                 y: min(max(panelHeight / 2, area.height * y), area.height - panelHeight / 2))
            ZStack(alignment: .bottom) {
                CameraPreview(recorder: recorder, mirrored: model.cameraPreviewMirror).ignoresSafeArea()
                    .contentShape(Rectangle()).onTapGesture { toggleRecordingTools() }
                promptPanel(size: CGSize(width: panelWidth, height: panelHeight), area: area, center: center)
                    .frame(width: panelWidth, height: panelHeight)
                    .position(center)
                if let countdown {
                    Text("\(countdown)").font(.system(size: 80, weight: .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity).allowsHitTesting(false)
                }
                VStack(spacing: 10) {
                    if toolsVisible { Text(recorder.status).font(.caption).foregroundStyle(.white).lineLimit(2) }
                    if toolsVisible && model.voiceMode {
                        HStack {
                            Text(model.voiceStatus).lineLimit(1)
                            Spacer()
                            if recorder.recording && !model.playing { Button("重新跟读") { model.resumeImmediately() } }
                        }.font(.caption2).foregroundStyle(.white)
                        if !model.heardText.isEmpty {
                            Text("听到：\(String(model.heardText.suffix(32)))").font(.caption2)
                                .foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                        }
                    }
                    HStack(spacing: 25) {
                        if toolsVisible {
                            Button { settings = true } label: { Image(systemName: "slider.horizontal.3").font(.title2) }
                                .accessibilityLabel("拍摄提词设置")
                        }
                        Button(action: toggleRecording) {
                            ZStack {
                                Circle().stroke(.white, lineWidth: 3).frame(width: 68, height: 68)
                                if recorder.recording || starting != nil {
                                    RoundedRectangle(cornerRadius: 6).fill(.red).frame(width: 28, height: 28)
                                } else { Circle().fill(.red).frame(width: 56, height: 56) }
                            }
                        }.disabled(!recorder.ready || recorder.finishing)
                            .accessibilityLabel(recorder.recording ? "停止录像" : (starting == nil ? "开始录像" : "取消倒计时"))
                        if toolsVisible {
                            Button { Task { await recorder.flip() } } label: { Image(systemName: "arrow.triangle.2.circlepath.camera").font(.title2) }
                                .disabled(recorder.recording || recorder.finishing || starting != nil).accessibilityLabel("切换镜头")
                        }
                    }.foregroundStyle(.white)
                    if toolsVisible { HStack {
                        Toggle("语音跟读", isOn: $model.voiceMode).disabled(recorder.recording || starting != nil)
                        Spacer()
                        if let date = recorder.startedAt, recorder.recording {
                            Text(date, style: .timer).monospacedDigit()
                        }
                    }.font(.caption).foregroundStyle(.white) }
                    if let url = recorder.lastVideo, !recorder.recording, !recorder.finishing {
                        HStack {
                            Button("预览") {
                                Task { await recorder.prepareForReview(); review = RecordedVideo(url: url) }
                            }
                            Spacer()
                            Button("保存到相册") { Task { await recorder.saveToPhotos() } }
                            Spacer()
                            ShareLink("分享视频", item: url)
                        }.font(.subheadline).foregroundStyle(.white)
                    }
                }.padding(18).background(.black.opacity(toolsVisible ? 0.7 : 0))
            }.background(.black)
        }
        .navigationTitle("拍摄跟读").navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.black, for: .navigationBar).toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $settings) { PromptSettings(camera: true, recording: recorder.recording) }
        .sheet(item: $review, onDismiss: {
            if phase == .active { Task { await recorder.prepare(speech: model.speech) } }
        }) { clip in VideoReview(clip: clip, recorder: recorder) }
        .onChange(of: recorder.lastVideo) { _, url in
            if let url { model.pause(); review = RecordedVideo(url: url) }
        }
        .onChange(of: recorder.recording) { _, _ in
            showRecordingTools = false; hideToolsTask?.cancel()
        }
        .task {
            pip.stop(); model.pause(); model.voiceMode = true; model.useCapturedAudio = true
            recorder.onInterruption = { cancelStart(); model.pause() }
            await recorder.prepare(speech: model.speech)
        }
        .onChange(of: phase) { _, value in
            if value == .background { cancelStart(); model.pause(); recorder.close() }
            else if value == .active, !recorder.ready, review == nil { Task { await recorder.prepare(speech: model.speech) } }
        }
        .onDisappear { cancelStart(); hideToolsTask?.cancel(); model.pause(); model.useCapturedAudio = false; recorder.close() }
    }

    private func toggleRecordingTools() {
        guard recorder.recording else { return }
        hideToolsTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) { showRecordingTools.toggle() }
        if showRecordingTools {
            hideToolsTask = Task {
                do { try await Task.sleep(for: .seconds(4)) } catch { return }
                withAnimation(.easeOut(duration: 0.2)) { showRecordingTools = false }
            }
        }
    }

    private func toggleRecording() {
        if recorder.recording { model.pause(); recorder.stop(); return }
        if starting != nil { cancelStart(); return }
        model.seek(sourceOffset: 0)
        starting = Task {
            if model.voiceMode, !(await model.speech.authorize()) { starting = nil; return }
            for value in stride(from: model.countdown, through: 1, by: -1) {
                guard !Task.isCancelled else { return }
                countdown = value
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
            countdown = nil
            guard !Task.isCancelled else { return }
            let mirrorVideo = model.cameraVideoMirror && recorder.device?.position == .front
            if await recorder.start(mirrored: mirrorVideo) {
                if Task.isCancelled { recorder.stop() }
                else { model.resumeImmediately() }
            }
            starting = nil
        }
    }

    private func cancelStart() { starting?.cancel(); starting = nil; countdown = nil }

    private func promptPanel(size: CGSize, area: CGSize, center: CGPoint) -> some View {
        VStack(spacing: 0) {
            HStack {
                Spacer(); Capsule().fill(.white.opacity(0.6)).frame(width: 34, height: 3)
                Text("拖动").font(.system(size: 10)); Spacer()
            }.frame(height: 25).contentShape(Rectangle()).foregroundStyle(.white.opacity(0.7))
                .accessibilityIdentifier("camera-prompt-drag")
                .gesture(DragGesture(minimumDistance: 2).onChanged { value in
                    if dragOrigin == nil { dragOrigin = center }
                    guard let origin = dragOrigin else { return }
                    x = min(max(size.width / 2 + 8, origin.x + value.translation.width), area.width - size.width / 2 - 8) / area.width
                    y = min(max(size.height / 2, origin.y + value.translation.height), area.height - size.height / 2) / area.height
                }.onEnded { _ in dragOrigin = nil })
            CameraPromptText(text: model.selected.text, sourceOffset: model.sourceOffset, fontSize: model.fontSize) { offset in
                model.seek(sourceOffset: offset)
                if recorder.recording { model.resumeImmediately() }
            }
                .scaleEffect(x: model.mirror ? -1 : 1, y: 1)
            HStack {
                Text(model.voiceMode ? "语音跟读" : "匀速提词").font(.system(size: 10)).padding(.leading, 12)
                Spacer()
                Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: 12)).frame(width: 32, height: 25)
                    .contentShape(Rectangle()).accessibilityLabel("调整提词窗大小")
                    .gesture(DragGesture(minimumDistance: 1).onChanged { value in
                        if resizeOrigin == nil { resizeOrigin = CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height) }
                        guard let origin = resizeOrigin else { return }
                        let w = min(max(180, origin.width + value.translation.width), area.width - 8 - origin.minX)
                        let h = min(max(110, origin.height + value.translation.height), area.height - origin.minY)
                        width = w / area.width; height = h / area.height
                        x = (origin.minX + w / 2) / area.width; y = (origin.minY + h / 2) / area.height
                    }.onEnded { _ in resizeOrigin = nil })
            }.foregroundStyle(.white.opacity(0.65))
        }.background(.black.opacity(model.cameraOpacity), in: RoundedRectangle(cornerRadius: 14))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var recorder: CameraRecorder
    let mirrored: Bool
    func makeUIView(context: Context) -> CameraPreviewHost {
        let view = CameraPreviewHost()
        view.preview.session = recorder.pipeline.session
        view.onCaptureAngle = { recorder.captureAngle = $0 }
        return view
    }
    func updateUIView(_ uiView: CameraPreviewHost, context: Context) { uiView.configure(device: recorder.device, mirrored: mirrored) }
}

final class CameraPreviewHost: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var preview: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    var onCaptureAngle: ((CGFloat) -> Void)?
    private var coordinator: AVCaptureDevice.RotationCoordinator?
    private var observations: [NSKeyValueObservation] = []
    private var mirrorPreview = true
    func configure(device: AVCaptureDevice?, mirrored: Bool) {
        mirrorPreview = mirrored && device?.position == .front
        if let connection = preview.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false; connection.isVideoMirrored = mirrorPreview
        }
        guard let device, coordinator?.device !== device else { return }
        observations.removeAll()
        preview.videoGravity = .resizeAspectFill
        let rotation = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: preview)
        coordinator = rotation
        observations = [
            rotation.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.initial, .new]) { [weak self] rotation, _ in
                let angle = rotation.videoRotationAngleForHorizonLevelPreview
                DispatchQueue.main.async {
                    guard let connection = self?.preview.connection, connection.isVideoRotationAngleSupported(angle) else { return }
                    connection.videoRotationAngle = angle
                    if connection.isVideoMirroringSupported {
                        connection.automaticallyAdjustsVideoMirroring = false; connection.isVideoMirrored = self?.mirrorPreview ?? false
                    }
                }
            },
            rotation.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.initial, .new]) { [weak self] rotation, _ in
                let angle = rotation.videoRotationAngleForHorizonLevelCapture
                DispatchQueue.main.async { self?.onCaptureAngle?(angle) }
            },
        ]
    }
}
