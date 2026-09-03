import Foundation
import Observation

/// Holds the text currently shown on screen. Pure state, no UI.
@MainActor
@Observable
public final class CaptionStore {
    /// Finalized segments, oldest first. Trimmed to `maxSegments`.
    public private(set) var segments: [String] = []
    /// The latest volatile text, appended after `segments` when rendering.
    public private(set) var partial: String = ""
    public private(set) var lastUpdate: Date?

    public let maxSegments: Int

    public init(maxSegments: Int = 2) {
        self.maxSegments = maxSegments
    }

    /// Text to render: finalized segments followed by the in-progress partial.
    public var displayText: String {
        var parts = segments
        if !partial.isEmpty { parts.append(partial) }
        return parts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func apply(_ event: CaptionEvent, at date: Date = Date()) {
        switch event {
        case .partial(let text):
            partial = text
            lastUpdate = date
        case .final(let text):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                segments.append(trimmed)
                if segments.count > maxSegments {
                    segments.removeFirst(segments.count - maxSegments)
                }
            }
            partial = ""
            lastUpdate = date
        case .status, .error:
            break
        }
    }

    /// Clears captions if nothing arrived for `timeout` seconds. Returns true if cleared.
    @discardableResult
    public func expireIfIdle(now: Date = Date(), timeout: TimeInterval) -> Bool {
        guard let lastUpdate, !displayText.isEmpty else { return false }
        guard now.timeIntervalSince(lastUpdate) >= timeout else { return false }
        clear()
        return true
    }

    public func clear() {
        segments = []
        partial = ""
        lastUpdate = nil
    }
}
