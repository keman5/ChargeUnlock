import Foundation

@main
struct PolicyCheck {
    static func main() {
        var policy = ChargingPolicy()
        assert(!policy.start(powered: false))
        assert(policy.start(powered: true))
        assert(policy.start(powered: true))
        assert(policy.updatePower(true))
        assert(!policy.updatePower(false))
        assert(!policy.updatePower(true)) // Replug requires a new start automation, not a stale request.
        assert(policy.start(powered: true))
        policy.stop()
        assert(!policy.requested)
        assert(!policy.updatePower(true))
        assert(policy.start(powered: true))
        policy.stop(pictureInPicturePending: true)
        assert(!policy.requested && policy.stopping)
        assert(!policy.start(powered: true)) // A replug cannot restart during asynchronous PiP dismissal.
        policy.stop(pictureInPicturePending: true)
        assert(policy.stopping) // Repeated stop requests must not release the closing session.
        policy.didStopPictureInPicture()
        assert(!policy.requested && !policy.stopping)
        assert(!policy.updatePower(true))
        assert(policy.start(powered: true))
        policy.stop()
        assert(!policy.stopping && !policy.requested)
        print("PASS: iOS charging-only start, idempotence, unplug, explicit stop, no stale restart")
    }
}
