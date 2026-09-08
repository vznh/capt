#!/usr/bin/env python3
"""Prepare validated release metadata for the packaging workflow."""
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess


def release_target(ref, version, run_id, attempt, sha):
    if ref == "refs/heads/master":
        return f"master-{run_id}-{attempt}", f"Capt master {sha[:7]}", True
    tag = ref.removeprefix("refs/tags/")
    if not ref.startswith("refs/tags/") or not re.fullmatch(r"v\d+\.\d+\.\d+", tag):
        raise ValueError("Use master or a version tag in the form vX.Y.Z")
    if tag != f"v{version}":
        raise ValueError(f"Tag {tag} does not match Info.plist version {version}")
    return tag, f"Capt {version}", False


def main():
    with open("Resources/Info.plist", "rb") as source:
        version = plistlib.load(source)["CFBundleShortVersionString"]
    tag, name, prerelease = release_target(
        os.environ["GITHUB_REF"], version, os.environ["GITHUB_RUN_ID"],
        os.environ["GITHUB_RUN_ATTEMPT"], os.environ["GITHUB_SHA"],
    )
    result = subprocess.run(
        ["gh", "api", f"repos/{os.environ['GITHUB_REPOSITORY']}/releases/tags/{tag}"],
        capture_output=True, text=True,
    )
    existing = None
    if result.returncode == 0:
        existing = json.loads(result.stdout)
        if existing.get("immutable"):
            raise ValueError("This release is immutable; publish a new version to add downloads")
    elif "(HTTP 404)" not in result.stderr:
        raise RuntimeError(f"Cannot inspect release: {result.stderr.strip()}")

    notes = Path(".release-notes.md")
    if existing:
        # Preserve author-written notes and whether a release is still a draft.
        name = existing["name"] or tag
        prerelease = existing["prerelease"]
        notes.write_text(existing.get("body") or "")
    else:
        notes.write_text(
            f"Built from commit `{os.environ['GITHUB_SHA']}`.\n\n"
            "Requires **Apple Silicon (M1 or newer) and macOS 26+**.\n\n"
            "1. Download and open the DMG below.\n"
            "2. Drag Capt into Applications and open it.\n"
            "3. Click the menu bar icon, select the spoken language, and enable Capt.\n"
            "4. Allow System Audio Recording. The speech model may download on first use.\n\n"
            "**This build is ad-hoc signed and not notarized by Apple.** If you trust it and "
            "macOS blocks opening it, use System Settings → Privacy & Security → Open Anyway "
            "after trying to open Capt. See [Apple’s instructions](https://support.apple.com/en-us/102445).\n\n"
            "The ZIP is an alternative download. SHA-256 checksums and BUILD.txt are attached.\n"
        )
    output = {
        "tag": tag, "prerelease": str(prerelease).lower(),
        "draft": str(bool(existing and existing["draft"])).lower(),
        "generate_notes": str(not existing and not prerelease).lower(),
        "make_latest": "false" if prerelease or (existing and existing["draft"]) else "legacy",
    }
    # A release title can contain newlines; leave existing titles to the action.
    if not existing:
        output["name"] = name
    with open(os.environ["GITHUB_OUTPUT"], "a") as target:
        for key, value in output.items():
            target.write(f"{key}={value}\n")


if __name__ == "__main__":
    main()
