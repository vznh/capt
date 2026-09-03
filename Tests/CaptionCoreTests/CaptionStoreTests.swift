import Foundation
import Testing
@testable import CaptionCore

@MainActor
struct CaptionStoreTests {
    @Test func partialReplacesPreviousPartial() {
        let store = CaptionStore()
        store.apply(.partial("hel"))
        store.apply(.partial("hello"))
        #expect(store.displayText == "hello")
    }

    @Test func finalAppendsAndClearsPartial() {
        let store = CaptionStore()
        store.apply(.partial("hello wor"))
        store.apply(.final("hello world"))
        #expect(store.displayText == "hello world")
        #expect(store.partial.isEmpty)
        store.apply(.partial("how"))
        #expect(store.displayText == "hello world how")
    }

    @Test func trimsToMaxSegments() {
        let store = CaptionStore(maxSegments: 2)
        store.apply(.final("one"))
        store.apply(.final("two"))
        store.apply(.final("three"))
        #expect(store.segments == ["two", "three"])
    }

    @Test func ignoresEmptyFinals() {
        let store = CaptionStore()
        store.apply(.final("   "))
        #expect(store.segments.isEmpty)
    }

    @Test func expiresAfterIdleTimeout() {
        let store = CaptionStore()
        let t0 = Date(timeIntervalSince1970: 1000)
        store.apply(.final("hello"), at: t0)
        #expect(!store.expireIfIdle(now: t0.addingTimeInterval(2), timeout: 5))
        #expect(store.expireIfIdle(now: t0.addingTimeInterval(6), timeout: 5))
        #expect(store.displayText.isEmpty)
    }
}
