import AVFoundation

/// Events emitted by a `TranscriptionEngine`.
public enum CaptionEvent: Sendable, Equatable {
    /// In-progress text that may still change.
    case partial(String)
    /// Text that will no longer change.
    case final(String)
    case status(EngineStatus)
    case error(String)
}

public enum EngineStatus: Sendable, Equatable {
    case idle
    /// Downloading or loading the speech model. Progress is 0...1 when known.
    case preparingModel(Double?)
    case ready
    case running
    case stopped
}

/// A streaming speech-to-text backend. Implementations: `SpeechAnalyzerEngine` (on-device, macOS 26).
/// Future: Deepgram / Whisper engines conform to the same seam.
public protocol TranscriptionEngine: AnyObject {
    var events: AsyncStream<CaptionEvent> { get }
    /// Load models and warm up. Called once before `start()`.
    func prepare() async throws
    func start() async throws
    /// Called from the audio I/O thread. Must be cheap and non-blocking.
    func send(_ buffer: AVAudioPCMBuffer)
    func stop() async
}

/// A source of PCM audio. Implementations: `SystemAudioTap` (Core Audio process tap).
public protocol AudioCapturing: AnyObject {
    /// Starts delivering buffers on an internal queue.
    func start(onBuffer: @escaping @Sendable (AVAudioPCMBuffer) -> Void) throws
    func stop()
}
