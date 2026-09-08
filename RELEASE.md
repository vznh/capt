# Releasing Capt

Capt distributes a standalone macOS app. Users download a DMG, drag Capt into Applications,
and open it. They do not need Swift, Xcode, or the source repository. ZIP downloads are also
provided. Builds currently target the build machine's architecture; filenames identify it.
macOS 26 or newer is required.

## Automatic master builds

Every push to `master` runs [Package Capt](https://github.com/vznh/capt/actions/workflows/package.yml)
on a GitHub-hosted Apple Silicon macOS 26 runner. It builds the pushed commit, verifies the
app signature, archives, and checksums, and publishes a separate **prerelease** with a DMG,
ZIP, checksums, and source/build metadata. No signing secrets are needed for these ad-hoc builds.

Find public downloads on the [releases page](https://github.com/vznh/capt/releases).
Each successful run gets a unique `master-<run-id>-<attempt>` tag at its source commit;
reruns cannot overwrite another build. These builds do not replace the stable Latest release.
The same files are also retained as Actions artifacts for 30 days. Prerelease assets remain
available until the release is deleted. GitHub may require sign-in to download Actions artifacts.

There is no path filter or cancellation of older pushes: each pushed commit gets a build.
A failed check stops publication. Inspect the failed Actions run and choose **Re-run failed jobs**
after resolving a transient runner problem, or push a fix. You can also run the workflow manually
on `master`. Builds usually take about 3–8 minutes, plus any runner queue time.

These are development downloads, not notarized releases. Users may need the first-launch
exception described in their release notes. Stable notarized releases use the setup below.

## Local packaging

```sh
Scripts/package.sh local
open build/packages
```

Builds a release app and creates a DMG with an Applications shortcut, a ZIP, and SHA-256
checksums. Filenames include `-local`: these downloads are not notarized for public distribution.
The app itself is at `build/Capt.app`. This uses the installed Swift toolchain and available
macOS SDK; public notarization also needs full Xcode.

## One-time public release setup

1. Install Xcode 26 or newer and select its developer directory (for example, set
   `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` in your shell).
2. Enroll in the Apple Developer Program and install a **Developer ID Application**
   certificate with its private key in your login Keychain.
3. Store notarization credentials in Keychain using the interactive prompt:

   ```sh
   xcrun notarytool store-credentials Capt-notary
   ```

   Supply the requested Apple ID, team ID, and app-specific password privately in Terminal.
   Never put credentials in this repository or chat.
4. Set these non-secret configuration values:

   ```sh
   export CAPT_SIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)'
   export CAPT_NOTARY_PROFILE=Capt-notary
   ```

The distribution mode requires a full certificate name, not a SHA-1 hash. Local builds still
support the existing automatic identity selection and hash override.

## Produce public downloads

```sh
Scripts/package.sh release
```

This builds with hardened runtime and a secure timestamp, submits the app to Apple,
staples and validates its ticket, checks Gatekeeper, packages and notarizes the DMG,
and creates a ZIP of the stapled app. Final files and checksums live in `build/packages/`.
Apple submissions require network access and can take several minutes or longer.
The script stops on signing, notarization, or validation failures. For a rejected submission,
use `xcrun notarytool log SUBMISSION_ID --keychain-profile Capt-notary` to inspect Apple's report.

## Publish on GitHub

1. Update `CFBundleShortVersionString` and increment `CFBundleVersion` in
   `Resources/Info.plist`; commit the release changes.
2. Create and push the matching tag, for example `git tag v0.1.0` followed by
   `git push origin v0.1.0` (substitute the actual version).
3. Run `Scripts/release.sh` with an authenticated GitHub CLI. It requires a clean checkout
   at the tagged commit, builds fresh notarized packages, and uploads a **draft** release
   to `vznh/capt` with generated release notes.
4. Review the draft and test the downloaded app on another Mac before clicking Publish.

The scripts never store signing keys in Git. A future CI workflow can run the same packaging
script with a temporary signing Keychain and protected secrets. Automatic updates and Homebrew
are separate distribution features; neither is required to install or run Capt.

References: [Apple notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
and [customizing notarization](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).
