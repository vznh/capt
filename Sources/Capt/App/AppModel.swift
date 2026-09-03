import CaptionCore
import Foundation
import Observation
import SwiftUI

/// Top-level state for the menu bar and overlay. Builds a fresh session per run.
@MainActor
@Observable
final class AppModel {
    /// Range of caption font sizes the user can pick, in points.
    static let fontSizeRange: ClosedRange<Double> = 14 ... 48

    /// Sample sentence shown by both preview entry points.
    private static let sampleSentence = "Captions will look like this. Pick a size that reads comfortably."

    /// Scroll distance, in points, that changes the caption size by one point.
    private static let scrollPointsPerStep: CGFloat = 6
    /// How long a menu-triggered preview stays on screen.
    private static let previewHold: Duration = .seconds(4)

    /// Leftover scroll delta between adjustments.
    private var scrollAccumulator: CGFloat = 0

    // MARK: - Dependencies

    let store = CaptionStore()
    let settings = SettingsStore()
    private let layout = CaptionLayoutStore()
    private var overlay: OverlayController?
    private var resize: ResizeController?

    // MARK: - State

    private var session: CaptionSession?
    /// The in-flight `start()`, so `stop()` can wait for it instead of orphaning a half-started session.
    private var startTask: Task<Void, Never>?
    private(set) var status: EngineStatus = .idle
    private(set) var errorMessage: String?
    private(set) var noAudioDetected = false
    private(set) var supportedLocales: [Locale] = []
    /// Locale identifier to installed-state. A missing entry means the status is still loading.
    private(set) var localeAssetsInstalled: [String: Bool] = [:]
    private var previewTask: Task<Void, Never>?

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
        return "\(n) \(total == 1 ? "word" : "words") transcribed totally"
    }

    var isRunning: Bool {
        session?.isRunning ?? false
    }

    /// Shown beside the title: Active while transcribing, Inactive otherwise.
    var activityLabel: String {
        status == .running ? "Active" : "Inactive"
    }

    /// Secondary line under the title, only for states that need explaining. Nil when idle or running normally.
    var detailText: String? {
        if let errorMessage {
            return errorMessage
        }
        if noAudioDetected {
            return "No audio is being detected."
        }
        switch status {
        case .preparingModel(let p):
            if let p, p > 0 {
                return "Downloading model \(Int(p * 100))%"
            }
            return "Preparing model…"
        case .ready: return "Starting…"
        case .idle, .running, .stopped: return nil
        }
    }

    // MARK: - Intents

    /// Creates the per-display caption panels. Called once from the app delegate.
    func startOverlay() {
        guard overlay == nil else { return }
        let overlay = OverlayController(store: store, settings: settings, layout: layout)
        overlay.start()
        self.overlay = overlay
        resize = ResizeController(overlay: overlay, store: store)
    }

    /// Enters resize mode on every display with a sample caption showing.
    func beginResize() {
        resize?.begin(previewText: Self.sampleSentence)
    }

    func loadLocales() async {
        let locales = await SpeechAnalyzerEngine.supportedLocales
            .sorted { localeName($0) < localeName($1) }
        supportedLocales = locales
        localeAssetsInstalled = await SpeechAnalyzerEngine.assetInstallationStatus(for: locales)
    }

    func refreshLocaleAssetStatus() async {
        guard !supportedLocales.isEmpty else { return }
        localeAssetsInstalled = await SpeechAnalyzerEngine.assetInstallationStatus(for: supportedLocales)
    }

    func localeRequiresDownload(_ locale: Locale) -> Bool {
        localeAssetsInstalled[locale.identifier] == false
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        Task { enabled ? await start() : await stop() }
    }

    func start() async {
        guard session == nil, startTask == nil else { return }
        isEnabled = true
        errorMessage = nil
        noAudioDetected = false
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
        let task = Task { [weak self] in
            do {
                try await session.start()
            } catch {
                self?.errorMessage = error.localizedDescription
                self?.session = nil
                self?.status = .idle
                self?.isEnabled = false
            }
        }
        startTask = task
        await task.value
        startTask = nil
        await refreshLocaleAssetStatus()
    }

    func stop() async {
        // Let a start that is still preparing the model finish, then tear it down.
        await startTask?.value
        await session?.stop()
        session = nil
        status = .idle
        noAudioDetected = false
        isEnabled = false
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

    // MARK: - Preview and text size

    /// Shows sample caption text in the overlay for a few seconds so the user can judge the font size.
    func previewCaptions() {
        store.showPreview(Self.sampleSentence)
        previewTask?.cancel()
        previewTask = Task {
            try? await Task.sleep(for: Self.previewHold)
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
        let steps = Int(scrollAccumulator / Self.scrollPointsPerStep)
        guard steps != 0 else { return }
        scrollAccumulator -= CGFloat(steps) * Self.scrollPointsPerStep
        let proposed = settings.fontSize - Double(steps)
        let newSize = min(max(proposed, Self.fontSizeRange.lowerBound), Self.fontSizeRange.upperBound)
        guard newSize != settings.fontSize else { return }
        withAnimation(.snappy(duration: 0.18)) {
            settings.fontSize = newSize
        }
    }
}
