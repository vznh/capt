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

    private enum Edge: String, CaseIterable {
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

    // MARK: - Constants

    private static let indicatorLength: CGFloat = 44
    private static let indicatorThickness: CGFloat = 3
    private static let indicatorInset: CGFloat = 5
    /// Invisible padding around each indicator keeps the short visual bars easy to acquire.
    private static let hitPadding: CGFloat = 12
    private static let idleIndicatorOpacity: Float = 0.42
    private static let hoveredIndicatorOpacity: Float = 0.95
    private static let hoverDuration: TimeInterval = 0.14
    /// Width of the border stroked around the overlay bounds, in points.
    private static let borderWidth: CGFloat = 1
    private static let trackingEdgeKey = "edge"

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
    private var indicatorLayers: [Edge: CALayer] = [:]
    private var edgeTrackingAreas: [NSTrackingArea] = []
    private var cursorTrackingArea: NSTrackingArea?

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
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        for edge in Edge.allCases {
            let indicator = CALayer()
            indicator.backgroundColor = NSColor.white.cgColor
            indicator.opacity = Self.idleIndicatorOpacity
            layer?.addSublayer(indicator)
            indicatorLayers[edge] = indicator
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
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for edge in Edge.allCases {
            let indicator = indicatorLayers[edge]
            indicator?.frame = indicatorRect(for: edge)
            indicator?.cornerRadius = Self.indicatorThickness / 2
        }
        CATransaction.commit()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for trackingArea in edgeTrackingAreas {
            removeTrackingArea(trackingArea)
        }
        if let cursorTrackingArea {
            removeTrackingArea(cursorTrackingArea)
        }

        let edgeOptions: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .activeAlways,
            .enabledDuringMouseDrag,
        ]
        edgeTrackingAreas = Edge.allCases.map { edge in
            let trackingArea = NSTrackingArea(
                rect: hitRect(for: edge),
                options: edgeOptions,
                owner: self,
                userInfo: [Self.trackingEdgeKey: edge.rawValue]
            )
            addTrackingArea(trackingArea)
            return trackingArea
        }

        let cursorArea = NSTrackingArea(
            rect: bounds,
            options: [.cursorUpdate, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(cursorArea)
        cursorTrackingArea = cursorArea
    }

    // MARK: - Drawing

    /// Strokes a dim border. Edge indicators are separate layers so opacity can animate smoothly.
    override func draw(_ dirtyRect: NSRect) {
        let borderRect = bounds.insetBy(dx: Self.borderWidth / 2, dy: Self.borderWidth / 2)
        let border = NSBezierPath(rect: borderRect)
        border.lineWidth = Self.borderWidth
        NSColor.white.withAlphaComponent(0.35).setStroke()
        border.stroke()
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
        indicatorRect(for: edge)
            .insetBy(dx: -Self.hitPadding, dy: -Self.hitPadding)
            .intersection(bounds)
    }

    // MARK: - Hover and cursor feedback

    override func mouseEntered(with event: NSEvent) {
        setHoveredEdge(edge(from: event))
    }

    override func mouseExited(with event: NSEvent) {
        guard hoveredEdge == edge(from: event) else { return }
        setHoveredEdge(nil)
    }

    override func cursorUpdate(with event: NSEvent) {
        if let edge = edge(at: convert(event.locationInWindow, from: nil)) {
            edge.cursor.set()
        } else {
            NSCursor.openHand.set()
        }
    }

    private func edge(from event: NSEvent) -> Edge? {
        guard let rawValue = event.trackingArea?.userInfo?[Self.trackingEdgeKey] as? String else {
            return nil
        }
        return Edge(rawValue: rawValue)
    }

    private func setHoveredEdge(_ edge: Edge?) {
        guard edge != hoveredEdge else { return }
        hoveredEdge = edge
        CATransaction.begin()
        CATransaction.setAnimationDuration(Self.hoverDuration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        for (candidate, indicator) in indicatorLayers {
            indicator.opacity = candidate == edge
                ? Self.hoveredIndicatorOpacity
                : Self.idleIndicatorOpacity
        }
        CATransaction.commit()
    }

    // MARK: - Mouse handling

    override func mouseDown(with event: NSEvent) {
        // Anchor the drag: the location now and the frame as it stands are both frozen until mouse-up.
        hitRegion = region(at: event.locationInWindow)
        startMouseLocation = NSEvent.mouseLocation
        startWindowFrame = windowFrame
        if hitRegion == .interior {
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
        releaseClosedHandCursor()
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil {
            releaseClosedHandCursor()
        }
        super.viewWillMove(toWindow: newWindow)
    }

    /// Which grab region contains `locationInWindow` (converted to screen coordinates).
    private func region(at locationInWindow: NSPoint) -> HitRegion {
        let local = convert(locationInWindow, from: nil)
        return edge(at: local)?.hitRegion ?? .interior
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
