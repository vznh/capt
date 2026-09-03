import AppKit
import CoreFoundation

/// Stable identity for a display, so caption frames persist per monitor across reboots and cable swaps.
struct DisplayID: Hashable, Codable, Sendable { let uuid: String }

extension NSScreen {
    /// Hardware UUID via CGDisplayCreateUUIDFromDisplayID on the NSScreenNumber in deviceDescription.
    /// Nil if unavailable (no screen number, or CoreGraphics could not produce a UUID).
    var displayID: DisplayID? {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return nil
        }
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(number)?.takeRetainedValue() else { return nil }
        return DisplayID(uuid: CFUUIDCreateString(nil, uuid) as String)
    }
}
