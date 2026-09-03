# Contributing

## Build and run

```sh
Scripts/run.sh            # release build, bundle build/Capt.app, launch it
Scripts/build.sh debug    # bundle only
swift build               # compile without bundling
```

Requires macOS 26 and Xcode 26. Always launch the bundled app with `open` or `Scripts/run.sh`,
never the raw binary, so macOS attributes the audio permission to Capt rather than your terminal.

The signing identity is chosen automatically: `build.sh` prefers a Developer ID Application or
Apple Development certificate from the keychain, falling back to ad-hoc with a warning that
privacy permissions may be re-requested after each rebuild. `CAPT_SIGN_IDENTITY` overrides the
choice; see [README.md](README.md#known-limitations).

## Layout rules

- `Sources/CaptionCore` holds protocols, caption state, and session orchestration. It never imports
  AppKit or SwiftUI.
- `Sources/Capt` is the app. Each folder is one role: audio capture, transcription engines, overlay,
  settings, permissions, and the menu bar panel.
- A new speech backend conforms to `TranscriptionEngine` and gets a case in `EngineKind`. Nothing
  else should need to change.
- One primary type per file, named after the type, with a `///` comment on it explaining its role.

## Commits

One concise sentence in the imperative, describing the change. No trailers, no co-author lines.
Each commit builds on its own.

## Releases

Tag `v<semver>` and bump `CFBundleShortVersionString` in `Resources/Info.plist` to match.
Release notes live on the GitHub release, not in a changelog file.

## Reporting problems

Open a GitHub issue with your macOS version, whether the System Audio Recording permission was
granted, and what was playing. Security or privacy concerns go to the address in
[SECURITY.md](SECURITY.md) instead.
