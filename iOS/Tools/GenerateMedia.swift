import Foundation
import AVFoundation
import CoreGraphics
import CoreText

@main
struct GenerateMedia {
    static func main() async throws {
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        try? FileManager.default.removeItem(at: url)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 320, AVVideoHeightKey: 180, AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 48_000, AVVideoMaxKeyFrameIntervalKey: 10]])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB, kCVPixelBufferWidthKey as String: 320, kCVPixelBufferHeightKey as String: 180, kCVPixelBufferCGImageCompatibilityKey as String: true, kCVPixelBufferCGBitmapContextCompatibilityKey as String: true])
        guard writer.canAdd(input) else { throw NSError(domain: "Media", code: 1) }
        writer.add(input)
        guard writer.startWriting() else { throw writer.error! }
        writer.startSession(atSourceTime: .zero)
        for frame in 0..<30 {
            while !input.isReadyForMoreMediaData {
                guard writer.status == .writing else { throw writer.error ?? NSError(domain: "Media", code: 2) }
                try await Task.sleep(for: .milliseconds(10))
            }
            var pixel: CVPixelBuffer?
            guard let pool = adaptor.pixelBufferPool, CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixel) == kCVReturnSuccess, let pixel else { throw NSError(domain: "Media", code: 3) }
            CVPixelBufferLockBaseAddress(pixel, [])
            let context = CGContext(data: CVPixelBufferGetBaseAddress(pixel), width: 320, height: 180, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixel), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
            context.setFillColor(CGColor(red: 0.055, green: 0.075, blue: 0.10, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 320, height: 180))
            context.setFillColor(CGColor(red: 0.25, green: 0.85, blue: 0.60, alpha: 0.7 + 0.3 * sin(Double(frame) * .pi / 15)))
            context.move(to: CGPoint(x: 169, y: 142)); context.addLine(to: CGPoint(x: 141, y: 101)); context.addLine(to: CGPoint(x: 159, y: 101)); context.addLine(to: CGPoint(x: 150, y: 74)); context.addLine(to: CGPoint(x: 181, y: 115)); context.addLine(to: CGPoint(x: 162, y: 115)); context.closePath(); context.fillPath()
            let text = NSAttributedString(string: "CHARGEUNLOCK", attributes: [NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("HelveticaNeue-Medium" as CFString, 17, nil), NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0.92, alpha: 1)])
            let line = CTLineCreateWithAttributedString(text)
            context.textPosition = CGPoint(x: (320 - CTLineGetTypographicBounds(line, nil, nil, nil)) / 2, y: 43)
            CTLineDraw(line, context)
            CVPixelBufferUnlockBaseAddress(pixel, [])
            guard adaptor.append(pixel, withPresentationTime: CMTime(value: Int64(frame), timescale: 5)) else { throw writer.error ?? NSError(domain: "Media", code: 4) }
        }
        writer.endSession(atSourceTime: CMTime(seconds: 6, preferredTimescale: 600))
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? NSError(domain: "Media", code: 5) }
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard abs(duration.seconds - 6) < 0.1, tracks.count == 1 else { throw NSError(domain: "Media", code: 6) }
        print("Generated and validated 6-second local silent video")
    }
}
