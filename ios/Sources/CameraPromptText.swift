import SwiftUI
import UIKit

/// Tracks wrapped visual lines, rather than waiting for a whole sentence to end.
struct CameraPromptText: UIViewRepresentable {
    let text: String
    let sourceOffset: Int
    let fontSize: Double

    func makeUIView(context: Context) -> PromptTrackingTextView {
        let storage = NSTextStorage()
        let layout = NSLayoutManager(); storage.addLayoutManager(layout)
        let container = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude)); layout.addTextContainer(container)
        let view = PromptTrackingTextView(frame: .zero, textContainer: container)
        view.isEditable = false; view.isSelectable = false
        view.backgroundColor = UIColor.clear; view.showsVerticalScrollIndicator = false
        view.textContainer.widthTracksTextView = true
        view.textContainer.lineFragmentPadding = 0
        view.accessibilityLabel = "拍摄提词正文"
        return view
    }

    func updateUIView(_ view: PromptTrackingTextView, context: Context) {
        view.apply(text: text, sourceOffset: sourceOffset, fontSize: fontSize)
    }
}

final class PromptTrackingTextView: UITextView {
    private var cursor = 0
    private var appliedFont: Double = 0
    private var lastSize = CGSize.zero

    func apply(text: String, sourceOffset: Int, fontSize: Double) {
        let contentChanged = self.text != text || appliedFont != fontSize
        if contentChanged {
            let paragraph = NSMutableParagraphStyle(); paragraph.lineSpacing = 6
            textStorage.setAttributedString(NSAttributedString(string: text, attributes: [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
                .foregroundColor: UIColor.white, .paragraphStyle: paragraph,
            ]))
            appliedFont = fontSize
        }
        if contentChanged || cursor != sourceOffset {
            cursor = sourceOffset
            track(animated: !contentChanged)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if lastSize != bounds.size {
            lastSize = bounds.size
            textContainerInset = UIEdgeInsets(top: 4, left: 14, bottom: max(30, bounds.height * 0.7), right: 14)
            track(animated: false)
        }
    }

    private func track(animated: Bool) {
        guard textStorage.length > 0, bounds.width > 0 else { return }
        let width = max(1, bounds.width - textContainerInset.left - textContainerInset.right)
        if abs(textContainer.size.width - width) > 1 {
            textContainer.size = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        }
        layoutManager.ensureLayout(for: textContainer)
        guard layoutManager.numberOfGlyphs > 0 else { return }
        let character = min(max(0, cursor), textStorage.length - 1)
        let glyph = layoutManager.glyphIndexForCharacter(at: character)
        var glyphRange = NSRange()
        let line = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: &glyphRange)
        let lineCharacters = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        textStorage.beginEditing()
        textStorage.addAttribute(.foregroundColor, value: UIColor.white, range: NSRange(location: 0, length: textStorage.length))
        if lineCharacters.location > 0 {
            textStorage.addAttribute(.foregroundColor, value: UIColor.white.withAlphaComponent(0.35), range: NSRange(location: 0, length: lineCharacters.location))
        }
        textStorage.endEditing()
        guard !isDragging, !isDecelerating else { return }
        let target = max(0, min(line.minY + textContainerInset.top - bounds.height * 0.16, contentSize.height - bounds.height))
        if abs(contentOffset.y - target) > 2 {
            setContentOffset(CGPoint(x: 0, y: target), animated: animated && !UIAccessibility.isReduceMotionEnabled)
        }
    }
}
