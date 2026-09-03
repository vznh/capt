import CaptionCore
import Foundation

/// Which backend produces captions. Stored in settings; new engines get a case here
/// plus a branch in `make(locale:)`.
enum EngineKind: String {
    case speechAnalyzer

    func make(locale: Locale) -> TranscriptionEngine {
        switch self {
        case .speechAnalyzer: SpeechAnalyzerEngine(locale: locale)
        }
    }
}
