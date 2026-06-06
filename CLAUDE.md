# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**QuaX** (formerly Quacker) is a privacy-focused Flutter/Dart client for X (formerly Twitter), forked from Quacker/Fritter. It has no external trackers, stores all data locally in SQLite, and uses reverse-engineered X API endpoints.

## Build & Development Commands

Use `fvm flutter` instead of raw `flutter` to enforce the pinned SDK version (3.44.1).

```bash
# Install the pinned Flutter SDK and activate it for this project
fvm install
fvm use

# Generate launcher icon assets
python -mvenv .venv
bash -c '
  source ./.venv/bin/activate
  pip install -r requirements.txt
  python generate_icons.py
'

# Run all build steps through fvm so the pinned SDK is used
fvm flutter pub get
fvm dart run flutter_launcher_icons
fvm dart run dart_pubspec_licenses:generate
fvm dart run intl_utils:generate
fvm dart run flutter_iconpicker:generate_packs --packs material
fvm flutter build apk --debug
```

## Architecture

### State Management

All state is managed with **flutter_triple** `Store<T>` objects. Each feature has a `*_model.dart` that extends `Store` and uses `execute()` for async operations. UI widgets observe these stores via `ScopedBuilder` / `TripleBuilder`. **Do not use setState or ChangeNotifier** — use the Store pattern throughout.

### Feature-based Structure (`lib/`)

Each feature folder contains its screen(s) and its model:

| Folder | Description |
|---|---|
| `client/` | X API client wrappers (authenticated + unauthenticated) |
| `database/` | SQLite repository, entity classes, schema migrations |
| `home/` | Home screen with tab navigation |
| `profile/` | User profile view |
| `tweet/` | Tweet card rendering, threads, video playback |
| `search/` | Search for tweets and users |
| `trends/` | Trending topics |
| `subscriptions/` | Followed users management |
| `group/` | Subscription groups (custom feeds) |
| `saved/` | Offline saved tweets |
| `settings/` | App preferences |
| `utils/` | Shared helpers (downloads, caching, deep linking) |
| `generated/` | Auto-generated localization — do not edit manually |

### API Layer (`lib/client/`)

The X API is **reverse-engineered** — endpoints, tokens, and headers may change without notice. Always use safe null-coalescing access when parsing JSON responses:

```dart
// Good — safe against missing fields
final text = result["data"]?["text"] as String?;
final count = result["legacy"]?["favorite_count"] as int? ?? 0;

// Bad — will throw if field is absent
final text = result["data"]["text"] as String;
```

`client.dart` wraps `dart_twitter_api` and adds caching via `FFCache`. `client_unauthenticated.dart` uses a hardcoded bearer token from `constants.dart`; `client_regular_account.dart` uses stored OAuth credentials.

### Database (`lib/database/`)

`repository.dart` is the single access point for SQLite (via `sqflite`). Schema changes must go through `sqflite_migration_plan` migrations — never alter the schema outside of a migration. Key entities: `Subscription`, `SubscriptionGroup`, `SavedTweet`, `Account`.

### Navigation

Routes are defined as constants in `constants.dart` (`routeHome`, `routeProfile`, etc.) and registered in `main.dart`. Deep links from x.com URLs are parsed in `utils/urls.dart` into sealed `ProfileUriInfo` / `PostUriInfo` classes, then navigated in `main.dart`.

### Localization

Strings live in `lib/l10n/*.arb` files. The `L10n` class in `lib/generated/l10n.dart` is auto-generated — run `fvm dart run intl_utils:generate` after editing ARB files. Access via `L10n.of(context).someKey`.

### Coding Style

- Prefer functional patterns: immutable data, pure functions, `map`/`where`/`fold` over imperative loops. Avoid mutable state outside of Store objects.
- Always split responsibilities
- Avoid functions of more than 30 lines (except for some widget builders)
- NEVER insert raw strings in the code if they are displayed on the UI, always use translated strings in arb files
- Anytime when you are about to copy/paste code from somewhere, think about refactoring instead. Ask me first what to do in such cases.

## Custom Skills

- `/parse-api` — guidance for safely parsing reverse-engineered X API responses
- `/port-from-squawker` — port a bug fix or feature from the Squawker codebase
- `/translate` — user asked anything about translation, or you tried to add/remove/edit a text that appears in the UI
