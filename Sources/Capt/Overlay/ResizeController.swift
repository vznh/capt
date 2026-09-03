import AppKit
import CaptionCore

/// Runs resize mode on the caption panel's display: dims the screen around the box, makes the panel
/// draggable and resizable by its edges, shows a Reset / Cancel / Done toolbar, and commits or
/// restores the frame when the mode ends.
@MainActor
final class ResizeController {
    private(set) var isActive = false
    var onEnd: (() -> Void)?

    private let overlay: OverlayController
    private let store: CaptionStore

    private var dim: DimPanel?
    private var hud: ResizeHUDPanel?
    private var handles: ResizeOverlayView?
    private var originalFrame: CGRect = .zero

    init(overlay: OverlayController, store: CaptionStore) {
        self.overlay = overlay
        self.store = store
    }

    /// Enters resize mode with `previewText` showing in the box.
    func begin(previewText: String) {
        guard !isActive, let screen = overlay.screen else { return }
        isActive = true
        let panel = overlay.panel
        originalFrame = panel.frame
        store.showPreview(previewText)

        let dim = DimPanel(screen: screen)
        dim.cutout = panel.frame
        dim.orderFrontRegardless()
        dim.show()
        self.dim = dim

        let hud = ResizeHUDPanel(
            onReset: { [weak self] in self?.reset() },
            onCancel: { [weak self] in self?.cancel() },
            onDone: { [weak self] in self?.commit() }
        )
        hud.position(above: panel.frame, on: screen)
        self.hud = hud

        let view = ResizeOverlayView(frame: panel.contentView?.bounds ?? .zero)
        view.windowFrame = panel.frame
        view.clamp = { CaptionLayoutStore.clamp($0, to: screen) }
        view.onFrameChange = { [weak self] rect in
            self?.apply(rect, on: screen)
        }
        panel.setInteractive(true)
        panel.showResizeOverlay(view)
        handles = view

        // Key status lets Return and Escape reach the toolbar without activating the app.
        hud.makeKeyAndOrderFront(nil)
    }

    /// Saves the current frame for this display and leaves resize mode.
    func commit() {
        guard isActive, let screen = overlay.screen else { return }
        overlay.layout.setFrame(overlay.panel.frame, for: screen)
        end()
    }

    /// Restores the frame from before resize mode and leaves it.
    func cancel() {
        guard isActive else { return }
        overlay.panel.setFrame(originalFrame, display: true)
        end()
    }

    /// Moves the box back to this display's default frame. Not saved until Done.
    func reset() {
        guard isActive, let screen = overlay.screen else { return }
        apply(CaptionLayoutStore.clamp(CaptionLayoutStore.defaultFrame(for: screen), to: screen), on: screen)
    }

    private func apply(_ rect: CGRect, on screen: NSScreen) {
        overlay.panel.setFrame(rect, display: true)
        handles?.windowFrame = rect
        dim?.cutout = rect
        hud?.position(above: rect, on: screen)
    }

    private func end() {
        isActive = false
        overlay.panel.hideResizeOverlay()
        overlay.panel.setInteractive(false)
        hud?.close()
        hud = nil
        if let dim {
            dim.hide { dim.close() }
        }
        dim = nil
        handles = nil
        store.clearPreview()
        onEnd?()
    }
}
