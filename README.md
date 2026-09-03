# Capt

Live, on-device captions for anything your Mac is playing.

Capt is a menu bar app that taps system audio, transcribes it with Apple's on-device SpeechAnalyzer,
and draws YouTube-style captions in a click-through overlay above every window, including fullscreen
video. Capt has no servers, accounts, advertising, analytics, telemetry, crash reporting, or other
tracking. Audio and caption text stay in memory and are never saved or sent anywhere.

Born from watching videos on sites that don't ship captions. Accessibility first.

## Requirements

- macOS 26 or newer. SpeechAnalyzer is the on-device recognizer.
- Xcode 26 to build.

## Build and run

```sh
Scripts/run.sh            # release build, bundles build/Capt.app, launches it
Scripts/build.sh debug    # bundle only
```

Click the menu bar icon and flip the **Capt** switch. On first use, macOS asks for **System Audio
Recording** permission and downloads Apple's on-device speech model for the selected language if it
is not already installed.

## Using it

- **Language** picks the recognition locale. Capt cannot auto-detect the spoken language. A cloud
  download icon marks languages whose on-device model is not installed yet.
- **Theme** is System, Dark, or Light. **Text Size** opens a size menu; hover it and scroll to adjust
  while a sample caption shows on screen.
- **Resize** dims the screen and lets you drag the caption box by its edges to change its width and
  height, or drag its middle to move it. Done saves, Cancel restores, Reset returns the default. The
  box defines the maximum caption area and is remembered per display. Return confirms and Escape
  cancels too.
- **Additional…** opens **Adjustments** for fill and text opacity, plus **Accessibility** for an
  experimental Bionic-style mode that bolds the beginning of each word.
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

Fill defaults to 40% opacity and text to 80%; both are adjustable. Capt keeps the three newest
sentences in a first-in, first-out queue, draws hard sentence breaks on separate rows, and limits the
visible block to three text rows. New text enters at the bottom and older overflow leaves from the top.
Long sentences wrap at word boundaries instead of showing an ellipsis. The centered box hugs its text,
caption changes do not animate, and partial results redraw at most every 250 ms. A subtle text edge
keeps glyphs legible over bright video. Reduce Transparency raises the fill to 90%; Increase Contrast
makes the text fully opaque.

## Known limitations

- **Language is chosen, not detected.** SpeechAnalyzer needs a locale up front. Auto-detection needs a
  cloud engine behind the same protocol.
- **The overlay uses the primary display.** Layouts are stored per display, but Capt currently shows
  its caption panel only on the display macOS treats as primary.
- **Signing identity is chosen automatically.** `build.sh` prefers a Developer ID Application or
  Apple Development certificate from the keychain, so the code signature (and the System Audio
  Recording grant keyed to it) survives rebuilds. `CAPT_SIGN_IDENTITY` overrides the choice;
  `-` forces ad-hoc, and the script warns that permissions may be re-requested after each rebuild.
- **Local builds are not notarized.** The build script produces a hardened, signed app for local use;
  distributing it through Gatekeeper requires a separate notarization workflow.
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
