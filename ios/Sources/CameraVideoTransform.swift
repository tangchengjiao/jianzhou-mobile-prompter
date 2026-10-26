import CoreGraphics

enum CameraVideoTransform {
    /// Mirror in the displayed video's horizontal direction after rotation.
    static func make(size: CGSize, angle: CGFloat, mirrored: Bool) -> CGAffineTransform {
        var transform = CGAffineTransform(rotationAngle: angle * .pi / 180)
        if mirrored { transform = transform.concatenating(CGAffineTransform(scaleX: -1, y: 1)) }
        let bounds = CGRect(origin: .zero, size: size).applying(transform)
        return transform.concatenating(CGAffineTransform(translationX: -bounds.minX, y: -bounds.minY))
    }
}
