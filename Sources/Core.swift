import Foundation
import IOKit

struct Phone: Equatable, Sendable {
    let id: String
    var label: String { "iPhone · \(id.suffix(6))" }
}

func canonicalUDID(_ serial: String) -> String {
    let compact = serial.replacingOccurrences(of: "-", with: "").uppercased()
    if compact.count == 24 {
        return String(compact.prefix(8)) + "-" + String(compact.dropFirst(8))
    }
    return compact
}

func usbPhones() -> [Phone] {
    var iterator: io_iterator_t = 0
    guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOUSBHostDevice"), &iterator) == KERN_SUCCESS else { return [] }
    defer { IOObjectRelease(iterator) }
    var phones: [Phone] = []
    while case let device = IOIteratorNext(iterator), device != 0 {
        defer { IOObjectRelease(device) }
        func property(_ key: String) -> Any? {
            IORegistryEntryCreateCFProperty(device, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
        }
        guard (property("idVendor") as? NSNumber)?.intValue == 1452,
              property("USB Product Name") as? String == "iPhone",
              let serial = property("USB Serial Number") as? String, !serial.isEmpty else { continue }
        phones.append(Phone(id: canonicalUDID(serial)))
    }
    return phones.sorted { $0.id < $1.id }
}

func mayHeartbeat(enabled: Bool, target: String, connected: [Phone], ready: Bool) -> Bool {
    enabled && ready && !target.isEmpty && connected.contains { $0.id == target }
}

struct RunnerOutput {
    private var pending = ""
    mutating func states(in chunk: String) -> [String] {
        pending += chunk.replacingOccurrences(of: "\r", with: "")
        var states: [String] = []
        while let end = pending.firstIndex(of: "\n") {
            let line = String(pending[..<end])
            pending.removeSubrange(...end)
            if let marker = line.range(of: "CHARGEUNLOCK:") {
                states.append(String(line[marker.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        if pending.count > 8192 { pending = String(pending.suffix(8192)) }
        return states
    }
}
