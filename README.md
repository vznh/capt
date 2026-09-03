# Capt

Live, on-device captions for anything your Mac is playing. A menu bar app that taps system audio,
transcribes it with Apple's SpeechAnalyzer (macOS 26), and draws YouTube-style captions in a
click-through overlay that floats above every window, including fullscreen video.

Born from watching videos on sites that don't ship captions. Accessibility first.

## Requirements

- macOS 26 or newer (SpeechAnalyzer). The Core Audio process tap needs 14.2+.
- Xcode 26 command line tools.

## Build and run

```sh
Scripts/run.sh            # release build, bundles build/Capt.app, launches it
Scripts/build.sh debug    # bundle only
swift test                # CaptionCore unit tests, no AppKit needed
```

Click the menu bar icon and choose **Start Captions** (⇧⌘C). The first run asks for
**System Audio Recording** permission and downloads the speech model for your language.

## Layout

Modeled on open-source macOS caption apps (Korus, mac-live-captions/caption-core, subtitles,
OpenCaptions, overwhisper). UI-free logic lives in a separate package so it can be tested without AppKit.

```
Package.swift
Sources/
  CaptionCore/            # library, no AppKit
    Protocols.swift       # TranscriptionEngine, AudioCapturing, CaptionEvent
    CaptionStore.swift    # text on screen, capped to the last two sentences
    SentenceSplitter.swift # language-agnostic sentence boundaries (NaturalLanguage)
    CaptionSession.swift  # capture -> engine -> store lifecycle
    SilenceWatchdog.swift # detects a permission-less tap (silent, no error)
  Capt/                   # the app
    App/                  # @main, AppDelegate, AppModel, menu bar
    Audio/                # SystemAudioTap (Core Audio process tap), format conversion
    Transcription/        # EngineKind, SpeechAnalyzerEngine
    Overlay/              # CaptionPanel (NSPanel), CaptionView (SwiftUI)
    Settings/             # UserDefaults-backed preferences
    Permissions/          # deep link to the audio recording pane
Resources/                # Info.plist, entitlements
Scripts/                  # build.sh bundles the .app, run.sh launches it
Tests/CaptionCoreTests/
```

Adding a backend: conform to `TranscriptionEngine`, add a case to `EngineKind`.

## Caption style

Fill at 40% opacity, text at 80% opacity, at most two sentences, tail-anchored so the newest words stay
visible. Dark (black on white text) and Light (inverse) themes in the Appearance menu.

## Known limitations

- **Language is chosen, not detected.** SpeechAnalyzer needs a locale up front. Pick it in the
  Language menu. Auto-detection needs a cloud engine (Deepgram Nova-3 multilingual) behind the same protocol.
- **Ad-hoc signing resets permissions on every rebuild.** macOS keys the audio-capture grant to the
  code hash. Set `CAPT_SIGN_IDENTITY` to a Developer ID to keep it. Always launch via `open`, never the raw binary.
- If captions never appear and the status says no audio is reaching Capt, grant System Audio Recording
  in System Settings › Privacy & Security.

## Credits

Core Audio property helpers adapted from [insidegui/AudioCap](https://github.com/insidegui/AudioCap) (MIT).
