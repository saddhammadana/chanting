#!/usr/bin/env python3
"""Check the store listing copy against Play Console's character limits.

Reads docs/store/04-store-listing.md and measures every field, which is written
as a ```text fenced block under a "### <field> (limit N)" heading. The limit is
taken from the heading itself, so adding a field needs no change here. Each
field is reported under the "## " heading above it, which is what separates the
Thai copy from the English copy inside the one file.

Play counts characters, not bytes; Thai combining marks each count as one, which
is what len() on a Python str gives.

    python3 tool/store/check_listing_limits.py          # the listing file
    python3 tool/store/check_listing_limits.py some/other.md
"""

import pathlib
import re
import sys

FIELD = re.compile(r"^### (?P<name>.+?) \(limit (?P<limit>\d+)\)\s*\n+```text\n(?P<body>.*?)^```", re.M | re.S)
GROUP = re.compile(r"^## (?P<name>.+?)\s*$", re.M)


def check(path: pathlib.Path) -> bool:
    ok = True
    print(f"{path}:")
    text = path.read_text(encoding="utf-8")
    fields = list(FIELD.finditer(text))
    if not fields:
        print("  no fields found — has the heading format changed?")
        return False
    groups = [(m.start(), m.group("name")) for m in GROUP.finditer(text)]
    shown = None
    for match in fields:
        # The "## " heading above a field says which locale it belongs to.
        above = [name for start, name in groups if start < match.start()]
        if above and above[-1] != shown:
            shown = above[-1]
            print(f"  {shown}")
        name = match.group("name")
        limit = int(match.group("limit"))
        # Trailing newline before the closing fence is markdown, not copy.
        count = len(match.group("body").rstrip("\n"))
        mark = "ok " if count <= limit else "OVER"
        if count > limit:
            ok = False
        print(f"  [{mark}] {count:>5} / {limit:<5} {name}")
    return ok


def main() -> int:
    root = pathlib.Path(__file__).resolve().parents[2]
    args = sys.argv[1:]
    paths = [pathlib.Path(a) for a in args] or [root / "docs/store/04-store-listing.md"]
    return 0 if all(check(p) for p in paths) else 1


if __name__ == "__main__":
    raise SystemExit(main())
