import AppKit
import CaptionCore

/// Owns the single caption panel and keeps it on the main display, at the frame the layout store
/// holds for that display. Re-evaluates when displays are added, removed, or rearranged.
@MainActor
final class OverlayController {
    let panel: CaptionPanel
    let layout: CaptionLayoutStore
    /// The display currently hosting the panel.
    private(set) var screen: NSScreen?

    private var observer: NSObjectProtocol?

    init(store: CaptionStore, settings: SettingsStore, layout: CaptionLayoutStore) {
        self.layout = layout
        panel = CaptionPanel(store: store, settings: settings)
    }

    /// Shows the panel on the main display and starts tracking display changes.
    func start() {
        syncScreen()
        panel.orderFrontRegardless()
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.syncScreen() }
        }
    }

    /// Moves the panel to the stored frame for its display.
    func applyLayout() {
        guard let screen else { return }
        panel.setFrame(layout.frame(for: screen), display: true)
    }

    /// Picks the main display. NSScreen.main follows the key window, which never exists for
    /// this accessory app, so it always resolves to the primary display with the menu bar.
    private func syncScreen() {
        screen = NSScreen.main ?? NSScreen.screens.first
        applyLayout()
    }
}
