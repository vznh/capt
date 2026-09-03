import AudioToolbox
import AVFoundation
import CaptionCore
import OSLog

/// Captures everything the system plays, as a mono mixdown, via a Core Audio process tap
/// (macOS 14.2+). Requires `NSAudioCaptureUsageDescription` in Info.plist; without the
/// permission the tap silently returns zeros (see `SilenceWatchdog`).
final class SystemAudioTap: AudioCapturing {
    private let logger = Logger(subsystem: kAppSubsystem, category: "SystemAudioTap")
    private let queue = DispatchQueue(label: "capt.audio-tap", qos: .userInitiated)

    private var tapID: AudioObjectID = .unknown
    private var aggregateDeviceID: AudioObjectID = .unknown
    private var ioProcID: AudioDeviceIOProcID?
    private(set) var format: AVAudioFormat?
    private static let preferredBufferFrames: UInt32 = 256

    func start(onBuffer: @escaping @Sendable (AVAudioPCMBuffer) -> Void) throws {
        guard ioProcID == nil else { return }

        // Resolve object IDs at use time: they are recycled across device changes.
        let description = CATapDescription(monoGlobalTapButExcludeProcesses: [])
        description.uuid = UUID()
        description.name = "Capt"
        description.isPrivate = true
        description.muteBehavior = .unmuted

        var newTapID: AudioObjectID = .unknown
        var err = AudioHardwareCreateProcessTap(description, &newTapID)
        guard err == noErr else { throw "Failed to create process tap: \(err)" }
        tapID = newTapID

        var streamDescription = try tapID.readAudioTapStreamBasicDescription()
        guard let tapFormat = AVAudioFormat(streamDescription: &streamDescription) else {
            throw "Unsupported tap stream format"
        }
        format = tapFormat
        logger.info("Tap format: \(tapFormat, privacy: .public)")

        let outputID = try AudioObjectID.readDefaultSystemOutputDevice()
        let outputUID = try outputID.readDeviceUID()

        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Capt Tap",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapDriftCompensationKey: true,
                kAudioSubTapUIDKey: description.uuid.uuidString,
            ]],
        ]

        err = AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateDeviceID)
        guard err == noErr else {
            teardown()
            throw "Failed to create aggregate device: \(err)"
        }

        // Smaller I/O buffers mean audio reaches the analyzer sooner. ~5 ms at 48 kHz. Best effort.
        do {
            try aggregateDeviceID.write(kAudioDevicePropertyBufferFrameSize, value: Self.preferredBufferFrames)
        } catch {
            logger.warning("Could not set buffer frame size: \(error.localizedDescription, privacy: .public)")
        }

        err = AudioDeviceCreateIOProcIDWithBlock(&ioProcID, aggregateDeviceID, queue) { _, inputData, _, _, _ in
            guard let buffer = AVAudioPCMBuffer(pcmFormat: tapFormat, bufferListNoCopy: inputData, deallocator: nil) else { return }
            onBuffer(buffer)
        }
        guard err == noErr else {
            teardown()
            throw "Failed to create IO proc: \(err)"
        }

        err = AudioDeviceStart(aggregateDeviceID, ioProcID)
        guard err == noErr else {
            teardown()
            throw "Failed to start aggregate device: \(err)"
        }
        logger.info("Tap running")
    }

    func stop() {
        teardown()
    }

    private func teardown() {
        if aggregateDeviceID.isValid {
            if let ioProcID {
                AudioDeviceStop(aggregateDeviceID, ioProcID)
                AudioDeviceDestroyIOProcID(aggregateDeviceID, ioProcID)
                self.ioProcID = nil
            }
            AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
            aggregateDeviceID = .unknown
        }
        if tapID.isValid {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = .unknown
        }
        format = nil
    }

    deinit { teardown() }
}
