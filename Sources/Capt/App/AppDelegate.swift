import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        model.startOverlay()
        Task { await model.loadLocales() }
    }

    // No teardown on terminate: coreaudiod reclaims the tap and aggregate device when the process exits,
    // and blocking the main thread here would deadlock the MainActor session.
}
