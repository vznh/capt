# Architecture

Capt is a pipeline with one seam in the middle.

```
SystemAudioTap            Core Audio process tap on the default output device. Mono float32 at device rate.
      │  AVAudioPCMBuffer, audio I/O thread
      ▼
SpeechAnalyzerEngine      Converts to the analyzer's format (AudioFormatConverter) and feeds Apple's
      │                   on-device SpeechAnalyzer. Emits CaptionEvent: partial, final, status, error.
      │  AsyncStream<CaptionEvent>
      ▼
CaptionSession            Owns one run: prepares the engine, starts capture, throttles partials to 250 ms,
      │                   runs the silence watchdog and the idle timer, unwinds everything on stop or failure.
      ▼
CaptionStore              Pure state on the main actor: strips sound annotations, keeps the last two
      │                   sentences, holds an optional preview text.
      ▼
CaptionView in CaptionPanel   A click-through NSPanel above every window draws the store's text.
```

`AppModel` sits beside the pipeline. It builds a session per run, owns settings, and exposes the state
the menu bar panel shows. `MenuPanelView` is the only place user intent enters.

## Boundaries

- `CaptionCore` (library) contains the middle of the pipeline: the two protocols, `CaptionSession`,
  `CaptionStore`, and their helpers. It imports no AppKit or SwiftUI.
- `Capt` (app) contains both ends: audio capture, the engine, the overlay, the panel, settings.

## Adding an engine

Conform to `TranscriptionEngine` (prepare, start, send, stop, and an event stream), then add a case to
`EngineKind` and return your engine from `make(locale:)`. The session, store, and views do not change.
A cloud engine would open its socket in `start()` and forward buffers from `send(_:)`.

## Threads

Audio arrives on a Core Audio queue. `SystemAudioTap` hands each buffer to the session's closure on
that queue, which computes the peak for the watchdog and calls `engine.send`. The engine converts and
yields on that same queue. Everything from the event stream onward runs on the main actor.
