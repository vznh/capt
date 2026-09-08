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
on `master` or an existing version tag. Builds usually take about 3–8 minutes, plus any runner queue time.

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

## Versioned GitHub releases

The same workflow also runs when you push a `vX.Y.Z` tag. It uses
[softprops/action-gh-release](https://github.com/softprops/action-gh-release), pinned to v3.0.3,
to create the release and upload its DMG, ZIP, checksums, and build metadata.

1. Update `CFBundleShortVersionString` in `Resources/Info.plist` (for example, `0.2.0`)
   and increment `CFBundleVersion`.
2. Commit and push the changes to `master`.
3. Run `Scripts/release.sh`. It checks that your clean checkout matches remote `master`,
   creates the matching version tag if needed, and pushes it. GitHub handles packaging.

Equivalent tagging commands, after updating the version and pushing the commit:

```sh
git tag v0.2.0
git push origin v0.2.0
```

A tag must exactly match the app version. Invalid or mismatched version tags fail before
compilation. New versioned releases get installation instructions and generated release notes;
GitHub determines Latest by its date/version rules (`make_latest: legacy`). Master builds remain
prereleases and never become Latest.

If a release already exists, its notes, title, draft status, and prerelease status are preserved.
The action attaches missing files and skips existing filenames (`overwrite_files: false`).
Re-running a job therefore does not replace files people already downloaded. For an intentional
binary update, bump the app version and create a new tag. Immutable published releases cannot
accept new assets; the workflow stops with an explanation.

To attach packages to an existing tag, select **Run workflow** and choose that tag, provided
its commit contains this workflow and matches the bundle version. Tags from before this workflow
was added, including the original `0.1` release, retain their existing manual downloads.
A tag created by GitHub Actions using `GITHUB_TOKEN` does not trigger another push workflow;
create version tags from your terminal as above.

These CI downloads are currently **ad-hoc signed and not notarized**, including versioned
releases. Developer ID signing and notarization remain a separate setup; `Scripts/package.sh release`
still supports notarized local packaging. `Scripts/release.sh` now triggers CI and no longer
builds a notarized draft on your Mac.

The scripts never store signing keys in Git. A future CI workflow can run the same packaging
script with a temporary signing Keychain and protected secrets. Automatic updates and Homebrew
are separate distribution features; neither is required to install or run Capt.

References: [Apple notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
and [customizing notarization](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).
