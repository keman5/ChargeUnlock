import Foundation

enum BatteryReading {
    static func percentageText(_ level: Float) -> String {
        guard level.isFinite, (0...1).contains(level) else { return "电量未知" }
        return "\(Int((level * 100).rounded()))%"
    }
}

struct ChargingPolicy {
    private(set) var requested = false
    private(set) var stopping = false
    mutating func start(powered: Bool) -> Bool {
        guard !stopping else { return false }
        requested = powered
        return requested
    }
    mutating func updatePower(_ powered: Bool) -> Bool {
        if !powered { requested = false }
        return requested
    }
    mutating func stop(pictureInPicturePending: Bool = false) {
        requested = false
        stopping = pictureInPicturePending
    }
    mutating func didStopPictureInPicture() { stopping = false }
}
