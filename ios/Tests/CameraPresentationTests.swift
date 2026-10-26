import XCTest
import UIKit
@testable import JianzhouPrompter

final class CameraPresentationTests: XCTestCase {
    func testRecordedMirrorFlipsDisplayedHorizontalAxisAndKeepsBounds() {
        let size = CGSize(width: 1920, height: 1080)
        for angle: CGFloat in [0, 90, 180, 270] {
            let regular = CameraVideoTransform.make(size: size, angle: angle, mirrored: false)
            let mirrored = CameraVideoTransform.make(size: size, angle: angle, mirrored: true)
            let normalBounds = CGRect(origin: .zero, size: size).applying(regular)
            let mirrorBounds = CGRect(origin: .zero, size: size).applying(mirrored)
            XCTAssertEqual(normalBounds.width, mirrorBounds.width, accuracy: 0.001)
            XCTAssertEqual(normalBounds.height, mirrorBounds.height, accuracy: 0.001)
            XCTAssertEqual(mirrorBounds.minX, 0, accuracy: 0.001)
            XCTAssertEqual(mirrorBounds.minY, 0, accuracy: 0.001)
            let point = CGPoint(x: 300, y: 200)
            let first = point.applying(regular), second = point.applying(mirrored)
            XCTAssertEqual(first.x + second.x, normalBounds.width, accuracy: 0.001)
            XCTAssertEqual(first.y, second.y, accuracy: 0.001)
        }
    }

    @MainActor func testLongSentenceScrollsByVisualLineWhileSentenceStaysTheSame() {
        let storage = NSTextStorage(), layout = NSLayoutManager()
        storage.addLayoutManager(layout)
        let container = NSTextContainer(size: CGSize(width: 0, height: .greatestFiniteMagnitude))
        layout.addTextContainer(container)
        let view = PromptTrackingTextView(frame: CGRect(x: 0, y: 0, width: 290, height: 150), textContainer: container)
        view.textContainer.widthTracksTextView = true
        let script = String(repeating: "我想把这段长口播讲得更加自然流畅", count: 20)
        view.apply(text: script, sourceOffset: 0, fontSize: 32)
        view.layoutIfNeeded()
        view.apply(text: script, sourceOffset: 100, fontSize: 32)
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        XCTAssertGreaterThan(view.contentOffset.y, 50)
    }
}
