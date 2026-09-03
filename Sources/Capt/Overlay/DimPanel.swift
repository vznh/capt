import AppKit

/// Full-screen dimming layer shown while the user resizes the caption region.
/// Draws black at 50% over the whole screen with an even-odd cutout around `cutout`
/// (a screen-coordinate rect left undimmed; nil dims the whole screen). Setting it redraws.
@MainActor
final class DimPanel: NSPanel {
    /// Screen-coordinate rect left undimmed. Nil dims the whole screen. Setting it redraws.
    var cutout: CGRect? {
        didSet { contentView?.needsDisplay = true }
    }

    /// Called on mouse-up anywhere on the dim layer (the caption box is a separate window
    /// above it, so clicks there never reach this).
    var onClick: (() -> Void)?

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue - 1)
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isExcludedFromWindowsMenu = true

        contentView = DimView(frame: screen.frame, panel: self)
        setFrame(screen.frame, display: true)
    }

    /// Animates alpha from 0 to 1 over 0.15 s.
    func show() {
        alphaValue = 0
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
        })
    }

    /// Animates alpha from 1 to 0 over 0.15 s, then runs `completion`.
    func hide(completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
            self.alphaValue = 1
            completion?()
        })
    }

    /// View that paints the dim layer with an even-odd cutout and forwards mouse-up to `onClick`.
    private final class DimView: NSView {
        // Weak: the panel owns this view through contentView.
        private weak var panel: DimPanel?

        init(frame: NSRect, panel: DimPanel) {
            self.panel = panel
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        override var acceptsFirstResponder: Bool { false }

        override func draw(_ dirtyRect: NSRect) {
            // Black at 50% over the whole bounds, minus the cutout: one path holding the
            // bounds rect plus the cutout rect, filled with the even-odd winding rule so
            // the overlap (the cutout) stays undimmed.
            NSColor.black.withAlphaComponent(0.5).setFill()
            let path = NSBezierPath(rect: bounds)
            path.windingRule = .evenOdd
            if let cutout = panel?.cutout {
                // Convert the screen-coordinate cutout into this view's coordinate system.
                path.append(NSBezierPath(rect: window!.convertFromScreen(cutout)))
            }
            path.fill()
        }

        override func mouseUp(with event: NSEvent) {
            panel?.onClick?()
        }
    }
}
