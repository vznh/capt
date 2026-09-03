import Foundation

/// Detects the "tap returns all zeros" failure mode: a Core Audio process tap without the
/// audio-capture permission produces silent buffers and no error. Fires once.
public final class SilenceWatchdog: @unchecked Sendable {
    public enum Verdict: Sendable, Equatable {
        case ok
        case silentTooLong
    }

    private let threshold: TimeInterval
    private let peakFloor: Float
    private var firstSilentAt: Date?
    private var fired = false

    public init(threshold: TimeInterval = 8, peakFloor: Float = 1e-5) {
        self.threshold = threshold
        self.peakFloor = peakFloor
    }

    /// Feed the peak absolute sample of each buffer. Call from a single thread.
    public func observe(peak: Float, at date: Date) -> Verdict {
        if peak > peakFloor {
            firstSilentAt = nil
            return .ok
        }
        guard !fired else { return .ok }
        if let start = firstSilentAt {
            if date.timeIntervalSince(start) >= threshold {
                fired = true
                return .silentTooLong
            }
        } else {
            firstSilentAt = date
        }
        return .ok
    }
}
