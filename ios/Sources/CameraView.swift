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
    @AppStorage("camera.prompt.x") private var x = 0.5
    @AppStorage("camera.prompt.y") private var y = 0.28
    @AppStorage("camera.prompt.width") private var width = 0.88
    @AppStorage("camera.prompt.height") private var height = 0.26
    @State private var dragOrigin: CGPoint?
    @State private var resizeOrigin: CGRect?

    var body: some View {
        GeometryReader { geometry in
            let area = CGSize(width: geometry.size.width, height: max(180, geometry.size.height - 170))
            let panelWidth = min(max(180, area.width * width), area.width - 16)
            let panelHeight = min(max(110, area.height * height), area.height)
            let center = CGPoint(x: min(max(panelWidth / 2 + 8, area.width * x), area.width - panelWidth / 2 - 8),
                                 y: min(max(panelHeight / 2, area.height * y), area.height - panelHeight / 2))
            ZStack(alignment: .bottom) {
                CameraPreview(recorder: recorder).ignoresSafeArea()
                VStack { Spacer() }.frame(maxWidth: .infinity, maxHeight: .infinity)
                promptPanel(size: CGSize(width: panelWidth, height: panelHeight), area: area, center: center)
                    .frame(width: panelWidth, height: panelHeight)
                    .position(center)
                if let countdown {
                    Text("\(countdown)").font(.system(size: 80, weight: .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity).allowsHitTesting(false)
                }
                VStack(spacing: 10) {
                    Text(recorder.status).font(.caption).foregroundStyle(.white).lineLimit(2)
                    HStack(spacing: 25) {
                        Button { settings = true } label: { Image(systemName: "slider.horizontal.3").font(.title2) }
                            .accessibilityLabel("拍摄提词设置")
                        Button(action: toggleRecording) {
                            ZStack {
                                Circle().stroke(.white, lineWidth: 3).frame(width: 68, height: 68)
                                if recorder.recording || starting != nil {
                                    RoundedRectangle(cornerRadius: 6).fill(.red).frame(width: 28, height: 28)
                                } else { Circle().fill(.red).frame(width: 56, height: 56) }
                            }
                        }.disabled(!recorder.ready || recorder.finishing)
                            .accessibilityLabel(recorder.recording ? "停止录像" : (starting == nil ? "开始录像" : "取消倒计时"))
                        Button { Task { await recorder.flip() } } label: { Image(systemName: "arrow.triangle.2.circlepath.camera").font(.title2) }
                            .disabled(recorder.recording || recorder.finishing || starting != nil).accessibilityLabel("切换镜头")
                    }.foregroundStyle(.white)
                    HStack {
                        Toggle("语音跟读", isOn: $model.voiceMode).disabled(recorder.recording || starting != nil)
                        Spacer()
                        if let date = recorder.startedAt, recorder.recording {
                            Text(date, style: .timer).monospacedDigit()
                        }
                    }.font(.caption).foregroundStyle(.white)
                    if let url = recorder.lastVideo, !recorder.recording, !recorder.finishing {
                        HStack {
                            Button("保存到相册") { Task { await recorder.saveToPhotos() } }
                            Spacer()
                            ShareLink("分享视频", item: url)
                        }.font(.subheadline).foregroundStyle(.white)
                    }
                }.padding(18).background(.black.opacity(0.7))
            }.background(.black)
        }
        .navigationTitle("拍摄跟读").navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.black, for: .navigationBar).toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $settings) { PromptSettings(camera: true) }
        .task {
            pip.stop(); model.pause(); model.voiceMode = true; model.useCapturedAudio = true
            recorder.onInterruption = { cancelStart(); model.pause() }
            await recorder.prepare(speech: model.speech)
        }
        .onChange(of: phase) { _, value in
            if value == .background { cancelStart(); model.pause(); recorder.close() }
            else if value == .active, !recorder.ready { Task { await recorder.prepare(speech: model.speech) } }
        }
        .onDisappear { cancelStart(); model.pause(); model.useCapturedAudio = false; recorder.close() }
    }

    private func toggleRecording() {
        if recorder.recording { model.pause(); recorder.stop(); return }
        if starting != nil { cancelStart(); return }
        starting = Task {
            if model.voiceMode, !(await model.speech.authorize()) { starting = nil; return }
            for value in stride(from: model.countdown, through: 1, by: -1) {
                guard !Task.isCancelled else { return }
                countdown = value
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
            countdown = nil
            guard !Task.isCancelled else { return }
            if await recorder.start() { model.resumeImmediately() }
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
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(model.sentences.enumerated()), id: \.offset) { index, sentence in
                            Text(sentence.text).font(.system(size: model.fontSize, weight: .semibold)).lineSpacing(6)
                                .foregroundStyle(.white.opacity(index < model.sentenceIndex ? 0.35 : 1))
                                .frame(maxWidth: .infinity, alignment: .leading).id(index)
                        }
                    }.padding(.horizontal, 14).padding(.bottom, 18).scaleEffect(x: model.mirror ? -1 : 1, y: 1)
                }.onChange(of: model.sentenceIndex) { _, index in
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(index, anchor: .top) }
                }
            }
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
    func makeUIView(context: Context) -> CameraPreviewHost {
        let view = CameraPreviewHost()
        view.preview.session = recorder.pipeline.session
        view.onCaptureAngle = { recorder.captureAngle = $0 }
        return view
    }
    func updateUIView(_ uiView: CameraPreviewHost, context: Context) { uiView.configure(device: recorder.device) }
}

final class CameraPreviewHost: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var preview: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    var onCaptureAngle: ((CGFloat) -> Void)?
    private var coordinator: AVCaptureDevice.RotationCoordinator?
    private var observations: [NSKeyValueObservation] = []
    func configure(device: AVCaptureDevice?) {
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
                        connection.automaticallyAdjustsVideoMirroring = false; connection.isVideoMirrored = device.position == .front
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
