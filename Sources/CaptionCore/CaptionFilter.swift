import Foundation

/// Removes non-speech annotations from recognized text before it is shown, e.g. "[clears throat]",
/// "(coughs)", "*sighs*", "[Music]". Captions should carry speech only.
enum CaptionFilter {
    private static let annotation = try! NSRegularExpression(
        pattern: #"\s*(\[[^\]]*\]|\([^)]*\)|\*[^*]*\*)\s*"#
    )

    static func clean(_ text: String) -> String {
        let range = NSRange(text.startIndex..., in: text)
        let stripped = annotation.stringByReplacingMatches(in: text, range: range, withTemplate: " ")
        return stripped
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
