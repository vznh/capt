import AppKit

/// Transparent AppKit view laid over the caption panel during resize mode. Draws a border and four edge-midpoint handles, and turns mouse drags into a new window frame: edges resize, the interior moves. All math is done in screen coordinates using `NSEvent.mouseLocation` so it stays correct while the window itself moves under the cursor.
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

    // MARK: - Constants

    /// Square side length of the drawn (and hit-tested) edge handles, in points.
    private static let handleSize: CGFloat = 10
    /// Extra distance beyond a handle's visual bounds that still counts as a hit, in points.
    private static let hitTolerance: CGFloat = 8
    /// Width of the border stroked around the overlay bounds, in points.
    private static let borderWidth: CGFloat = 1.5

    // MARK: - Configuration

    /// Current frame of the owning window in screen coordinates. The controller sets this before showing the view and after applying each change.
    var windowFrame: CGRect = .zero {
        didSet {
            // The overlay's own geometry is unchanged; only the tracked window moved.
            needsDisplay = true
        }
    }

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
        // Transparent by default; the border and handles are the only visible parts.
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
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

    // MARK: - Drawing

    /// Strokes the border and the four edge-midpoint handles. There are no corner handles.
    override func draw(_ dirtyRect: NSRect) {
        // 1.5 pt white border around the bounds.
        let borderRect = bounds.insetBy(dx: Self.borderWidth / 2, dy: Self.borderWidth / 2)
        let border = NSBezierPath(rect: borderRect)
        border.lineWidth = Self.borderWidth
        NSColor.white.setStroke()
        border.stroke()

        // Four edge-midpoint handles: top, bottom, left, right. White with a 1 pt black outline.
        for handleRect in handleRects(in: bounds) {
            let path = NSBezierPath(rect: handleRect)
            path.lineWidth = 1
            NSColor.black.setStroke()
            path.stroke()
            NSColor.white.setFill()
            path.fill()
        }
    }

    /// Handle rects centered on the bounds' edge midpoints. Corners are deliberately excluded.
    private func handleRects(in rect: NSRect) -> [NSRect] {
        let s = Self.handleSize
        let midX = NSMidX(rect)
        let midY = NSMidY(rect)
        let minX = rect.minX
        let maxX = rect.maxX
        let minY = rect.minY
        let maxY = rect.maxY

        func centered(_ x: CGFloat, _ y: CGFloat) -> NSRect {
            NSRect(x: x - s / 2, y: y - s / 2, width: s, height: s)
        }

        return [
            centered(midX, maxY), // top
            centered(midX, minY), // bottom
            centered(minX, midY), // left
            centered(maxX, midY), // right
        ]
    }

    // MARK: - Cursor feedback

    override func resetCursorRects() {
        // Top/bottom handles: up-down; left/right handles: left-right; everywhere else (including corners): open hand.
        addCursorRect(edgeCursorRect(.top), cursor: .resizeUpDown)
        addCursorRect(edgeCursorRect(.bottom), cursor: .resizeUpDown)
        addCursorRect(edgeCursorRect(.left), cursor: .resizeLeftRight)
        addCursorRect(edgeCursorRect(.right), cursor: .resizeLeftRight)
        addCursorRect(interiorCursorRect(), cursor: .openHand)
    }

    /// Hit-test tolerant strip along an edge: the edge midpoint handle plus `hitTolerance` on each side.
    private func edgeCursorRect(_ edge: Edge) -> NSRect {
        let t = Self.hitTolerance
        switch edge {
        case .top:
            return NSRect(x: bounds.minX + Self.handleSize, y: bounds.maxY - t,
                          width: bounds.width - Self.handleSize * 2, height: t * 2)
        case .bottom:
            return NSRect(x: bounds.minX + Self.handleSize, y: bounds.minY - t,
                          width: bounds.width - Self.handleSize * 2, height: t * 2)
        case .left:
            return NSRect(x: bounds.minX - t, y: bounds.minY + Self.handleSize,
                          width: t * 2, height: bounds.height - Self.handleSize * 2)
        case .right:
            return NSRect(x: bounds.maxX - t, y: bounds.minY + Self.handleSize,
                          width: t * 2, height: bounds.height - Self.handleSize * 2)
        }
    }

    private enum Edge {
        case top, bottom, left, right
    }

    private func interiorCursorRect() -> NSRect {
        bounds.insetBy(dx: Self.handleSize, dy: Self.handleSize)
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
        // Convert window coordinates to this view's bounds.
        let local = convert(locationInWindow, from: nil)
        let s = Self.handleSize
        let t = Self.hitTolerance

        // Edge midpoints only; corners are not handles and fall through to the interior.
        let nearTop = local.y >= bounds.maxY - t && local.x > bounds.minX + s && local.x < bounds.maxX - s
        let nearBottom = local.y <= bounds.minY + t && local.x > bounds.minX + s && local.x < bounds.maxX - s
        let nearLeft = local.x <= bounds.minX + t && local.y > bounds.minY + s && local.y < bounds.maxY - s
        let nearRight = local.x >= bounds.maxX - t && local.y > bounds.minY + s && local.y < bounds.maxY - s

        if nearTop {
            return .topEdge
        }
        if nearBottom {
            return .bottomEdge
        }
        if nearLeft {
            return .leftEdge
        }
        if nearRight {
            return .rightEdge
        }

        // Interior: anywhere not on an edge strip, including corners.
        return .interior
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
