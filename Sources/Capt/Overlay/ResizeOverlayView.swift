import AppKit

/// Transparent AppKit view laid over the caption panel during resize mode. Draws a subtle border
/// and four edge indicators, and turns mouse drags into a new window frame: edges resize, while the
/// interior moves. Drag math uses screen coordinates so it remains stable as the window moves.
@MainActor
final class ResizeOverlayView: NSView {
    // MARK: - Types

    /// Which part of the overlay a mouse event landed on. Drives both cursor feedback and the per-drag geometry math. Corners are not handles: they fall through to `interior` (move).
    private enum HitRegion {
        case topEdge
        case bottomEdge
        case leftEdge
        case rightEdge
        case interior
    }

    private enum Edge: CaseIterable {
        case top
        case bottom
        case left
        case right

        var hitRegion: HitRegion {
            switch self {
            case .top: .topEdge
            case .bottom: .bottomEdge
            case .left: .leftEdge
            case .right: .rightEdge
            }
        }

        var cursor: NSCursor {
            switch self {
            case .top, .bottom: .resizeUpDown
            case .left, .right: .resizeLeftRight
            }
        }
    }

    /// A real AppKit subview, rather than a layer attached before AppKit creates the parent's
    /// backing layer. This guarantees the handle enters the rendered view hierarchy.
    private final class EdgeIndicatorView: NSView {
        override var isOpaque: Bool {
            false
        }

        override func draw(_ dirtyRect: NSRect) {
            let radius = min(bounds.width, bounds.height) / 2
            let path = NSBezierPath(
                roundedRect: bounds,
                xRadius: radius,
                yRadius: radius
            )

            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.8)
            shadow.shadowBlurRadius = 1.5
            shadow.shadowOffset = .zero
            shadow.set()
            NSColor.white.setFill()
            path.fill()
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    // MARK: - Constants

    private static let indicatorLength: CGFloat = 96
    private static let indicatorThickness: CGFloat = 1.5
    /// Keeps each thinner indicator centered at the same distance from its edge as before.
    private static let indicatorInset: CGFloat = 6.75
    /// Preserves the previous 100 × 41 point acquisition area independently of visual size.
    private static let hitLength: CGFloat = 100
    private static let hitThickness: CGFloat = 41
    private static let idleIndicatorOpacity: CGFloat = 0.82
    private static let dimmedIndicatorOpacity: CGFloat = 0.56
    private static let hoveredIndicatorOpacity: CGFloat = 1
    private static let draggedIndicatorOpacity: CGFloat = 1
    private static let hoverDuration: TimeInterval = 0.14
    /// Width of the border stroked around the overlay bounds, in points.
    private static let borderWidth: CGFloat = 1

    // MARK: - Configuration

    /// Current frame of the owning window in screen coordinates. The controller sets this before showing the view and after applying each change.
    var windowFrame: CGRect = .zero

    /// Screen region the caption window must remain inside.
    var allowedFrame: CGRect = .zero

    /// Smallest allowed caption-window size.
    var minimumSize: CGSize = .zero

    /// Called with the clamped frame on every drag step. The controller applies it to the window and sets `windowFrame`.
    var onFrameChange: ((CGRect) -> Void)?

    // MARK: - Drag state

    /// Region grabbed at mouse-down; constant for the whole drag so the resize semantics never change mid-gesture.
    private var hitRegion: HitRegion = .interior
    /// Mouse location in screen coordinates at mouse-down.
    private var startMouseLocation: CGPoint = .zero
    /// `windowFrame` captured at mouse-down. Every drag step recomputes from this anchor, never from the previous step's result, so a clamped frame cannot make the box jitter.
    private var startWindowFrame: CGRect = .zero
    private var closedHandCursorIsPushed = false
    private var hoveredEdge: Edge?
    private var draggedEdge: Edge?
    private var indicatorViews: [Edge: EdgeIndicatorView] = [:]
    private var pointerTrackingArea: NSTrackingArea?

    // MARK: - Setup

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        for edge in Edge.allCases {
            let indicator = EdgeIndicatorView(frame: .zero)
            indicator.alphaValue = Self.idleIndicatorOpacity
            addSubview(indicator)
            indicatorViews[edge] = indicator
        }
    }

