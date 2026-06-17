#!/usr/bin/env python3
"""
generate_categories.py

Convert the canonical Atlas_Categories.md table into the bundled, schema-validated
categories.json consumed by the iOS app (see Tastecard_Production_Prompt.md §6).

- Drops empty trailing rows and any row missing a display name or detection prompts.
- Splits the semicolon-separated SigLIP detection prompts into a list.
- Assigns each category a rarityIndex (0..1; common subjects low, rare subjects high)
  and a starting per-category similarity threshold. Both are TUNABLE config, not magic
  numbers in code — edit the tables below (or the JSON) without touching app logic.

Usage:
    python scripts/generate_categories.py
    python scripts/generate_categories.py --input path/to.md --output path/to.json
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

SCHEMA_VERSION = 1
DEFAULT_THRESHOLD = 0.20
DEFAULT_RARITY = 0.40

# rarityIndex per category id. Common/everyday subjects low; rare subjects high.
# Bands (see Rarity.swift): common 0.0–0.33, rare 0.33–0.6, epic 0.6–0.8, legendary 0.8–1.0.
RARITY: dict[str, float] = {
    # common — everyday camera-roll fodder
    "powered_by_caffeine": 0.12,
    "eats_first_questions_later": 0.12,
    "main_character": 0.12,
    "your_people": 0.15,
    "paws_claws": 0.18,
    "salt_in_the_air": 0.18,
    "golden_hour_loyalist": 0.20,
    "one_more_chapter": 0.20,
    "last_round": 0.22,
    "medium_rare": 0.24,
    "glaze_days": 0.26,
    "green_juice": 0.26,
    "bird_and_sauce": 0.26,
    "page_and_pour": 0.26,
    "boba_run": 0.28,
    "after_dark": 0.30,
    "wheels_up": 0.30,
    "player_one": 0.30,
    "caption_material": 0.30,
    "note_to_self": 0.30,
    "matcha_hour": 0.30,
    "rise_and_bake": 0.32,
    # rare — deliberate hobbies / specific scenes
    "always_on_the_run": 0.35,
    "engine_heart": 0.35,
    "on_the_pitch": 0.35,
    "hoop_dreams": 0.35,
    "front_row_energy": 0.35,
    "beat_face": 0.35,
    "your_move": 0.35,
    "two_wheels": 0.38,
    "sole_collector": 0.40,
    "crowd_surfer": 0.40,
    "skin_first": 0.40,
    "tech_forward": 0.40,
    "six_strings": 0.40,
    "layered_up": 0.45,
    "signature_scent": 0.45,
    "inked_pages": 0.45,
    "anime_heart": 0.45,
    "summit_chaser": 0.45,
    "board_feet": 0.45,
    "glove_up": 0.45,
    "gallery_wanderer": 0.45,
    "brick_by_brick": 0.45,
    "lights_up": 0.45,
    "designer_eye": 0.50,
    "holy_ground": 0.50,
    "time_piece": 0.50,
    "on_the_baize": 0.50,
    "net_result": 0.50,
    "deck_builder": 0.50,
    "bullseye": 0.50,
    "mic_night": 0.52,
    "last_light": 0.55,
    # epic — uncommon / harder to capture
    "sea_legs": 0.60,
    "in_the_saddle": 0.62,
    "fresh_ice": 0.62,
    "sawdust": 0.60,
    "spray_can": 0.60,
    "lens_hunter": 0.60,
    "star_gazer": 0.62,
    "in_character": 0.65,
    "steam_engine": 0.60,
    "tiny_hands": 0.66,
    "apex_hunter": 0.68,
    "cave_dweller": 0.72,
    "drone_pilot": 0.70,
    # legendary — genuinely rare moments / subjects
    "she_said_yes": 0.82,
    "aurora_chaser": 0.92,
}

# Per-category threshold overrides. Ambiguous categories (e.g. running vs hiking) get a
# slightly raised bar to reduce cross-firing. Everything else uses DEFAULT_THRESHOLD.
THRESHOLD: dict[str, float] = {
    "always_on_the_run": 0.22,   # running vs hiking/walking
    "summit_chaser": 0.22,       # mountains vs generic landscape
    "last_light": 0.24,          # calm water vs any water
    "salt_in_the_air": 0.22,     # beach vs any water
    "note_to_self": 0.24,        # notes vs any screenshot
    "caption_material": 0.24,    # memes vs any screenshot
    "main_character": 0.22,      # selfie vs any portrait
}


def slugify(name: str) -> str:
    s = name.strip().lower()
    s = s.replace("&", " and ")
    s = re.sub(r"[''`]", "", s)
    s = re.sub(r"[^a-z0-9]+", "_", s)
    return s.strip("_")


def parse_table(md: str) -> list[dict]:
    rows: list[dict] = []
    for line in md.splitlines():
        line = line.strip()
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        if len(cells) < 3:
            continue
        display, tagline, prompts_raw = cells[0], cells[1], cells[2]
        # Skip the header row and the markdown separator row.
        if display.lower() in {"display name", ""}:
            continue
        if set(display) <= {"-", ":", " "}:
            continue
        prompts = [p.strip() for p in prompts_raw.split(";") if p.strip()]
        if not display or not prompts:
            # Drop empty trailing rows and rows with no detection prompts (e.g. "New Keys").
            continue
        cid = slugify(display)
        rows.append(
            {
                "id": cid,
                "displayName": display,
                "tagline": tagline,
                "detectionPrompts": prompts,
                "rarityIndex": round(RARITY.get(cid, DEFAULT_RARITY), 2),
                "threshold": round(THRESHOLD.get(cid, DEFAULT_THRESHOLD), 2),
            }
        )
    return rows


def main() -> int:
    here = Path(__file__).resolve().parent
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", default=str(here / "Atlas_Categories.md"))
    ap.add_argument("--output", default=str(here.parent / "Tastecard" / "Resources" / "categories.json"))
    args = ap.parse_args()

    md = Path(args.input).read_text(encoding="utf-8")
    categories = parse_table(md)

    # Integrity checks: unique ids, non-empty prompts, sane ranges.
    ids = [c["id"] for c in categories]
    dupes = {i for i in ids if ids.count(i) > 1}
    if dupes:
        print(f"ERROR: duplicate category ids: {sorted(dupes)}", file=sys.stderr)
        return 1
    for c in categories:
        assert 0.0 <= c["rarityIndex"] <= 1.0, c
        assert 0.0 < c["threshold"] < 1.0, c
        assert c["detectionPrompts"], c

    payload = {"version": SCHEMA_VERSION, "categories": categories}
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {len(categories)} categories -> {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
