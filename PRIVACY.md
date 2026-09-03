# Capt Privacy Policy

**Version 1.0. Effective 2026-09-03.**

Capt is a macOS app made by vznh ("we", "us"). It listens to the audio your Mac is playing and shows live captions on your screen. This policy explains what Capt does with data, what it does not do, and how we will handle any future change to that.

The short version: **today, nothing you play, say, or read leaves your Mac.** Capt has no servers, no accounts, and no analytics.

## 1. What Capt processes, and where

| Data | What happens to it | Where it lives |
|---|---|---|
| System audio (everything your Mac is playing) | Captured through Apple's Core Audio process tap and fed to Apple's on-device speech recognizer only while Capt is switched on | Memory only; never written to disk, never transmitted |
| Captions (the recognized text) | Shown in the overlay for a few seconds, then discarded | Memory only; Capt keeps no transcript or history |
| Settings (language, theme, text size, engine) | Stored so Capt remembers your preferences | Your Mac's user defaults for Capt |

Capt does not collect, store, or transmit audio, transcripts, keystrokes, screen contents, contacts, location, device identifiers, or usage analytics. There is no crash reporting and no telemetry.

## 2. Things Capt does not do

- **No uploads.** Audio and captions are processed entirely on your Mac using Apple's SpeechAnalyzer.
- **No storage of captions.** Capt never saves what it hears or shows.
- **No voiceprints or speaker identification.** Capt does not create biometric identifiers of any kind.
- **No selling or sharing of personal information.** We hold none, so there is nothing to sell or share.
- **No advertising, no trackers, no third-party SDKs.**

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

## 6. Optional data programs we may offer in the future

We may later offer an optional program, for example "Improve Capt", that collects captions, audio snippets, or usage data to improve recognition accuracy, develop new features, and support Capt's development. That could include commercial uses such as training and evaluating speech models or licensing aggregated, de-identified datasets.

If we ever do this, all of the following will apply:

1. **Opt-in only.** It will be off by default and switched on only by an explicit, affirmative action inside Capt. Ignoring or dismissing a prompt means no.
2. **Nothing retroactive.** It can only apply to data processed after you opt in. We will never apply a data-collection change to earlier use or to users who have not opted in.
3. **Told in advance.** We will publish an updated version of this policy that describes exactly what is collected, why, how long it is kept, and who it is shared with, before the feature is available.
4. **Easy to leave.** You can opt out at any time from inside Capt. Opting out stops collection immediately, and you can ask us to delete data already collected.
5. **Consumer privacy rights honored.** Where laws such as the California Consumer Privacy Act apply, we will treat captions as sensitive personal information, offer the right to limit their use, and honor opt-outs of sale or sharing. Where the GDPR or UK GDPR applies, the program will run on your consent, which you can withdraw, and we will complete a data protection impact assessment before launch.
6. **Never calls or other people's audio.** Any program will exclude, by design and by rule, audio that you do not have the right to share.

Until such a program exists and you have joined it, sections 1 and 2 describe everything Capt does.

## 7. Your rights

Because Capt holds no data about you on any server, requests to access, correct, export, or delete personal data are satisfied by your own Mac. To remove everything Capt stores, quit Capt and delete the app and its preferences. If you are in California, the EU, the UK, or another jurisdiction with a privacy law, you have the rights those laws provide, and you can exercise them by contacting us at the address below. We will not discriminate against you for doing so.

## 8. Children

Capt is not directed at children under 13, and we do not knowingly collect personal information from them. If you believe a child has provided us data, contact us and we will delete it.

## 9. Security

Audio and captions never leave your Mac, so their security is your Mac's security. We recommend keeping macOS up to date and using FileVault.

## 10. Changes to this policy

We will post any change here with a new version number and effective date. If a change would let Capt collect or share more data than before, it will not take effect for you until you have seen an in-app notice and agreed to it, as described in section 6.

## 11. Contact

Privacy questions, requests, or complaints: **[privacy contact email]**.
Legal entity: **[legal name or entity]**, [jurisdiction].

Source code: https://github.com/vznh/capt
