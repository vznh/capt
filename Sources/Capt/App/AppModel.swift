import CaptionCore
import Foundation
import Observation

/// Top-level state for the menu bar and overlay. Builds a fresh session per run.
@MainActor
@Observable
final class AppModel {
    let store = CaptionStore()
    let settings = SettingsStore()

    private(set) var session: CaptionSession?
    private(set) var status: EngineStatus = .idle
    private(set) var errorMessage: String?
    private(set) var noAudioDetected = false
    private(set) var supportedLocales: [Locale] = []
    private(set) var installedLocales: [Locale] = []

    var isRunning: Bool { session?.isRunning ?? false }

    var statusText: String {
        if let errorMessage { return errorMessage }
        if noAudioDetected { return "No audio is being detected." }
        switch status {
        case .idle: return "Not currently scribing"
        case .preparingModel(let p):
            if let p, p > 0 { return "Downloading model \(Int(p * 100))%" }
            return "Preparing model…"
        case .ready: return "Starting…"
        case .running: return "Listening (\(localeName(settings.locale)))"
        case .stopped: return "Not currently scribing"
        }
    }

    func loadLocales() async {
        supportedLocales = await SpeechAnalyzerEngine.supportedLocales
            .sorted { localeName($0) < localeName($1) }
        installedLocales = await SpeechAnalyzerEngine.installedLocales
    }

    func toggle() {
        Task { isRunning ? await stop() : await start() }
    }

    func start() async {
        guard session == nil else { return }
        errorMessage = nil
        let engine = settings.engineKind.make(locale: settings.locale)
        let session = CaptionSession(capture: SystemAudioTap(), engine: engine, store: store)
        session.onStatus = { [weak self] in self?.status = $0 }
        session.onError = { [weak self] in self?.errorMessage = $0 }
        session.onSilenceChanged = { [weak self] in self?.noAudioDetected = $0 }
        self.session = session
        do {
            try await session.start()
        } catch {
            errorMessage = error.localizedDescription
            await session.stop()
            self.session = nil
            status = .idle
        }
    }

    func stop() async {
        await session?.stop()
        session = nil
        status = .idle
        noAudioDetected = false
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
}
