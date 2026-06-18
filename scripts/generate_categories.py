#!/usr/bin/env python3
"""
generate_categories.py

Emit the bundled, schema-validated categories.json from the catalogue in
categories_data.py (see Tastecard_Production_Prompt.md §6).

- ids are slugified from the display name; uniqueness is enforced.
- rarityIndex comes from the catalogue; threshold is a per-category match parameter.
  NOTE: the iOS engine uses bias-corrected RELATIVE affinity and ignores this absolute
  threshold; the Android engine still uses it as an absolute cosine cutoff. Keep it sane.

Usage:
    python scripts/generate_categories.py
    python scripts/generate_categories.py --output android/app/src/main/assets/categories.json
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from categories_data import CATEGORIES  # noqa: E402

SCHEMA_VERSION = 1
DEFAULT_THRESHOLD = 0.12


def slugify(name: str) -> str:
    s = name.strip().lower()
    s = s.replace("&", " and ")
    s = re.sub(r"[''`]", "", s)
    s = re.sub(r"[^a-z0-9]+", "_", s)
    return s.strip("_")


def build() -> list[dict]:
    out: list[dict] = []
    seen: set[str] = set()
    for name, tagline, rarity, prompts in CATEGORIES:
        cid = slugify(name)
        if not cid:
            raise ValueError(f"empty id for category {name!r}")
        if cid in seen:
            raise ValueError(f"duplicate category id {cid!r} (from {name!r})")
        seen.add(cid)
        prompts = [p.strip() for p in prompts if p.strip()]
        if not prompts:
            raise ValueError(f"{name!r}: no detection prompts")
        if not 0.0 <= rarity <= 1.0:
            raise ValueError(f"{name!r}: rarity out of range")
        out.append({
            "id": cid,
            "displayName": name.strip(),
            "tagline": tagline.strip(),
            "detectionPrompts": prompts,
            "rarityIndex": round(float(rarity), 2),
            "threshold": DEFAULT_THRESHOLD,
        })
    return out


def main() -> int:
    here = Path(__file__).resolve().parent
    ap = argparse.ArgumentParser()
    ap.add_argument("--output", default=str(here.parent / "Tastecard" / "Resources" / "categories.json"))
    args = ap.parse_args()

    categories = build()
    payload = {"version": SCHEMA_VERSION, "categories": categories}
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {len(categories)} categories -> {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
