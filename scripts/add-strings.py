#!/usr/bin/env python3
"""Adds or removes keys in Shared/Localizable.xcstrings (en + vi), keeping the
file sorted and formatted exactly as it is committed.

Add:    scripts/add-strings.py <<'JSON'
        {"some.key": ["English", "Tiếng Việt"]}
        JSON
Remove: scripts/add-strings.py --remove some.key other.key
"""
import argparse
import json
import os
import re
import sys

DEFAULT_CATALOG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Shared", "Localizable.xcstrings")
FORMAT = re.compile(r"%(?:\d+\$)?(?:ld|lld|d|@|f|\.\d+f)")


def entry(en, vi):
    return {"extractionState": "manual", "localizations": {
        "en": {"stringUnit": {"state": "translated", "value": en}},
        "vi": {"stringUnit": {"state": "translated", "value": vi}}}}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", default=DEFAULT_CATALOG)
    parser.add_argument("--remove", nargs="+", metavar="KEY")
    args = parser.parse_args()

    with open(args.catalog, encoding="utf-8") as f:
        catalog = json.load(f)
    strings = catalog["strings"]

    if args.remove:
        for key in args.remove:
            if key not in strings:
                sys.exit(f"unknown key: {key}")
            del strings[key]
    else:
        for key, pair in json.load(sys.stdin).items():
            if key in strings:
                sys.exit(f"key already exists: {key}")
            if not (isinstance(pair, list) and len(pair) == 2 and all(isinstance(s, str) and s.strip() for s in pair)):
                sys.exit(f"expected [English, Vietnamese] for {key}")
            en, vi = pair
            if sorted(FORMAT.findall(en)) != sorted(FORMAT.findall(vi)):
                sys.exit(f"format specifiers differ between en and vi for {key}")
            strings[key] = entry(en, vi)

    catalog["strings"] = dict(sorted(strings.items()))
    missing = [k for k, v in catalog["strings"].items() if set(v.get("localizations", {})) != {"en", "vi"}]
    if missing:
        sys.exit(f"missing translations: {missing}")
    with open(args.catalog, "w", encoding="utf-8") as f:
        json.dump(catalog, f, ensure_ascii=False, indent=2)
    print(f"{len(catalog['strings'])} strings")


if __name__ == "__main__":
    main()
