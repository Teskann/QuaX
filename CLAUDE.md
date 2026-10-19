# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**QuaX** (formerly Quacker) is a privacy-focused Flutter/Dart client for X (formerly Twitter), forked from Quacker/Fritter. It has no external trackers, stores all data locally in SQLite, and uses reverse-engineered X API endpoints.

## Build & Development Commands

Use `fvm flutter` instead of raw `flutter` to enforce the pinned SDK version (3.47.5).

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

**Account selection strategy.** `_QuackerTwitterClient.fetch()` in `client.dart` asks `AccountSelector` (`account_selector.dart`, a pure/testable policy) for an account with credits left, then retries on another account on a 429. Only rate limits count: any other error is surfaced without trying another account.

**Rate limit (`429`)** is **per-endpoint** (X rate-limits per endpoint, not per account). It is tracked **in memory** by `RateLimitTracker` (`rate_limit_tracker.dart`), keyed by `AccountEndpoint` (account id + `uri.path`), from the `x-rate-limit-remaining` / `x-rate-limit-reset` headers of **every** response (a `429` without headers falls back to `rateLimitFallback`). `fetch()` counts down one credit locally (`consume`) right when it picks an account, so a parallel batch (e.g. the per-chunk searches of a group feed) never sends more requests than the known quota left; an answer from X never raises the local count within the same window. An unknown quota counts as available. Not persisted — windows are short. The selector receives this via an injected `hasCredit` predicate. `RateLimitedException` carries the earliest reset time, shown in the error card.

`AccountSelector.pick()` draws at random among the untried accounts with a credit left. Rate limits **short-circuit**: an account with no credit left on the endpoint is never picked, and when no untried account has a credit, `RateLimitedException` is thrown without sending anything. Errors surface through the single `ErrorCard` in `ui/errors.dart` (wrapped by `FullPageErrorWidget` when it takes the page), which gives each of these its own title and actions:
- every account is out of credits, or got a 429, on the endpoint → `RateLimitedException`;
- X answered 404, which happens now and then in normal use → `NotFoundException` (thrown in `get()`), whose card only offers retry, as its primary action;
- there is no account at all → an unauthenticated (guest) request is attempted first; `NoAccountAvailableException` is thrown only if that guest request also fails.

Any other error response is surfaced as-is via `HttpException`, and the card then offers to report it as a prefilled GitHub issue. Retry simply re-runs `fetch()`.

Group feeds cache each chunk's tweets in `feed_group_chunk`: the first page (on open or refresh) shows the cache, reloads every chunk from scratch and replaces a chunk's cache only once X answered, so offline or rate-limited chunks keep theirs; later pages follow the stored `cursor_bottom`. They send one search per chunk in parallel, and a failing chunk must not block the others: `_listTweets()` (`group/_feed.dart`) keeps what X answered and the stored tweets of the failed chunks, and the error goes to `TweetFeedController.partialError`, shown above the tweets. When part of the feed loaded, a rate limit there becomes a `FeedRateLimitedException`, whose card says the whole feed could not be loaded, when to retry, and how many subscriptions loaded out of the total. When nothing loaded, the plain `RateLimitedException` is shown. The page only fails when every chunk did.

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
- Go easy on comments. Avoid comments that are obvious or redundant, or that simply describe the code you're about to write.

## Custom Skills

- `/parse-api` — guidance for safely parsing reverse-engineered X API responses
- `/port-from-squawker` — port a bug fix or feature from the Squawker codebase
- `/translate` — user asked anything about translation, or you tried to add/remove/edit a text that appears in the UI

## Writing tests

When writing tests:
- Use the Should convention, and always use a concise `reason` message in assertions to make it
  perfectly clear what's broken when a test fails
  Look at other tests to mimicate the style.