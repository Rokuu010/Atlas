#!/usr/bin/env python3
"""
precompute_text_embeddings.py  (run on macOS/Linux with PyTorch — NOT in the app)

Implements the §6 key optimisation: the category detection prompts are fixed, so we run
the SigLIP TEXT encoder ONCE at build time over every prompt, average the prompts per
category (prompt ensembling), L2-normalise, and ship ONLY these vectors. The text encoder
never ships in the app — only the image encoder does (see convert_siglip_coreml.py).

Output: Tastecard/Resources/category_text_embeddings.bin in the exact binary format that
TextEmbeddingStore.swift parses:

    magic   : 4 bytes "TCTE"
    version : uint32 = 1
    dim     : uint32
    count   : uint32
    repeated count times:
        idLen : uint16
        id    : idLen UTF-8 bytes
        vec   : dim float32 (little-endian, L2-normalised)

IMPORTANT: use the SAME SigLIP checkpoint here and in convert_siglip_coreml.py so the
text and image embedding spaces are aligned.

Setup:
    pip install open_clip_torch torch numpy
Usage:
    python scripts/precompute_text_embeddings.py
"""

from __future__ import annotations

import argparse
import json
import struct
from pathlib import Path

MODEL_NAME = "ViT-B-16-SigLIP"     # 768-dim; keep in sync with the image encoder
PRETRAINED = "webli"


def main() -> int:
    here = Path(__file__).resolve().parent
    ap = argparse.ArgumentParser()
    ap.add_argument("--categories", default=str(here.parent / "Tastecard" / "Resources" / "categories.json"))
    ap.add_argument("--output", default=str(here.parent / "Tastecard" / "Resources" / "category_text_embeddings.bin"))
    ap.add_argument("--model", default=MODEL_NAME)
    ap.add_argument("--pretrained", default=PRETRAINED)
    args = ap.parse_args()

    import numpy as np
    import torch
    import open_clip

    cats = json.loads(Path(args.categories).read_text(encoding="utf-8"))["categories"]
    print(f"Loaded {len(cats)} categories")

    model = open_clip.create_model(args.model, pretrained=args.pretrained)
    model.eval()
    tokenizer = open_clip.get_tokenizer(args.model)

    ids: list[str] = []
    vectors: list[np.ndarray] = []

    with torch.no_grad():
        for c in cats:
            prompts = c["detectionPrompts"]
            tokens = tokenizer(prompts)
            feats = model.encode_text(tokens)                    # [P, D]
            feats = feats / feats.norm(dim=-1, keepdim=True)     # normalise each prompt
            ensemble = feats.mean(dim=0)                         # prompt ensembling
            ensemble = ensemble / ensemble.norm()               # re-normalise the mean
            ids.append(c["id"])
            vectors.append(ensemble.cpu().numpy().astype("<f4"))

    dim = int(vectors[0].shape[0])
    assert all(v.shape[0] == dim for v in vectors), "inconsistent embedding dim"
    print(f"Embedding dim: {dim}")

    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("wb") as f:
        f.write(b"TCTE")
        f.write(struct.pack("<I", 1))
        f.write(struct.pack("<I", dim))
        f.write(struct.pack("<I", len(ids)))
        for cid, vec in zip(ids, vectors):
            idb = cid.encode("utf-8")
            f.write(struct.pack("<H", len(idb)))
            f.write(idb)
            f.write(vec.tobytes())

    size_kb = out.stat().st_size / 1024
    print(f"Wrote {len(ids)} vectors ({dim}-d) -> {out}  ({size_kb:.0f} KB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
