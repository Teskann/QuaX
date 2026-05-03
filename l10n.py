#!/usr/bin/env python3
"""Manage ARB localization files: sort, fix metadata, report missing and unused keys."""

import argparse
import json
import subprocess
import sys
from pathlib import Path

L10N_DIR = Path("lib/l10n")
DART_DIR = Path("lib")
GENERATED_DIR = Path("lib/generated")
REFERENCE = "intl_en.arb"


def run(cmd):
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error running {' '.join(cmd)}:\n{result.stderr}", file=sys.stderr)
        sys.exit(1)
    return result


def get_arb_files():
    return sorted(L10N_DIR.glob("intl_*.arb"))


def sort_and_fix(files):
    for f in files:
        print(f"  {f.name}")
        run(["fvm", "dart", "run", "arb_utils", "sort", str(f)])
        run(["fvm", "dart", "run", "arb_utils", "generate-meta", str(f)])


def content_keys(arb_path):
    data = json.loads(arb_path.read_text(encoding="utf-8"))
    return {k for k in data if not k.startswith("@")}


def find_unused_keys(ref_file):
    ref_keys = content_keys(ref_file)
    dart_files = [
        f for f in DART_DIR.rglob("*.dart")
        if not f.is_relative_to(GENERATED_DIR)
    ]
    dart_source = "\n".join(f.read_text(encoding="utf-8") for f in dart_files)
    return [k for k in sorted(ref_keys) if f".{k}" not in dart_source]


def report_missing(files):
    ref = L10N_DIR / REFERENCE
    ref_keys = content_keys(ref)
    any_missing = False

    for f in files:
        if f.name == REFERENCE:
            continue
        missing = sorted(ref_keys - content_keys(f))
        if missing:
            any_missing = True
            print(f"\n  {f.name}: {len(missing)} missing")
            for k in missing:
                print(f"    - {k}")

    if not any_missing:
        print("  All locales are complete!")


def report_unused(ref_file):
    unused = find_unused_keys(ref_file)
    if unused:
        print(f"  {len(unused)} unused keys:")
        for k in unused:
            print(f"    - {k}")
    else:
        print("  No unused keys found!")


def clean_en(ref_file):
    unused = find_unused_keys(ref_file)
    if not unused:
        print("  Nothing to remove.")
        return
    data = json.loads(ref_file.read_text(encoding="utf-8"))
    for k in unused:
        data.pop(k, None)
        data.pop(f"@{k}", None)
    ref_file.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"  Removed {len(unused)} keys from {ref_file.name}.")


def clean_locales(files, ref_file):
    ref_keys = content_keys(ref_file)
    for f in files:
        if f.name == REFERENCE:
            continue
        data = json.loads(f.read_text(encoding="utf-8"))
        extra = [k for k in data if not k.startswith("@") and k not in ref_keys]
        if not extra:
            continue
        for k in extra:
            data.pop(k, None)
            data.pop(f"@{k}", None)
        f.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print(f"  {f.name}: removed {len(extra)} keys.")


def main():
    parser = argparse.ArgumentParser(description="Manage ARB localization files.")
    parser.add_argument("--clean", action="store_true", help="Remove unused keys from the reference locale and extra keys from other locales.")
    args = parser.parse_args()

    files = get_arb_files()
    ref = L10N_DIR / REFERENCE

    if args.clean:
        print("==> Cleaning unused keys from reference...")
        clean_en(ref)
        print("\n==> Removing extra keys from other locales...")
        clean_locales(files, ref)
        print()

    print("==> Sorting and fixing metadata...")
    sort_and_fix(files)

    print("\n==> Missing keys report...")
    report_missing(files)

    print("\n==> Unused keys (not referenced in lib/**/*.dart)...")
    report_unused(ref)


if __name__ == "__main__":
    main()
