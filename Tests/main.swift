import Foundation

assert(canonicalUDID("00008101000960C2010A0000") == "00008101-000960C2010A0000")
assert(canonicalUDID("00008101-000960c2010a0000") == "00008101-000960C2010A0000")
let target = "test-phone"
let phones = [Phone(id: target)]
assert(mayHeartbeat(enabled: true, target: target, connected: phones, ready: true))
assert(!mayHeartbeat(enabled: false, target: target, connected: phones, ready: true))
assert(!mayHeartbeat(enabled: true, target: target, connected: [], ready: true))
assert(!mayHeartbeat(enabled: true, target: "other", connected: phones, ready: true))
assert(!mayHeartbeat(enabled: true, target: target, connected: phones, ready: false))
assert(!mayHeartbeat(enabled: true, target: "", connected: phones, ready: true))
print("PASS: USB-only target selection, disabled/not-ready guards, UDID normalization")
var output = RunnerOutput()
assert(output.states(in: "test log\r\nCHARGEUNLOCK:rea").isEmpty)
assert(output.states(in: "dy\r\nCHARGEUNLOCK:awake\r") == ["ready"])
assert(output.states(in: "\nCHARGEUNLOCK:locked\n") == ["awake", "locked"])
assert(output.states(in: "ordinary output\n").isEmpty)
print("PASS: chunked XCTest output with CRLF and LF")
