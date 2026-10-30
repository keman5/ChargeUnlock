import CoreImage
import CoreText
import os

// The video compositor reads immutable images off-main; battery updates replace them under the lock.
final class BatteryOverlay: Sendable {
    private let image = OSAllocatedUnfairLock<CIImage?>(initialState: nil)

    func update(caption: String) {
        guard let context = CGContext(data: nil, width: 960, height: 540, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        context.scaleBy(x: 3, y: 3)
        let text = NSAttributedString(string: caption, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("HelveticaNeue-Medium" as CFString, 22, nil),
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 1, alpha: 1)
        ])
        let line = CTLineCreateWithAttributedString(text)
        context.textPosition = CGPoint(x: (320 - CTLineGetTypographicBounds(line, nil, nil, nil)) / 2, y: 39)
        CTLineDraw(line, context)
        guard let cgImage = context.makeImage() else { return }
        let rendered = CIImage(cgImage: cgImage)
        image.withLock { $0 = rendered }
    }

    func composite(over source: CIImage) -> CIImage {
        guard let overlay = image.withLock({ $0 }) else { return source }
        return overlay.composited(over: source).cropped(to: source.extent)
    }
}
