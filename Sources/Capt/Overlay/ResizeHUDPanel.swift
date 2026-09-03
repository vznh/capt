import AppKit
import SwiftUI

/// Small floating toolbar shown near the caption box during resize mode: Reset, Cancel, Done.
@MainActor
final class ResizeHUDPanel: NSPanel {
    init(onReset: @escaping () -> Void, onCancel: @escaping () -> Void, onDone: @escaping () -> Void) {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isExcludedFromWindowsMenu = true
        becomesKeyOnlyIfNeeded = true

        let hud = ResizeHUDView(
            onReset: onReset,
            onCancel: onCancel,
            onDone: onDone
        )
        let host = NSHostingView(rootView: hud)
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        contentView = host
        setContentSize(host.fittingSize)
    }

    /// Allows controls that genuinely need keyboard input to request it without taking key status
    /// merely because the panel was clicked.
    override var canBecomeKey: Bool {
        true
    }

    /// Places the HUD centered horizontally above `rect` with 12 pt gap; if that would leave
    /// the screen's visibleFrame, place it below the rect instead; if still outside, clamp inside.
    func position(above rect: CGRect, on screen: NSScreen) {
        let frame = frame // current size from fittingSize
        let screenFrame = screen.visibleFrame

        var origin = NSPoint(
            x: rect.midX - frame.width / 2,
            y: rect.maxY + 12
        )

        // Above would leave the visible frame: fall back to below, then clamp so a
        // box near the screen's bottom edge cannot push the HUD off-screen either.
        if origin.y + frame.height > screenFrame.maxY {
            origin.y = rect.minY - 12 - frame.height
            origin.y = min(max(origin.y, screenFrame.minY), screenFrame.maxY - frame.height)
        }

        // Still outside (rect nearly fills the screen): clamp inside.
        origin.x = min(max(origin.x, screenFrame.minX), screenFrame.maxX - frame.width)
        origin.y = min(max(origin.y, screenFrame.minY), screenFrame.maxY - frame.height)

        setFrameOrigin(origin)
    }
}

/// SwiftUI content of the HUD: three actions in a material-backed rounded bar.
private struct ResizeHUDView: View {
    let onReset: () -> Void
    let onCancel: () -> Void
    let onDone: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button("Reset", action: onReset)
                .buttonStyle(.borderedProminent)
                .tint(.red)
            Button("Cancel", action: onCancel)
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
            Button("Done", action: onDone)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .font(.system(size: 13))
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
