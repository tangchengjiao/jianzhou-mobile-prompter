import AVKit
import SwiftUI

struct RecordedVideo: Identifiable {
    let url: URL
    var id: String { url.path }
}

struct VideoReview: View {
    let clip: RecordedVideo
    @ObservedObject var recorder: CameraRecorder
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer

    init(clip: RecordedVideo, recorder: CameraRecorder) {
        self.clip = clip; self.recorder = recorder
        _player = State(initialValue: AVPlayer(url: clip.url))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VideoPlayer(player: player).background(.black).accessibilityLabel("刚拍摄的视频")
                Text(recorder.status).font(.footnote).foregroundStyle(.secondary).padding(.horizontal)
                HStack {
                    Button("重拍") { dismiss() }
                    Spacer()
                    Button("保存到相册") { Task { await recorder.saveToPhotos() } }
                    Spacer()
                    ShareLink("分享视频", item: clip.url)
                }.padding(.horizontal, 22).padding(.bottom, 18)
            }.navigationTitle("拍摄预览").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("完成") { dismiss() } }
                .onAppear {
                    try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
                    try? AVAudioSession.sharedInstance().setActive(true)
                    player.play()
                }
                .onDisappear {
                    player.pause()
                    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                }
        }.tint(Brand.purple)
    }
}
