---
skill: enabled
name: port-from-squawker
description: Run this when user asked you to port something from Squawker
---

# port-from-squawker skill

Guide for porting bug fixes or features from the Squawker codebase into QuaX.

## Step 1 — Ensure Squawker is available

Check if `./squawker` exists:

```bash
ls squawker/lib 2>/dev/null || git clone https://github.com/j-fbriere/squawker squawker
```

If cloning is needed, try to clone. In case of failure during cloning, stop and ask the user to
clone it for you before proceeding.

## Step 2 — Locate the relevant change in Squawker

Find the fix using `git log` or `grep` in `squawker/lib/`.
Be aware Squawker sometimes have several commits for the same fix / feature, and sometimes mixes features in one commit.

Read the full Squawker file before reading the QuaX equivalent.

## Step 3 — Understand structural differences

QuaX and Squawker share a common ancestor (Fritter) but have diverged. Key differences to check:

| Area | QuaX | Squawker |
|---|---|---|
| State management | `flutter_triple` Store | may differ |
| DB entities | `lib/database/entities.dart` | may differ |
| API client | `lib/client/client.dart` | may differ |
| Route constants | `lib/constants.dart` | may differ |

Do **not** blindly copy code. Adapt it to QuaX's patterns.

## Step 4 — Port the change

- Apply the logic to the equivalent QuaX file(s) in `lib/`.
- Follow the functional style (immutable data, pure functions).
- If the fix touches API response parsing, apply null-safe access (see `/parse-api` skill).
- Preserve existing QuaX variable names, style, and indentation — do not reformat unrelated code.

## Step 5 — Verify

```bash
fvm flutter analyze          # no new analysis errors
```
