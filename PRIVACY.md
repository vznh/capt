# Capt Privacy Policy

**Version 1.2. Effective 2026-09-03.**

Capt is a macOS app made by 5f ("we", "us"). It listens to the audio your Mac is playing and shows live captions on your screen. This policy explains the app's current data practices.

The short version: **Capt does not track you or collect your data. Nothing you play, say, or read leaves your Mac.** Capt has no servers, accounts, analytics, telemetry, advertising, or crash reporting.

## 1. What Capt processes, and where

| Data | What happens to it | Where it lives |
|---|---|---|
| System audio (everything your Mac is playing) | Captured through Apple's Core Audio process tap and fed to Apple's on-device speech recognizer only while Capt is switched on | Memory only; never written to disk, never transmitted |
| Captions (the recognized text) | Shown in the overlay for a few seconds, then discarded | Memory only; Capt keeps no transcript or history |
| Local preferences (language, appearance and reading options, engine, caption layouts, and total word count) | Stored so Capt remembers your choices and can show your all-time word count | Your Mac's user defaults for Capt; never sent to us |

Capt processes the items above only to provide its features. We do not receive or collect them. Capt does not transmit audio, transcripts, preferences, keystrokes, screen contents, contacts, location, device identifiers, or usage information.

## 2. Things Capt does not do

- **No uploads.** Audio and captions are processed entirely on your Mac using Apple's SpeechAnalyzer.
- **No storage of captions.** Capt never saves what it hears or shows.
- **No voiceprints or speaker identification.** Capt does not create biometric identifiers of any kind.
- **No selling or sharing of personal information.** We receive none, so there is nothing to sell or share.
- **No tracking.** Capt has no advertising, analytics, telemetry, cookies, fingerprinting, or third-party SDKs.

## 3. Network activity you may see

Capt itself makes no network requests. Two things outside Capt can:

- **Speech model downloads.** The first time you pick a language, macOS downloads Apple's on-device speech model for it from Apple. That request is made by macOS under [Apple's privacy policy](https://www.apple.com/legal/privacy/), not by us. We receive nothing from it.
- **Links you open.** The Permissions and Legal rows open System Settings or a web page in your browser. Those destinations have their own policies.

## 4. Permissions Capt asks for

- **System Audio Recording.** Required to hear what your Mac plays. macOS shows an indicator while capture is active. You can revoke this at any time in System Settings, Privacy & Security, and Capt will stop captioning.

Capt never asks for the microphone, camera, screen contents, contacts, or location.

## 5. Recording other people

Capt captures whatever your Mac is playing, which can include phone calls, FaceTime, video meetings, and other people's voices. Recording or transcribing a private conversation without the consent of everyone in it is illegal in many places, including California and roughly a dozen other US states, and in much of the EU and UK.

**You are responsible for how you use Capt.** Do not use it to capture calls, meetings, or conversations unless everyone involved has agreed. Capt is a captioning aid, not a call recorder, and it keeps no recording.

## 6. Future versions

This policy describes the current version of Capt. Installing or using it does not consent to any future data collection. If a future version changes these practices, we will update this policy before collection begins, clearly disclose what changed, and ask for consent where required.

## 7. Your rights

Because we hold no Capt data about you, there is no server-side profile to access, correct, export, or delete. Capt's local preferences remain under your control on your Mac and can be removed with the app's preferences. You may contact us with any privacy question or request.

## 8. Children

Capt is not directed at children under 13. We do not collect personal information from children or anyone else through Capt.

## 9. Security

Audio and captions never leave your Mac, so their security is your Mac's security. We recommend keeping macOS up to date and using FileVault.

## 10. Changes to this policy

We will post any change here with a new version number and effective date. A change to this document alone will not silently enable data collection in an installed version of Capt.

## 11. Contact

Privacy questions, requests, or complaints: **5thf@proton.me**.
Legal entity: **5f**.

Source code: https://github.com/vznh/capt
