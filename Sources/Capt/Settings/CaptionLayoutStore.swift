import AppKit
import Foundation
import Observation

/// A caption frame stored as fractions of the screen frame.
struct NormalizedRect: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
}

/// Where the caption region sits on each display. Frames are stored as fractions of the screen
/// frame so resolution changes scale the box instead of pushing it off screen.
@MainActor
@Observable
final class CaptionLayoutStore {
    /// In-memory source of truth, keyed by DisplayID.uuid. Loaded in init, written on every set/reset.
    private var frames: [String: NormalizedRect] = [:]

    private let defaults: UserDefaults

    /// Loads persisted frames from the single "captions.frames" defaults key.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Keys.frames),
           let stored = try? JSONDecoder().decode([String: NormalizedRect].self, from: data)
        {
            frames = stored
        }
    }

    /// Stored frame for the screen, or the default, always clamped to the screen with Self.clamp.
    func frame(for screen: NSScreen) -> CGRect {
        if let id = screen.displayID, let stored = frames[id.uuid] {
            return Self.clamp(Self.denormalize(stored, in: screen.frame), to: screen)
        }
        return Self.clamp(Self.defaultFrame(for: screen), to: screen)
    }

    /// Converts a fractional rect back to screen coordinates.
    private static func denormalize(_ rect: NormalizedRect, in bounds: CGRect) -> CGRect {
        CGRect(
            x: bounds.origin.x + rect.x * bounds.width,
            y: bounds.origin.y + rect.y * bounds.height,
            width: rect.width * bounds.width,
            height: rect.height * bounds.height
        )
    }

    /// Stores the frame (normalized against screen.frame) and publishes the change. If the screen
    /// has no DisplayID, keeps it in memory only for this run.
    func setFrame(_ rect: CGRect, for screen: NSScreen) {
        let bounds = screen.frame
        guard bounds.width > 0, bounds.height > 0 else { return }
        let normalized = NormalizedRect(
            x: (rect.origin.x - bounds.origin.x) / bounds.width,
            y: (rect.origin.y - bounds.origin.y) / bounds.height,
            width: rect.width / bounds.width,
            height: rect.height / bounds.height
        )
        guard let id = screen.displayID else { return }
        frames[id.uuid] = normalized
        persist()
    }

    /// 70% of the screen width capped at 1200, 200 tall, bottom-centered 48 pt above the screen's
    /// bottom edge (this is the app's existing default).
    static func defaultFrame(for screen: NSScreen) -> CGRect {
        let bounds = screen.frame
        let width = min(bounds.width * 0.7, 1200)
        let height: CGFloat = 200
        let origin = NSPoint(x: bounds.midX - width / 2, y: bounds.minY + 48)
        return CGRect(origin: origin, size: NSSize(width: width, height: height))
    }

    /// Half the default size for that screen.
    static func minimumSize(for screen: NSScreen) -> CGSize {
        let frame = defaultFrame(for: screen)
        return CGSize(width: frame.width / 2, height: frame.height / 2)
    }

    /// Enforces minimum size, caps size to screen.visibleFrame.size, then shifts the origin so the
    /// rect lies fully inside screen.visibleFrame.
    static func clamp(_ rect: CGRect, to screen: NSScreen) -> CGRect {
        let minSize = minimumSize(for: screen)
        let visible = screen.visibleFrame

        // Cap to the visible frame first; the minimum size must never win over the
        // screen, or the result would be larger than the display it has to fit inside.
        var width = min(rect.width, visible.width)
        var height = min(rect.height, visible.height)
        width = max(width, min(minSize.width, visible.width))
        height = max(height, min(minSize.height, visible.height))

        var x = rect.origin.x
        var y = rect.origin.y
        x = min(max(x, visible.minX), visible.maxX - width)
        y = min(max(y, visible.minY), visible.maxY - height)

        return CGRect(origin: NSPoint(x: x, y: y), size: NSSize(width: width, height: height))
    }

    /// Writes the in-memory map back to the single "captions.frames" defaults key.
    private func persist() {
        guard let data = try? JSONEncoder().encode(frames) else { return }
        defaults.set(data, forKey: Keys.frames)
    }

    private enum Keys {
        static let frames = "captions.frames"
    }
}
