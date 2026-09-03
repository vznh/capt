import AVFoundation
import CaptionCore
import OSLog
import Speech

/// On-device streaming transcription via Apple's SpeechAnalyzer (macOS 26).
/// Locale must be chosen up front; SpeechAnalyzer does not auto-detect language.
final class SpeechAnalyzerEngine: TranscriptionEngine, @unchecked Sendable {
    let events: AsyncStream<CaptionEvent>

    private let continuation: AsyncStream<CaptionEvent>.Continuation
    private let logger = Logger(subsystem: kAppSubsystem, category: "SpeechAnalyzerEngine")
    private let requestedLocale: Locale

    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    private var analyzerFormat: AVAudioFormat?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?

    /// Touched only from the audio I/O thread.
    private var converter: AudioFormatConverter?

    init(locale: Locale) {
        requestedLocale = locale
        (events, continuation) = AsyncStream<CaptionEvent>.makeStream()
    }

    static var supportedLocales: [Locale] {
        get async { await SpeechTranscriber.supportedLocales }
    }

    /// Reports whether each locale's transcription assets are ready without reserving or
    /// downloading anything. Asset installation remains an explicit consequence of starting Capt.
    static func assetInstallationStatus(for locales: [Locale]) async -> [String: Bool] {
        var result: [String: Bool] = [:]
        result.reserveCapacity(locales.count)
        for locale in locales {
            result[locale.identifier] = await assetsAreInstalled(for: locale)
        }
        return result
    }

    static func assetsAreInstalled(for locale: Locale) async -> Bool {
        let transcriber = makeTranscriber(locale: locale)
        return await AssetInventory.status(forModules: [transcriber]) == .installed
    }

    func prepare() async throws {
        guard SpeechTranscriber.isAvailable else {
            throw CaptError("SpeechAnalyzer is not available on this Mac.")
        }
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: requestedLocale) else {
            throw CaptError("Language \(requestedLocale.identifier) is not supported by SpeechAnalyzer.")
        }

        let transcriber = Self.makeTranscriber(locale: locale)
        self.transcriber = transcriber

        try await ensureAssets(for: transcriber, locale: locale)

        let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
        analyzerFormat = format
        logger.info("Analyzer format: \(String(describing: format), privacy: .public)")

        // High priority for live captions; keep the model loaded across start/stop cycles.
        let options = SpeechAnalyzer.Options(priority: .userInitiated, modelRetention: .processLifetime)
        let analyzer = SpeechAnalyzer(modules: [transcriber], options: options)
        self.analyzer = analyzer
        try await analyzer.prepareToAnalyze(in: format)
        continuation.yield(.status(.ready))
    }

    func start() async throws {
        guard let analyzer, let transcriber else { throw CaptError("Engine not prepared") }

        let (inputSequence, builder) = AsyncStream<AnalyzerInput>.makeStream()
        inputBuilder = builder

        resultsTask = Task { [continuation, logger] in
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                    continuation.yield(result.isFinal ? .final(text) : .partial(text))
                }
            } catch {
                logger.error("Results stream failed: \(error, privacy: .public)")
                continuation.yield(.error(error.localizedDescription))
            }
        }

        try await analyzer.start(inputSequence: inputSequence)
        continuation.yield(.status(.running))
    }

    func send(_ buffer: AVAudioPCMBuffer) {
        guard let inputBuilder else { return }
        guard let target = analyzerFormat else {
            inputBuilder.yield(AnalyzerInput(buffer: buffer))
            return
        }
        if converter == nil || converter?.inputFormat != buffer.format {
            converter = AudioFormatConverter(from: buffer.format, to: target)
        }
        guard let converted = converter?.convert(buffer) else { return }
        inputBuilder.yield(AnalyzerInput(buffer: converted))
    }

    func stop() async {
        inputBuilder?.finish()
        inputBuilder = nil
        try? await analyzer?.finalizeAndFinishThroughEndOfInput()
        resultsTask?.cancel()
        resultsTask = nil
        continuation.yield(.status(.stopped))
        continuation.finish()
    }

    private func ensureAssets(for transcriber: SpeechTranscriber, locale: Locale) async throws {
        let status = await AssetInventory.status(forModules: [transcriber])
        guard status != .installed else { return }
        guard status != .unsupported else { throw CaptError("No speech model for \(locale.identifier).") }

        _ = try? await AssetInventory.reserve(locale: locale)
        guard let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) else { return }

        continuation.yield(.status(.preparingModel(0)))
        let progressTask = Task { [continuation] in
            while !Task.isCancelled {
                continuation.yield(.status(.preparingModel(request.progress.fractionCompleted)))
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
        defer { progressTask.cancel() }
        try await request.downloadAndInstall()
    }

    private static func makeTranscriber(locale: Locale) -> SpeechTranscriber {
        SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults, .fastResults],
            attributeOptions: []
        )
    }
}
