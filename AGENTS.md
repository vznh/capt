# Repository rules

- Never push directly to `master`, including documentation, CI, and small fixes.
- Make all changes on a feature branch and open a pull request targeting `master`.
- Wait for the required **Build and verify** check to pass, then merge through GitHub.
- Do not bypass repository rules, force-push `master`, or change protection settings to permit a direct push.
- PRs and merged master commits build preview artifacts. Only `vX.Y.Z` tags publish releases.
- Follow CONTRIBUTING.md and RELEASE.md for validation and versioned releases.
