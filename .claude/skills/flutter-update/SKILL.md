---
skill: enabled
name: flutter-update
description: Pin a new Flutter SDK, refresh the dependencies and write the pull request summary. Driven by the "Flutter update" GitHub Action.
---

# flutter-update skill

Upgrade QuaX to the Flutter version passed as argument, or to the one `flutter --version` reports if
none was given. Take the Dart version from `dart --version`.

You only edit files. The workflow commits, pushes and opens the pull request from your summary file,
so run no `git` or `gh` command yourself.

## Update the pins

`.fvmrc`, `environment.flutter` and `environment.sdk` in `pubspec.yaml` (both exact), the Flutter
version in `CLAUDE.md`, the Flutter badge in `README.md`, and anything version-related in `docs/`.
`docs/QuaX.md` links into `pubspec.yaml` by line number, so re-check those anchors still point at
the right lines.

## Upgrade the dependencies

`flutter pub upgrade --major-versions` rewrites constraints, so re-read `git diff pubspec.yaml`
afterwards and restore every pin or `dependency_overrides` entry it dropped.

Then challenge each one, because an upgrade is exactly when its reason expires: re-read the comment,
check whether it still describes reality, and take the entry out when it does not. `flutter pub get`
catches the resolution conflicts and the verification build catches the rest, so put back only what
actually breaks. Every override is a liability, so aim to leave fewer behind than you found. Say in
the summary which ones you dropped and which you kept, with the reason. Remove comments if they
don't apply anymore.

## Verify

Run the codegen from `CLAUDE.md`, then `flutter analyze` and `flutter build apk --debug`.
Fix all issues until it succeeds. The tests must also pass. The workflow re-runs both as a gate and
opens no pull request if either fails.

Never touch the `version:` line, `changelog.md` or `release-notes.md`.

## Write the summary

Write `/tmp/flutter-update-pr.md`:

- **First line**: the commit message, reused as the pull request title, e.g.
  `Upgraded Flutter to 3.47.2 and refreshed the dependencies`. It goes into the release notes
  verbatim, so keep it to one short line written for users.
- **Everything after it**: the pull request body, in markdown. Cover the version changes, the
  notable dependency bumps, the source changes you made and why, any pin you relaxed, and what a
  human should test by hand. The workflow appends `flutter pub outdated` to it.
