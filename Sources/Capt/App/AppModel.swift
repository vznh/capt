import CaptionCore
import Foundation
import Observation
import SwiftUI

/// Top-level state for the menu bar and overlay. Builds a fresh session per run.
@MainActor
@Observable
final class AppModel {
    /// Range of caption font sizes the user can pick, in points.
    static let fontSizeRange: ClosedRange<Double> = 14...48

    /// Sample sentence shown by both preview entry points.
    private static let sampleSentence = "Captions will look like this. Pick a size that reads comfortably."

    /// Leftover scroll delta between adjustments; every 6 points of magnitude moves the size by 1 pt.
    private var scrollAccumulator: CGFloat = 0

    let store = CaptionStore()
    let settings = SettingsStore()

    private(set) var session: CaptionSession?
    private(set) var status: EngineStatus = .idle
    private(set) var errorMessage: String?
    private(set) var noAudioDetected = false
    private(set) var supportedLocales: [Locale] = []
    private var previewTask: Task<Void, Never>?
    private(set) var installedLocales: [Locale] = []

    /// What the user asked for. Flips immediately so the switch does not snap back while the engine starts.
    private(set) var isEnabled = false

    /// Words transcribed since the current session started.
    private(set) var sessionWordCount = 0

    /// Easter egg shown while Command is held: this session's words when active, all-time words otherwise.
    var wordCountText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        if status == .running {
            let n = formatter.string(from: NSNumber(value: sessionWordCount)) ?? "\(sessionWordCount)"
            return "\(n) \(sessionWordCount == 1 ? "word" : "words") transcribed this session"
        }
        let total = settings.totalWordCount
        let n = formatter.string(from: NSNumber(value: total)) ?? "\(total)"
        return "\(n) \(total == 1 ? "word" : "words") transcribed all time"
    }

    var isRunning: Bool { session?.isRunning ?? false }

    /// BCP 47 tag of the chosen locale, matching the tags used by the language picker.
    var selectedLocaleTag: String { settings.locale.identifier(.bcp47) }

    /// Shown beside the title: Active while transcribing, Inactive otherwise.
    var activityLabel: String { status == .running ? "Active" : "Inactive" }

    /// Secondary line under the title, only for states that need explaining. Nil when idle or running normally.
    var detailText: String? {
        if let errorMessage { return errorMessage }
        if noAudioDetected { return "No audio is being detected." }
        switch status {
        case .preparingModel(let p):
            if let p, p > 0 { return "Downloading model \(Int(p * 100))%" }
            return "Preparing model…"
        case .ready: return "Starting…"
        case .idle, .running, .stopped: return nil
        }
    }

    var statusText: String {
        if let errorMessage { return errorMessage }
        if noAudioDetected { return "No audio is being detected." }
        switch status {
        case .idle: return "Capt is off"
        case .preparingModel(let p):
            if let p, p > 0 { return "Downloading model \(Int(p * 100))%" }
            return "Preparing model…"
        case .ready: return "Starting…"
        case .running: return "Listening (\(localeName(settings.locale)))"
        case .stopped: return "Capt is off"
        }
    }

    func loadLocales() async {
        supportedLocales = await SpeechAnalyzerEngine.supportedLocales
            .sorted { localeName($0) < localeName($1) }
        installedLocales = await SpeechAnalyzerEngine.installedLocales
    }

    func toggle() {
        setEnabled(!isEnabled)
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        Task { enabled ? await start() : await stop() }
    }

    func start() async {
        guard session == nil else { return }
        isEnabled = true
        errorMessage = nil
        let engine = settings.engineKind.make(locale: settings.locale)
        let session = CaptionSession(capture: SystemAudioTap(), engine: engine, store: store)
        session.onStatus = { [weak self] in self?.status = $0 }
        session.onError = { [weak self] in self?.errorMessage = $0 }
        session.onSilenceChanged = { [weak self] in self?.noAudioDetected = $0 }
        session.onFinalText = { [weak self] text in
            let words = text.split(whereSeparator: \.isWhitespace).count
            self?.sessionWordCount += words
            self?.settings.totalWordCount += words
        }
        sessionWordCount = 0
        self.session = session
        do {
            try await session.start()
        } catch {
            errorMessage = error.localizedDescription
            await session.stop()
            self.session = nil
            status = .idle
            isEnabled = false
        }
    }

    func stop() async {
        await session?.stop()
        session = nil
        status = .idle
        noAudioDetected = false
        isEnabled = false
    }

    func selectLocale(tag: String) {
        guard let locale = supportedLocales.first(where: { $0.identifier(.bcp47) == tag }) else { return }
        selectLocale(locale)
    }

    func selectLocale(_ locale: Locale) {
        settings.localeIdentifier = locale.identifier
        guard isRunning else { return }
        Task {
            await stop()
            await start()
        }
    }

    func localeName(_ locale: Locale) -> String {
        Locale.current.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
    }

    /// Shows sample caption text in the overlay for a few seconds so the user can judge the font size.
    func previewCaptions() {
        store.showPreview(Self.sampleSentence)
        previewTask?.cancel()
        previewTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            store.clearPreview()
        }
    }

    /// Shows the sample caption and keeps it up until `endPreview()`.
    func beginPreview() {
        previewTask?.cancel()
        previewTask = nil
        store.showPreview(Self.sampleSentence)
    }

    /// Hides the sample caption.
    func endPreview() {
        previewTask?.cancel()
        previewTask = nil
        store.clearPreview()
    }

    /// Adjusts the caption size from vertical scroll delta. Every 6 points of accumulated
    /// magnitude changes the size by 1 pt; scrolling up (negative delta) grows the text.
    func adjustFontSize(scrollDelta: CGFloat) {
        scrollAccumulator += scrollDelta
        let steps = Int(scrollAccumulator / 6)
        guard steps != 0 else { return }
        scrollAccumulator -= CGFloat(steps) * 6
        let proposed = settings.fontSize - Double(steps)
        let newSize = min(max(proposed, Self.fontSizeRange.lowerBound), Self.fontSizeRange.upperBound)
        guard newSize != settings.fontSize else { return }
        withAnimation(.snappy(duration: 0.18)) {
            settings.fontSize = newSize
        }
    }
}
