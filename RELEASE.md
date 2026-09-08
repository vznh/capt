# Releasing Capt

Capt distributes a standalone macOS app. Users download a DMG, drag Capt into Applications,
and open it. They do not need Swift, Xcode, or the source repository. ZIP downloads are also
provided. Builds currently target the build machine's architecture; filenames identify it.
macOS 26 or newer is required.

## Pull request builds

[Build Capt](https://github.com/vznh/capt/actions/workflows/build.yml) builds every PR
when opened, reopened, or updated with new commits, including draft PRs. It tests the PR's
merge commit against the target branch and verifies the same DMG, ZIP, and checksums as release
builds. A newer update cancels an older in-progress build for that PR.

Open the PR's **Checks → Build and verify → Details**, then follow **Download preview build**
in the run summary (or download the artifact at the bottom of the Actions run). GitHub sign-in
is required. Downloads expire after 30 days and include both PR head and tested merge commits
in `BUILD.txt`. Builds usually take 2–5 minutes plus runner queue time.

This workflow has read-only repository permissions, uses no Apple signing secrets, and does
not create releases or post comments. Downloads are ad-hoc signed development builds requiring
Apple Silicon and macOS 26+. Fork contributions may need a maintainer to approve the Actions
run; PRs with merge conflicts must resolve them before GitHub can run the merge build.

## Master verification

Merging a PR into `master` runs the same read-only **Build Capt** workflow again on the merged
commit. It creates verified preview artifacts but never publishes a GitHub release.
Version tags are the only automatic release trigger. Existing historical master prereleases
are retained, but new master pushes no longer create them.

## Branch policy

Never push directly to `master`, including documentation fixes. Work on a feature branch,
open a PR, wait for **Build and verify** to pass, and merge through GitHub. The repository
ruleset requires a PR with passing checks and up-to-date code, with no bypass actors.
It does not require a second person's approval, so a solo maintainer can merge a passing PR.
Force pushes and deletion of `master` are also blocked.

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

The **Package Capt** release workflow runs when you push a `vX.Y.Z` tag. It uses
[softprops/action-gh-release](https://github.com/softprops/action-gh-release), pinned to v3.0.3,
to create the release and upload its DMG, ZIP, checksums, and build metadata.

1. Update `CFBundleShortVersionString` in `Resources/Info.plist` (for example, `0.2.0`)
   and increment `CFBundleVersion`.
2. Commit on a feature branch, open a PR, and merge it after checks pass.
   Update your local checkout to the merged `master` commit.
3. Run `Scripts/release.sh`. It checks that your clean checkout matches remote `master`,
   creates the matching version tag if needed, and pushes it. GitHub handles packaging.

Equivalent tagging commands, after updating the version and pushing the commit:

```sh
git tag v0.2.0
git push origin v0.2.0
```

A tag must exactly match the app version. Invalid or mismatched version tags fail before
compilation. New versioned releases get installation instructions and generated release notes;
GitHub determines Latest by its date/version rules (`make_latest: legacy`). Master builds only produce preview artifacts.

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
