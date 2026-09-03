import AppKit
import CaptionCore
import SwiftUI

/// Transparent, click-through panel that floats above everything, including fullscreen video.
final class CaptionPanel: NSPanel {
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

    /// Bottom-centered strip, 70% of the screen width.
    func position(on screen: NSScreen? = NSScreen.main) {
        guard let screen else { return }
        let bounds = screen.frame
        let width = min(bounds.width * 0.7, 1200)
        let height: CGFloat = 200
        let origin = NSPoint(x: bounds.midX - width / 2, y: bounds.minY + 48)
        setFrame(NSRect(origin: origin, size: NSSize(width: width, height: height)), display: true)
    }
}
