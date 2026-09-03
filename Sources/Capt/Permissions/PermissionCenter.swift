import AppKit
import CaptionCore

/// macOS has no public API to query the system-audio-capture (process tap) permission.
/// The tap simply returns silence when denied, so `SilenceWatchdog` is the detector and
/// this type just deep-links to the right Settings pane.
enum PermissionCenter {
    static func openSystemAudioRecordingSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AudioCapture") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
