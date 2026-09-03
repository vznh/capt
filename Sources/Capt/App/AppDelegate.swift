import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var panel: CaptionPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let panel = CaptionPanel(store: model.store, settings: model.settings)
        panel.position()
        panel.orderFrontRegardless()
        self.panel = panel

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak panel] _ in
            panel?.position()
        }

        Task { await model.loadLocales() }
    }

    // No teardown on terminate: coreaudiod reclaims the tap and aggregate device when the process exits,
    // and blocking the main thread here would deadlock the MainActor session.
}
