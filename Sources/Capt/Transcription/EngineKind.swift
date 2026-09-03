import CaptionCore
import Foundation

/// Which backend produces captions. Stored in settings; new engines get a case here
/// plus a branch in `make(locale:)`.
enum EngineKind: String, CaseIterable, Codable {
    case speechAnalyzer

    var displayName: String {
        switch self {
        case .speechAnalyzer: "Apple on-device (SpeechAnalyzer)"
        }
    }

    func make(locale: Locale) -> TranscriptionEngine {
        switch self {
        case .speechAnalyzer: SpeechAnalyzerEngine(locale: locale)
        }
    }
}
