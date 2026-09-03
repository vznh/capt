import AppKit
import CaptionCore
import SwiftUI

/// Transparent, click-through panel that floats above everything, including fullscreen video.
/// One exists per display; `OverlayController` positions it from the layout store. During resize
/// mode it becomes interactive and hosts a `ResizeOverlayView` on top of the captions.
final class CaptionPanel: NSPanel {
    private var resizeOverlay: NSView?

    init(store: CaptionStore, settings: SettingsStore) {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isExcludedFromWindowsMenu = true

        let host = NSHostingView(rootView: CaptionView(store: store, settings: settings))
        host.wantsLayer = true
        host.layer?.backgroundColor = .clear
        contentView = host
    }

    /// Interactive panels accept mouse events; otherwise clicks fall through to whatever is beneath.
    func setInteractive(_ interactive: Bool) {
        ignoresMouseEvents = !interactive
    }

    /// Lays `view` over the captions, filling the panel and tracking its size.
    func showResizeOverlay(_ view: NSView) {
        hideResizeOverlay()
        guard let contentView else { return }
        view.frame = contentView.bounds
        view.autoresizingMask = [.width, .height]
        contentView.addSubview(view, positioned: .above, relativeTo: nil)
        resizeOverlay = view
    }

    func hideResizeOverlay() {
        resizeOverlay?.removeFromSuperview()
        resizeOverlay = nil
    }
}
