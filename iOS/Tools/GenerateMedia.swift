import Foundation
import AVFoundation
import CoreGraphics
import CoreText
import CoreImage
import AppKit

@main
struct GenerateMedia {
    @MainActor
    static func main() async throws {
        // Render the same symbol/weight as the home screen, then fit its ink to the existing video bounds.
        let symbol = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)!
            .withSymbolConfiguration(.init(pointSize: 408, weight: .semibold))!
        let symbolImage = symbol.cgImage(forProposedRect: nil, context: nil, hints: nil)!
        let width = symbolImage.width, height = symbolImage.height
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let inkBounds: CGRect = rgba.withUnsafeMutableBytes { bytes in
            let context = CGContext(data: bytes.baseAddress, width: width, height: height,
                                    bitsPerComponent: 8, bytesPerRow: width * 4,
                                    space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(symbolImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            var minX = width, minY = height, maxX = -1, maxY = -1
            for y in 0..<height {
                for x in 0..<width where bytes[(y * width + x) * 4 + 3] > 0 {
                    minX = min(minX, x); minY = min(minY, y)
                    maxX = max(maxX, x); maxY = max(maxY, y)
                }
            }
            precondition(maxX >= minX && maxY >= minY, "System lightning must have visible pixels")
            return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        }
        let bolt = symbolImage.cropping(to: inkBounds)!
        // Include the old mitered outline's visible extent, so the rounded replacement does not shrink.
        let boltRect = CGRect(x: 139, y: 69, width: 44, height: 77)
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        try? FileManager.default.removeItem(at: url)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 960, AVVideoHeightKey: 540, AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 6_000_000, AVVideoExpectedSourceFrameRateKey: 60, AVVideoMaxKeyFrameIntervalKey: 60]])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB, kCVPixelBufferWidthKey as String: 960, kCVPixelBufferHeightKey as String: 540, kCVPixelBufferCGImageCompatibilityKey as String: true, kCVPixelBufferCGBitmapContextCompatibilityKey as String: true])
        guard writer.canAdd(input) else { throw NSError(domain: "Media", code: 1) }
        writer.add(input)
        guard writer.startWriting() else { throw writer.error! }
        writer.startSession(atSourceTime: .zero)
        for frame in 0..<360 {
            while !input.isReadyForMoreMediaData {
                guard writer.status == .writing else { throw writer.error ?? NSError(domain: "Media", code: 2) }
                try await Task.sleep(for: .milliseconds(10))
            }
            var pixel: CVPixelBuffer?
            guard let pool = adaptor.pixelBufferPool, CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixel) == kCVReturnSuccess, let pixel else { throw NSError(domain: "Media", code: 3) }
            CVPixelBufferLockBaseAddress(pixel, [])
            let context = CGContext(data: CVPixelBufferGetBaseAddress(pixel), width: 960, height: 540, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixel), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
            context.scaleBy(x: 3, y: 3)
            context.setFillColor(CGColor(red: 0.10, green: 0.065, blue: 0.04, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 320, height: 180))
            let phase = Double(frame % 180) / 180
            let fill = min(1, max(0, (phase - 0.10) / 0.75))
            context.saveGState()
            context.interpolationQuality = .high
            context.clip(to: boltRect, mask: bolt)
            context.setFillColor(CGColor(red: 0.30, green: 0.22, blue: 0.15, alpha: 1))
            context.fill(boltRect)
            let height = boltRect.height * fill
            let edge = boltRect.minY + height
            context.setFillColor(CGColor(red: 1, green: 0.43, blue: 0.05, alpha: 1))
            context.fill(CGRect(x: boltRect.minX, y: boltRect.minY, width: boltRect.width, height: height))
            if fill > 0 && fill < 1 {
                context.setFillColor(CGColor(red: 1, green: 0.77, blue: 0.35, alpha: 1))
                context.fill(CGRect(x: 138, y: edge - 1.5, width: 46, height: 1.5))
            }
            context.restoreGState()
            let text = NSAttributedString(string: "PlugLit", attributes: [NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("HelveticaNeue-Medium" as CFString, 13, nil), NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0.92, alpha: 1)])
            let line = CTLineCreateWithAttributedString(text)
            context.textPosition = CGPoint(x: (320 - CTLineGetTypographicBounds(line, nil, nil, nil)) / 2, y: 16)
            CTLineDraw(line, context)
            CVPixelBufferUnlockBaseAddress(pixel, [])
            guard adaptor.append(pixel, withPresentationTime: CMTime(value: Int64(frame), timescale: 60)) else { throw writer.error ?? NSError(domain: "Media", code: 4) }
        }
        writer.endSession(atSourceTime: CMTime(seconds: 6, preferredTimescale: 600))
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? NSError(domain: "Media", code: 5) }
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard abs(duration.seconds - 6) < 0.1, tracks.count == 1 else { throw NSError(domain: "Media", code: 6) }
        let size = try await tracks[0].load(.naturalSize)
        guard size == CGSize(width: 960, height: 540) else { throw NSError(domain: "Media", code: 11) }
        let frameRate = try await tracks[0].load(.nominalFrameRate)
        guard abs(frameRate - 60) < 0.1 else { throw NSError(domain: "Media", code: 7) }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: tracks[0], outputSettings: nil)
        reader.add(output)
        guard reader.startReading() else { throw reader.error ?? NSError(domain: "Media", code: 8) }
        var count = 0
        var previous = CMTime.invalid
        while let sample = output.copyNextSampleBuffer() {
            let time = CMSampleBufferGetDecodeTimeStamp(sample)
            if time.isValid && previous.isValid {
                guard time > previous else { throw NSError(domain: "Media", code: 9) }
            }
            previous = time
            count += CMSampleBufferGetNumSamples(sample)
        }
        guard reader.status == .completed, count == 360 else {
            throw reader.error ?? NSError(domain: "Media", code: 10, userInfo: [NSLocalizedDescriptionKey: "Expected 360 frames; found \(count), reader status \(reader.status.rawValue)"])
        }
        // Check decoded pixels so an inverted scan cannot pass frame-count validation.
        let generator = AVAssetImageGenerator(asset: asset)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let imageContext = CIContext()
        for (seconds, lowerFilled, upperFilled) in [(0.0, false, false), (1.4, true, false), (2.7, true, true)] {
            let frame = try await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 60)).image
            let image = CIImage(cgImage: frame)
            for (x, y, expected) in [(159.0, 90.0, lowerFilled), (162.0, 126.0, upperFilled)] {
                var pixel = [UInt8](repeating: 0, count: 4)
                imageContext.render(image, toBitmap: &pixel, rowBytes: 4,
                                    bounds: CGRect(x: x * 3, y: y * 3, width: 1, height: 1),
                                    format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
                let filled = pixel[0] > 160 && pixel[1] > 60
                guard filled == expected else { throw NSError(domain: "Media", code: 12, userInfo: [NSLocalizedDescriptionKey: "Incorrect bottom-to-top fill at \(seconds)s, y=\(y)"]) }
            }
            if lowerFilled && upperFilled {
                var pixels = [UInt8](repeating: 0, count: 960 * 540 * 4)
                imageContext.render(image, toBitmap: &pixels, rowBytes: 960 * 4, bounds: image.extent,
                                    format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
                var minX = 960, maxX = -1, minY = 540, maxY = -1
                for index in stride(from: 0, to: pixels.count, by: 4) {
                    let r = Double(pixels[index]), g = Double(pixels[index + 1]), b = Double(pixels[index + 2])
                    if r > 160 && r > g * 1.2 && g > b * 1.2 {
                        let x = index / 4 % 960, y = index / 4 / 960
                        minX = min(minX, x); maxX = max(maxX, x)
                        minY = min(minY, y); maxY = max(maxY, y)
                    }
                }
                // Compare the decoded silhouette with the previous video's visible 131×231 pixel bounds.
                precondition(abs(minX - 418) <= 2 && abs(maxX - minX + 1 - 131) <= 2 && abs(maxY - minY + 1 - 231) <= 2,
                             "Lightning must retain its previous visible size after encoding")
            }
        }
        print("PASS: 6-second silent charging animation, 960×540, 60 fps, 360 encoded frames")
        print("PASS: decoded frames fill the lower lightning first, then the upper lightning")
        print("PASS: rounded system lightning retains the previous visible pixel bounds")
    }
}
