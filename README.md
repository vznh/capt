# Capt

Live, on-device captions for anything your Mac is playing.

Capt is a menu bar app that taps system audio, transcribes it with Apple's SpeechAnalyzer on macOS 26,
and draws YouTube-style captions in a click-through overlay that floats above every window, including
fullscreen video. Nothing leaves your Mac. Capt has no accounts, advertising, analytics, telemetry,
crash reporting, or other tracking.

Born from watching videos on sites that don't ship captions. Accessibility first.

## Requirements

- macOS 26 or newer. SpeechAnalyzer is the on-device recognizer; the Core Audio process tap needs 14.2+.
- Xcode 26 to build.

## Build and run

```sh
Scripts/run.sh            # release build, bundles build/Capt.app, launches it
Scripts/build.sh debug    # bundle only
```

Click the menu bar icon and flip the **Capt** switch. The first run asks for **System Audio Recording**
permission and downloads the speech model for your language.

## Using it

- **Language** picks the recognition locale. Capt cannot auto-detect the spoken language.
- **Theme** is System, Dark, or Light. **Text Size** opens a size menu; hover it and scroll to adjust
  while a sample caption shows on screen.
- **Resize** dims the screen and lets you drag the caption box by its edges to change its width and
  height, or drag its middle to move it. Done saves, Cancel restores, Reset returns the default. The
  box is remembered per display.
- Hold ⌘ with the panel open to see how many words Capt has transcribed.

## How it works

System audio → Core Audio process tap → Apple SpeechAnalyzer → session → store → overlay.
The full picture, including where a new engine plugs in, is in [ARCHITECTURE.md](ARCHITECTURE.md).

## Layout

Modeled on open-source macOS caption apps (Korus, mac-live-captions/caption-core, subtitles,
OpenCaptions, overwhisper). UI-free logic lives in a separate package, kept free of AppKit.

```
Package.swift             # CaptionCore library + Capt executable
Sources/
  CaptionCore/            # protocols, CaptionStore, CaptionSession, sentence and filter helpers
  Capt/
    App/                  # @main, AppDelegate, AppModel, links, scroll modifier
    App/Panel/            # menu bar panel: view, style tokens, row building blocks
    Audio/                # SystemAudioTap (Core Audio process tap), format conversion
    Transcription/        # EngineKind, SpeechAnalyzerEngine
    Overlay/              # CaptionPanel + CaptionView, OverlayController, resize mode (dim, handles, HUD)
    Settings/             # UserDefaults-backed preferences and per-display caption frames
    Permissions/          # deep link to the audio recording pane
Resources/                # Info.plist, entitlements
Scripts/                  # build.sh bundles the .app, run.sh launches it
ARCHITECTURE.md CONTRIBUTING.md SECURITY.md
LICENSE NOTICE PRIVACY.md TERMS.md
```

## Caption style

Fill at 40% opacity and text at 80% opacity. Sentences stack upward from the newest caption, while long
sentences wrap at word boundaries instead of being truncated. Older lines roll off the top when the
caption region fills. The box hugs its text and is centered. Nothing animates, and partial results
redraw at most every 250 ms. A one-point text edge keeps glyphs legible over bright video. Reduce
Transparency raises the fill to 90%; Increase Contrast makes the text fully opaque.

## Known limitations

- **Language is chosen, not detected.** SpeechAnalyzer needs a locale up front. Auto-detection needs a
  cloud engine behind the same protocol.
- **Signing identity is chosen automatically.** `build.sh` prefers a Developer ID Application or
  Apple Development certificate from the keychain, so the code signature (and the System Audio
  Recording grant keyed to it) survives rebuilds. `CAPT_SIGN_IDENTITY` overrides the choice;
  `-` forces ad-hoc, and the script warns that permissions may be re-requested after each rebuild.
- If captions never appear and the panel says no audio is being detected, grant System Audio Recording
  in System Settings › Privacy & Security.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Security and privacy reports go to [SECURITY.md](SECURITY.md).

## License and legal

Capt is source-available under the [Functional Source License 1.1, MIT Future License](LICENSE):
use, modify, and redistribute it for any purpose except building a competing commercial product,
and each version becomes MIT-licensed two years after release. Third-party notices are in
[NOTICE](NOTICE); Core Audio helpers are adapted from
[insidegui/AudioCap](https://github.com/insidegui/AudioCap), BSD 2-Clause. End-user terms are in
[TERMS.md](TERMS.md) and the privacy policy in [PRIVACY.md](PRIVACY.md).
