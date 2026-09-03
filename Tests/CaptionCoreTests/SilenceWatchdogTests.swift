import Foundation
import Testing
@testable import CaptionCore

struct SilenceWatchdogTests {
    @Test func firesOnceAfterSustainedSilence() {
        let watchdog = SilenceWatchdog(threshold: 5)
        let t0 = Date(timeIntervalSince1970: 0)
        #expect(watchdog.observe(peak: 0, at: t0) == .ok)
        #expect(watchdog.observe(peak: 0, at: t0.addingTimeInterval(4)) == .ok)
        #expect(watchdog.observe(peak: 0, at: t0.addingTimeInterval(5)) == .silentTooLong)
        #expect(watchdog.observe(peak: 0, at: t0.addingTimeInterval(20)) == .ok)
    }

    @Test func reportsResumeAndCanFireAgain() {
        let watchdog = SilenceWatchdog(threshold: 5)
        let t0 = Date(timeIntervalSince1970: 0)
        _ = watchdog.observe(peak: 0, at: t0)
        #expect(watchdog.observe(peak: 0, at: t0.addingTimeInterval(5)) == .silentTooLong)
        #expect(watchdog.observe(peak: 0.5, at: t0.addingTimeInterval(6)) == .audioResumed)
        #expect(watchdog.observe(peak: 0.5, at: t0.addingTimeInterval(7)) == .ok)
        _ = watchdog.observe(peak: 0, at: t0.addingTimeInterval(8))
        #expect(watchdog.observe(peak: 0, at: t0.addingTimeInterval(13)) == .silentTooLong)
    }

    @Test func audioResetsTheClock() {
        let watchdog = SilenceWatchdog(threshold: 5)
        let t0 = Date(timeIntervalSince1970: 0)
        #expect(watchdog.observe(peak: 0, at: t0) == .ok)
        #expect(watchdog.observe(peak: 0.3, at: t0.addingTimeInterval(4)) == .ok)
        #expect(watchdog.observe(peak: 0, at: t0.addingTimeInterval(6)) == .ok)
        #expect(watchdog.observe(peak: 0, at: t0.addingTimeInterval(11)) == .silentTooLong)
    }
}
