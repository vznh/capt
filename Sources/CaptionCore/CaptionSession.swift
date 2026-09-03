import AVFoundation
import Foundation

/// Wires capture -> engine -> store. Owns the lifecycle of one captioning run.
@MainActor
public final class CaptionSession {
    public private(set) var isRunning = false
    public private(set) var status: EngineStatus = .idle

    public var onStatus: ((EngineStatus) -> Void)?
    public var onError: ((String) -> Void)?

    /// Seconds without new text before the overlay clears.
    public var idleTimeout: TimeInterval = 5
    /// Minimum spacing between partial-text redraws. Fast results rewrite words many times a second;
    /// coalescing them keeps the caption readable. Finals always render immediately.
    public var partialInterval: TimeInterval = 0.25

    private let capture: AudioCapturing
    private let engine: TranscriptionEngine
    private let store: CaptionStore
    private var eventTask: Task<Void, Never>?
    private var idleTask: Task<Void, Never>?
    private var partialCooldown: Task<Void, Never>?
    private var pendingPartial: String?

    public init(capture: AudioCapturing, engine: TranscriptionEngine, store: CaptionStore) {
        self.capture = capture
        self.engine = engine
        self.store = store
    }

    public func start() async throws {
        guard !isRunning else { return }

        let events = engine.events
        eventTask = Task { [weak self] in
            for await event in events {
                self?.handle(event)
            }
        }

        try await engine.prepare()
        try await engine.start()

        let watchdog = SilenceWatchdog()
        let engine = self.engine
        try capture.start { [weak self] buffer in
            if let peak = AudioLevel.peak(of: buffer),
               watchdog.observe(peak: peak, at: Date()) == .silentTooLong {
                Task { @MainActor in
                    self?.onError?("No audio is reaching Capt. Check System Settings > Privacy & Security > Screen & System Audio Recording.")
                }
            }
            engine.send(buffer)
        }

        idleTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                self.store.expireIfIdle(timeout: self.idleTimeout)
            }
        }

        isRunning = true
    }

    public func stop() async {
        guard isRunning else { return }
        capture.stop()
        await engine.stop()
        eventTask?.cancel()
        idleTask?.cancel()
        partialCooldown?.cancel()
        eventTask = nil
        idleTask = nil
        partialCooldown = nil
        pendingPartial = nil
        store.clear()
        isRunning = false
        status = .stopped
        onStatus?(.stopped)
    }

    private func handle(_ event: CaptionEvent) {
        switch event {
        case .status(let s):
            status = s
            onStatus?(s)
        case .error(let message):
            onError?(message)
        case .partial(let text):
            applyPartial(text)
        case .final:
            partialCooldown?.cancel()
            partialCooldown = nil
            pendingPartial = nil
            store.apply(event)
        }
    }

    /// Leading-edge throttle: render now if idle, otherwise keep the newest text and flush when the cooldown ends.
    private func applyPartial(_ text: String) {
        guard partialCooldown == nil else {
            pendingPartial = text
            return
        }
        store.apply(.partial(text))
        partialCooldown = Task { [weak self] in
            try? await Task.sleep(for: .seconds(self?.partialInterval ?? 0.25))
            guard let self, !Task.isCancelled else { return }
            self.partialCooldown = nil
            if let pending = self.pendingPartial {
                self.pendingPartial = nil
                self.applyPartial(pending)
            }
        }
    }
}
