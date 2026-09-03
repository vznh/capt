import AppKit
import SwiftUI

/// Attaches a custom `NSCursor` and a scroll-wheel handler to any view while it is hovered,
/// consuming the scroll events so the enclosing panel does not scroll. Used by the menu panel rows.
///
/// Implementation notes:
/// - Uses `NSEvent.addLocalMonitorForEvents(matching: .scrollWheel)` rather than an
///   `NSViewRepresentable` overlay. A `Menu` styled with `.buttonStyle(.plain)` inside a
///   menu-bar panel is hosted in an `NSHostingView` with a full-size content view, so a
///   background `NSView` subclass overriding `scrollWheel(with:)` is never hit — its frame
///   is behind the hosting view and AppKit routes wheel events to the responder chain, not
///   to arbitrary sibling views. A local event monitor sees the event before dispatch.
/// - The monitor is installed in `onHover(true)` and removed in `onHover(false)` and
///   `onDisappear`, so nothing leaks if the panel closes while the row is hovered.
/// - The monitor closure returns `nil` to consume the event.
private struct ScrollWheelModifier: ViewModifier {
    /// Cursor shown while the pointer hovers the modified view. `nil` restores the current cursor.
    let cursor: NSCursor?
    /// Called with vertical scroll deltas (points) while hovered. Positive = fingers/wheel
    /// moving down on a natural-scrolling device.
    let onDeltaY: (CGFloat) -> Void

    @State private var monitorToken: Any?
    @State private var isHovering = false
    @State private var cursorPushed = false

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    pushCursor()
                    installMonitor()
                } else {
                    teardown()
                }
            }
            .onDisappear {
                isHovering = false
                teardown()
            }
    }

    @MainActor
    private func pushCursor() {
        guard !cursorPushed, let cursor else { return }
        cursor.push()
        cursorPushed = true
    }

    @MainActor
    private func installMonitor() {
        guard monitorToken == nil else { return }
        monitorToken = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            guard isHovering else { return event }
            var deltaY = event.scrollingDeltaY
            // A mouse wheel notch is not a precise-delta event; scale it up so one notch
            // is a meaningful step instead of a pixel.
            if !event.hasPreciseScrollingDeltas {
                deltaY *= 10
            }
            if deltaY != 0 {
                onDeltaY(deltaY)
            }
            // Returning nil consumes the event: the panel does not scroll.
            return nil
        }
    }

    @MainActor
    private func teardown() {
        if let token = monitorToken {
            NSEvent.removeMonitor(token)
        }
        monitorToken = nil
        if cursorPushed {
            NSCursor.pop()
            cursorPushed = false
        }
    }
}

extension View {
    /// Shows `cursor` while hovering and reports vertical scroll deltas (points; positive =
    /// fingers/wheel moving down on a natural-scrolling device) while hovered. Scroll events
    /// are consumed.
    func onScrollWheel(cursor: NSCursor? = nil,
                       perform: @escaping (_ deltaY: CGFloat) -> Void) -> some View {
        modifier(ScrollWheelModifier(cursor: cursor, onDeltaY: perform))
    }
}
