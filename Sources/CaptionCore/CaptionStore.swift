import Foundation
import Observation

/// Holds the text currently shown on screen, capped to the last `maxSentences` sentences.
/// Pure state, no UI.
@MainActor
@Observable
public final class CaptionStore {
    /// Finalized text, already reduced to the trailing sentences.
    public private(set) var committed: String = ""
    /// Sample text shown in place of live captions while adjusting settings.
    public private(set) var previewText: String?
    /// The latest volatile text, appended after `committed` when rendering.
    public private(set) var partial: String = ""
    public private(set) var lastUpdate: Date?

    public let maxSentences: Int
    /// Safety cap for speech with no sentence boundaries.
    public let maxCharacters: Int

    public init(maxSentences: Int = 2, maxCharacters: Int = 240) {
        self.maxSentences = maxSentences
        self.maxCharacters = maxCharacters
    }

    /// Text to render: an active preview if set, otherwise the last
    /// `maxSentences` sentences of committed text plus the live partial.
    public var displayText: String {
        if let previewText {
            return previewText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return liveText
    }

    /// Shows sample text in place of live captions.
    public func showPreview(_ text: String) {
        previewText = text
    }

    /// Removes the sample text, restoring live captions.
    public func clearPreview() {
        previewText = nil
    }

    /// Sentences currently displayed, for tests and layout.
    public var sentences: [String] { SentenceSplitter.split(displayText) }

    public func apply(_ event: CaptionEvent, at date: Date = Date()) {
        switch event {
        case .partial(let text):
            partial = text
            lastUpdate = date
        case .final(let text):
            committed = Self.tail(of: join(committed, text), sentences: maxSentences, characters: maxCharacters)
            partial = ""
            lastUpdate = date
        case .status, .error:
            break
        }
    }

    /// Clears captions if nothing arrived for `timeout` seconds. Returns true if cleared.
    @discardableResult
    public func expireIfIdle(now: Date = Date(), timeout: TimeInterval) -> Bool {
        guard let lastUpdate, !liveText.isEmpty else { return false }
        guard now.timeIntervalSince(lastUpdate) >= timeout else { return false }
        clear()
        return true
    }

    public func clear() {
        committed = ""
        partial = ""
        lastUpdate = nil
    }

    /// Live caption text: committed + partial, before any preview override.
    private var liveText: String {
        Self.tail(of: join(committed, partial), sentences: maxSentences, characters: maxCharacters)
    }
    private func join(_ a: String, _ b: String) -> String {
        let a = a.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = b.trimmingCharacters(in: .whitespacesAndNewlines)
        if a.isEmpty { return b }
        if b.isEmpty { return a }
        return a + " " + b
    }

    private static func tail(of text: String, sentences: Int, characters: Int) -> String {
        var result = SentenceSplitter.split(text).suffix(sentences).joined(separator: " ")
        if result.count > characters {
            result = String(result.suffix(characters))
        }
        return result
    }
}
