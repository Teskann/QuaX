---
skill: enabled
name: parse-api
description: guidance for safely parsing reverse-engineered X API responses
---

# parse-api skill

Guide for writing code that parses X (Twitter) API responses in this codebase.

## Context

The X API used by QuaX is **reverse-engineered**. Endpoints, response shapes, and fields can change or disappear at any time without notice. Every field access on a parsed JSON map must be null-safe.

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
