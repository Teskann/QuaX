---
skill: enabled
name: parse-api
description: guidance for safely parsing reverse-engineered X API responses, and for fixing a Dart error caused by content X returned (type cast, null, missing field…) with a recorded fixture and tests
---

# parse-api skill

Guide for writing code that parses X (Twitter) API responses in this codebase.

## Context

The X API used by QuaX is **reverse-engineered**. Endpoints, response shapes, and fields can change or disappear at any time without notice. Every field access on a parsed JSON map must be null-safe.

## Fixing an error caused by content returned by X

When the bug is a Dart exception (`type 'Null' is not a subtype…`, `NoSuchMethodError`, a `TypeError` while parsing…) triggered by what X answered, do not guess the fix from the stack trace alone. Reproduce it from a recorded response:

1. **Add a scenario to `tool/record/links.json`** pointing at the page that triggers the error (the post, profile, search… from the issue or the report), with a `description` saying what makes it special. Follow the existing entries; see `tool/record/README.md`.
2. **Capture it**: `fvm dart run tool/record/capture.dart --only <part of the URL>` (only that link is opened, other fixtures are untouched). It needs Chrome and a logged-in throwaway account, so if it cannot run from here, ask the user to run the command and wait for the new file in `test/fixtures/<Operation>/`. Do not hand-write a fixture instead.
3. **First rule out a stale request.** If the fixture is fine (no null, every item present) while the app fails on the same page, the app is probably calling an outdated query and X answers it with degraded content (empty `tweet_results`…). Compare what the web client sent, recorded in the fixture, with what the app sends in `lib/client/client.dart`:
   - the fixture's `operation` and `queryId` against the path of the call (`/i/api/graphql/<queryId>/<Operation>`; an operation can be renamed, e.g. `UserMedia` became `UserVideoTimeline`);
   - `jq -r '.features|to_entries[]|"\(.key)=\(.value)"' <fixture> | sort` against the feature map used by the call (`_timelineFeatures`, `_profileFeatures`…), and the same for `variables` and `fieldToggles`.
   Align the app on the fixture: new queryId/operation, add the missing features (extra old ones are harmless), then update the `fixture(...)` keys in tests if the operation was renamed. Confirm before/after on a device or emulator when you can.
4. **Look for the fix in the fixture**: read the new JSON (`jq` on the path the stack trace names) to see the real shape, then fix the parser with the rules below. Check the fixture holds no private data before it is committed.
5. **Write a test that uses the fixture** through `test/fixtures.dart` (`fixture(...)` / `fixturesOf(...)`), in the Should style with a `reason` on every assertion. Check that it fails without the fix, then passes with it.
6. **Add widget tests when the error shows in the UI** (card, profile, feed…) to cover the rendering of that content: see `test/tweet/` for `pump_tweets.dart`, `card_fixtures.dart` and `FixtureTwitterClient` in `test/fixture_client.dart`.

## Rules

**Always use `?[]` (null-aware subscript) and cast with `as Type?`:**

```dart
// Safe — handles missing keys and null values
final id = tweet["rest_id"] as String?;
final text = tweet["legacy"]?["full_text"] as String?;
final count = tweet["legacy"]?["favorite_count"] as int? ?? 0;
final media = tweet["legacy"]?["entities"]?["media"] as List<dynamic>?;
```

**Never use `[]` without null-aware access on API-derived maps:**

```dart
// Unsafe — throws StateError if field absent
final text = tweet["legacy"]["full_text"] as String;
```

**Provide sensible fallbacks at the use site, not deep in the parser:**

```dart
// Return nullable types from parsers, let callers decide defaults
String? parseTweetText(Map<String, dynamic> data) {
  return data["legacy"]?["full_text"] as String?;
}
```

**Log unexpected shapes rather than crashing:**

```dart
final result = data["result"];
if (result == null) {
  log.warning('parse: missing result field in $data');
  return null;
}
```

## Common Response Shapes

X GraphQL responses are typically wrapped:

```
data -> tweetResult -> result -> __typename (Tweet | TweetWithVisibilityResults)
```

For `TweetWithVisibilityResults`, the actual tweet is nested under `tweet`:

```dart
final typename = result?["__typename"] as String?;
final tweet = typename == "TweetWithVisibilityResults"
    ? result?["tweet"]
    : result;
final legacy = tweet?["legacy"] as Map<String, dynamic>?;
```

## Checklist When Adding a New Parser

- [ ] Every `map[key]` access uses `?[key]` or is guarded by a prior null check
- [ ] All casts use `as Type?` (nullable)
- [ ] Missing or null fields produce `null` or a documented default — not an exception
- [ ] Add a comment referencing the endpoint if non-obvious
