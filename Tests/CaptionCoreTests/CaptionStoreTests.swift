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

    @Test func finalCommitsAndClearsPartial() {
        let store = CaptionStore()
        store.apply(.partial("hello wor"))
        store.apply(.final("hello world."))
        #expect(store.displayText == "hello world.")
        #expect(store.partial.isEmpty)
        store.apply(.partial("how"))
        #expect(store.displayText == "hello world. how")
    }

    @Test func keepsOnlyLastTwoSentencesAcrossFinals() {
        let store = CaptionStore(maxSentences: 2)
        store.apply(.final("First one. Second one."))
        store.apply(.final("Third one."))
        #expect(store.sentences == ["Second one.", "Third one."])
    }

    @Test func partialCountsTowardTheLimit() {
        let store = CaptionStore(maxSentences: 2)
        store.apply(.final("First one. Second one."))
        store.apply(.partial("Third is still"))
        #expect(store.sentences == ["Second one.", "Third is still"])
    }

    @Test func splitsSentencesWithinOneFinal() {
        let store = CaptionStore(maxSentences: 2)
        store.apply(.final("One. Two. Three. Four."))
        #expect(store.sentences == ["Three.", "Four."])
    }

    @Test func handlesCJKPunctuation() {
        let store = CaptionStore(maxSentences: 2)
        store.apply(.final("こんにちは。元気ですか。さようなら。"))
        #expect(store.sentences == ["元気ですか。", "さようなら。"])
    }

    @Test func capsRunOnSpeechByCharacters() {
        let store = CaptionStore(maxSentences: 2, maxCharacters: 20)
        store.apply(.final(String(repeating: "word ", count: 20)))
        #expect(store.displayText.count <= 20)
    }

    @Test func ignoresEmptyFinals() {
        let store = CaptionStore()
        store.apply(.final("   "))
        #expect(store.displayText.isEmpty)
    }

    @Test func expiresAfterIdleTimeout() {
        let store = CaptionStore()
        let t0 = Date(timeIntervalSince1970: 1000)
        store.apply(.final("hello"), at: t0)
        #expect(!store.expireIfIdle(now: t0.addingTimeInterval(2), timeout: 5))
        #expect(store.expireIfIdle(now: t0.addingTimeInterval(6), timeout: 5))
        #expect(store.displayText.isEmpty)
    }

    @Test func previewOverridesLiveText() {
        let store = CaptionStore()
        store.apply(.final("hello"), at: Date(timeIntervalSince1970: 1000))
        store.showPreview("preview text")
        #expect(store.displayText == "preview text")
        store.clearPreview()
        #expect(store.displayText == "hello")
    }

    @Test func previewDoesNotBlockIdleExpiry() {
        let store = CaptionStore()
        let t0 = Date(timeIntervalSince1970: 1000)
        store.apply(.final("hello"), at: t0)
        store.showPreview("preview")
        #expect(!store.expireIfIdle(now: t0.addingTimeInterval(2), timeout: 5))
        store.clearPreview()
        #expect(store.expireIfIdle(now: t0.addingTimeInterval(6), timeout: 5))
        #expect(store.displayText.isEmpty)
    }
}
