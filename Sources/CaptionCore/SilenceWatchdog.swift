import Foundation

/// Detects the "tap returns all zeros" failure mode: a Core Audio process tap without the
/// audio-capture permission produces silent buffers and no error. Fires once.
final class SilenceWatchdog: @unchecked Sendable {
    enum Verdict: Sendable, Equatable {
        case ok
        /// Silence exceeded the threshold. Reported once per silent stretch.
        case silentTooLong
        /// Audio came back after `silentTooLong` was reported.
        case audioResumed
    }

    private let threshold: TimeInterval
    private let peakFloor: Float
    private var firstSilentAt: Date?
    private var fired = false

    init(threshold: TimeInterval = 8, peakFloor: Float = 1e-5) {
        self.threshold = threshold
        self.peakFloor = peakFloor
    }

    /// Feed the peak absolute sample of each buffer. Call from a single thread.
    func observe(peak: Float, at date: Date) -> Verdict {
        if peak > peakFloor {
            firstSilentAt = nil
            if fired {
                fired = false
                return .audioResumed
            }
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
