---
name: translate
description: load this skill everytime user asks you to do translation stuff, or when you want to add text that will be displayed on the UI or when you remove such a text
---

# translate skill

Guide for adding, changing, or removing user-visible strings in QuaX.

## When this skill applies

Any time you touch a string that appears on the UI: adding a new label, changing existing copy, removing a string, or refactoring code that calls `L10n.of(context).*`.

## Fill translations

When asked to fill missing translations, DON'T READ *.arb FILES YET.

First run `./l10n.py` and check the output to see which file you need to work with.

## Rules

### 1. Never use raw strings in the UI

If a string is displayed to the user, it **must** go through the localization system:

```dart
// Wrong
Text("Subscribe")

// Right
Text(L10n.of(context).subscribe)
```

### 2. Add the key to `intl_en.arb` first

- Choose a descriptive snake_case key.
- The `@key` metadata entry is added automatically by `l10n.py` — you do not need to write it.

### 3. Fill every supported locale

After adding a key to `intl_en.arb`, add a translation for the same key in **all** of the following files:

```bash
ls lib/l10n/*.arb
```

### 3.1. Correctly fill a locale

For each translation, make an effort to produce a translation that not only is grammatically correct 
but also sounds natural in the target language. For every translation, ask yourself "does this sound
natural in this language ?". Do not try to match exactly the English syntax if it does not sound natural.

Example, from English to French for a setting description:

```txt
English: How much of a video is loaded ahead of playback. A shorter duration saves data and memory but may cause more pauses to load on unstable connections.
French: Détermine la durée maximale de vidéo chargée à l'avance. Une durée plus courte économise les données et la mémoire, mais peut provoquer davantage de coupures de chargement sur les connexions instables.
```

### 4. Stop and ask when the string is ambiguous

Before translating, **stop and ask the user** if any of the following is unclear:

- What is being counted or described (needed for plurals and grammatical gender)
- Ambiguity about the words (is it a verb ? A noun ? Which tense is it ?).
- Whether formal or informal register is expected
- The surrounding UI context (button label vs. body text vs. error message)

Do not guess. A wrong translation in one language silently ships to all users of that locale.

Then add the disambiguity in the arb file.

### 5. Plural strings: use ICU format with correct forms per language

Use the `{count, plural, …}` ICU syntax. Different languages require different plural categories:

```
// English — only one + other
"{count, plural, one{1 item} other{{count} items}}"

// French — zero treated as singular; only one + other
"{count, plural, one{{count} élément} other{{count} éléments}}"

// Russian / Ukrainian / Belarusian / Polish — one, few, many, other
"{count, plural, one{{count} элемент} few{{count} элемента} many{{count} элементов} other{{count} элемента}}"

// Arabic — zero, one, two, few, many, other (all six)
"{count, plural, zero{لا عناصر} one{عنصر واحد} two{عنصران} few{{count} عناصر} many{{count} عنصرًا} other{{count} عنصر}}"

// Japanese / Korean / Chinese / Vietnamese / Indonesian — only other
"{count, plural, other{{count}件}}"
```

When in doubt about which plural forms a language needs, ask the user.

### 6. Run `l10n.py` after every ARB change

```bash
python l10n.py
```

This sorts all files, adds missing metadata, and reports any remaining missing or unused keys. Fix any issues it reports before marking the task done.

## Checklist

- [ ] No raw UI string in Dart code — every visible string goes through `L10n.of(context).*`
- [ ] Key added to `intl_en.arb`
- [ ] Same key added to all 29 other locale files with correct translation
- [ ] Plural strings use ICU format with the correct plural categories for each language
- [ ] Ambiguous context was clarified with the user before translating
- [ ] `python l10n.py` run and output is clean (no missing keys reported)
