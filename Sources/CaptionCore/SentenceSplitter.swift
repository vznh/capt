import Foundation
import NaturalLanguage

/// Language-agnostic sentence segmentation via NaturalLanguage. Handles CJK punctuation too.
enum SentenceSplitter {
    static func split(_ text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = trimmed
        var sentences: [String] = []
        tokenizer.enumerateTokens(in: trimmed.startIndex..<trimmed.endIndex) { range, _ in
            let sentence = trimmed[range].trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty { sentences.append(sentence) }
            return true
        }
        return sentences.isEmpty ? [trimmed] : sentences
    }
}
