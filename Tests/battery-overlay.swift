import Foundation
import CoreImage

@main
struct BatteryOverlayCheck {
    static func main() {
        let overlay = BatteryOverlay()
        let bounds = CGRect(x: 0, y: 0, width: 960, height: 540)
        let source = CIImage(color: .black).cropped(to: bounds)
        let context = CIContext(options: [.useSoftwareRenderer: true])
        func pixels() -> Data {
            let image = context.createCGImage(overlay.composite(over: source), from: bounds)!
            assert(image.width == 960 && image.height == 540)
            return image.dataProvider!.data! as Data
        }
        let empty = pixels()
        overlay.update(caption: "正在充电 · 57%")
        let charging = pixels()
        assert(charging != empty, "Battery caption must be visible in the video frame")
        overlay.update(caption: "电量已满 · 100%")
        assert(pixels() != charging, "Battery changes must replace the caption without restarting playback")
        print("PASS: battery overlay draws and updates in a 960×540 video frame")
    }
}