    /// `isFlipped` is false: AppKit's default bottom-left origin, matching screen coordinates.
    override var isFlipped: Bool {
        false
    }

    /// The first click on a non-key window starts the drag instead of just activating the window.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    /// The whole bounds are interactive; subviews would steal clicks.
    override func hitTest(_ point: NSPoint) -> NSView? {
        self
    }

    override func layout() {
        super.layout()
        for edge in Edge.allCases {
            indicatorViews[edge]?.frame = indicatorRect(for: edge)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let pointerTrackingArea {
            removeTrackingArea(pointerTrackingArea)
        }
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [
                .mouseEnteredAndExited,
                .mouseMoved,
                .activeAlways,
                .enabledDuringMouseDrag,
                .inVisibleRect,
            ],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        pointerTrackingArea = trackingArea
    }

    // MARK: - Drawing

    /// Strokes a dual-contrast border. Edge indicators are separate layers so opacity can animate smoothly.
    override func draw(_ dirtyRect: NSRect) {
        let outerRect = bounds.insetBy(dx: 1.5, dy: 1.5)
        let outerBorder = NSBezierPath(rect: outerRect)
        outerBorder.lineWidth = 3
        NSColor.black.withAlphaComponent(0.28).setStroke()
        outerBorder.stroke()

        let innerRect = bounds.insetBy(dx: Self.borderWidth / 2, dy: Self.borderWidth / 2)
        let innerBorder = NSBezierPath(rect: innerRect)
        innerBorder.lineWidth = Self.borderWidth
        NSColor.white.withAlphaComponent(0.72).setStroke()
        innerBorder.stroke()
    }

    private func indicatorRect(for edge: Edge) -> NSRect {
        let length = Self.indicatorLength
        let thickness = Self.indicatorThickness
        let inset = Self.indicatorInset
        switch edge {
        case .top:
            return NSRect(x: bounds.midX - length / 2, y: bounds.maxY - inset - thickness,
                          width: length, height: thickness)
        case .bottom:
            return NSRect(x: bounds.midX - length / 2, y: bounds.minY + inset,
                          width: length, height: thickness)
        case .left:
            return NSRect(x: bounds.minX + inset, y: bounds.midY - length / 2,
                          width: thickness, height: length)
        case .right:
            return NSRect(x: bounds.maxX - inset - thickness, y: bounds.midY - length / 2,
                          width: thickness, height: length)
        }
    }

    private func hitRect(for edge: Edge) -> NSRect {
        let indicator = indicatorRect(for: edge)
        let rect = switch edge {
        case .top, .bottom:
            NSRect(
                x: indicator.midX - Self.hitLength / 2,
                y: indicator.midY - Self.hitThickness / 2,
                width: Self.hitLength,
                height: Self.hitThickness
            )
        case .left, .right:
            NSRect(
                x: indicator.midX - Self.hitThickness / 2,
                y: indicator.midY - Self.hitLength / 2,
                width: Self.hitThickness,
                height: Self.hitLength
            )
        }
        return rect.intersection(bounds)
    }

    // MARK: - Hover and cursor feedback

    override func mouseEntered(with event: NSEvent) {
        updatePointerFeedback(at: event.locationInWindow)
    }

    override func mouseMoved(with event: NSEvent) {
        updatePointerFeedback(at: event.locationInWindow)
    }

    override func mouseExited(with event: NSEvent) {
        setHoveredEdge(nil)
        if let draggedEdge {
            draggedEdge.cursor.set()
        } else {
            NSCursor.arrow.set()
        }
    }

    private func updatePointerFeedback(at locationInWindow: NSPoint) {
        let local = convert(locationInWindow, from: nil)
        let edge = edge(at: local)
        setHoveredEdge(edge)
        if let activeEdge = draggedEdge ?? edge {
            activeEdge.cursor.set()
        } else {
            NSCursor.openHand.set()
        }
    }

    private func setHoveredEdge(_ edge: Edge?) {
        guard edge != hoveredEdge else { return }
        hoveredEdge = edge
        updateIndicatorOpacities(animated: true)
    }

    private func updateIndicatorOpacities(animated: Bool) {
        let changes = {
            for (edge, indicator) in self.indicatorViews {
                let opacity: CGFloat = if edge == self.draggedEdge {
                    Self.draggedIndicatorOpacity
                } else if edge == self.hoveredEdge {
                    Self.hoveredIndicatorOpacity
                } else if self.draggedEdge != nil || self.hoveredEdge != nil {
                    Self.dimmedIndicatorOpacity
                } else {
                    Self.idleIndicatorOpacity
                }
                indicator.animator().alphaValue = opacity
            }
        }

        guard animated else {
            NSAnimationContext.beginGrouping()
            NSAnimationContext.current.duration = 0
            changes()
            NSAnimationContext.endGrouping()
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.hoverDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            changes()
        }
    }

    // MARK: - Mouse handling

    override func mouseDown(with event: NSEvent) {
        // Anchor the drag: the location now and the frame as it stands are both frozen until mouse-up.
        let local = convert(event.locationInWindow, from: nil)
        draggedEdge = edge(at: local)
        hitRegion = draggedEdge?.hitRegion ?? .interior
        startMouseLocation = NSEvent.mouseLocation
        startWindowFrame = windowFrame
        updateIndicatorOpacities(animated: true)
        if let draggedEdge {
            draggedEdge.cursor.set()
        } else {
            NSCursor.closedHand.push()
            closedHandCursorIsPushed = true
        }
    }

    override func mouseDragged(with event: NSEvent) {
        // Delta from the mouse-down anchor, in screen coordinates.
        let current = NSEvent.mouseLocation
        let dx = current.x - startMouseLocation.x
        let dy = current.y - startMouseLocation.y

        let proposed = constrainedFrame(
            from: startWindowFrame,
            delta: CGPoint(x: dx, y: dy)
        )
        if proposed != windowFrame {
            onFrameChange?(proposed)
        }
    }

    override func mouseUp(with event: NSEvent) {
        draggedEdge = nil
        updateIndicatorOpacities(animated: true)
        releaseClosedHandCursor()
        updatePointerFeedback(at: event.locationInWindow)
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil {
            draggedEdge = nil
            updateIndicatorOpacities(animated: false)
            releaseClosedHandCursor()
        }
        super.viewWillMove(toWindow: newWindow)
    }

    private func edge(at point: NSPoint) -> Edge? {
        Edge.allCases.first { hitRect(for: $0).contains(point) }
    }

    /// Builds a frame from the drag anchor while keeping the opposite edge fixed and the result
    /// fully inside `allowedFrame`.
    private func constrainedFrame(from anchor: CGRect, delta: CGPoint) -> CGRect {
        var frame = anchor
        let minimumWidth = min(minimumSize.width, allowedFrame.width)
        let minimumHeight = min(minimumSize.height, allowedFrame.height)

        switch hitRegion {
        case .interior:
            frame.origin.x = clamp(
                anchor.origin.x + delta.x,
                from: allowedFrame.minX,
                through: allowedFrame.maxX - anchor.width
            )
            frame.origin.y = clamp(
                anchor.origin.y + delta.y,
                from: allowedFrame.minY,
                through: allowedFrame.maxY - anchor.height
            )

        case .topEdge:
            let top = clamp(
                anchor.maxY + delta.y,
                from: anchor.minY + minimumHeight,
                through: allowedFrame.maxY
            )
            frame.size.height = top - anchor.minY

        case .bottomEdge:
            let bottom = clamp(
                anchor.minY + delta.y,
                from: allowedFrame.minY,
                through: anchor.maxY - minimumHeight
            )
            frame.origin.y = bottom
            frame.size.height = anchor.maxY - bottom

        case .leftEdge:
            let left = clamp(
                anchor.minX + delta.x,
                from: allowedFrame.minX,
                through: anchor.maxX - minimumWidth
            )
            frame.origin.x = left
            frame.size.width = anchor.maxX - left

        case .rightEdge:
            let right = clamp(
                anchor.maxX + delta.x,
                from: anchor.minX + minimumWidth,
                through: allowedFrame.maxX
            )
            frame.size.width = right - anchor.minX
        }

        return frame
    }

    private func clamp(_ value: CGFloat, from lowerBound: CGFloat, through upperBound: CGFloat) -> CGFloat {
        min(max(value, lowerBound), upperBound)
    }

    private func releaseClosedHandCursor() {
        guard closedHandCursorIsPushed else { return }
        NSCursor.pop()
        closedHandCursorIsPushed = false
    }
}
