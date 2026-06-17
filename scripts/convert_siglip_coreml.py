#!/usr/bin/env python3
"""
convert_siglip_coreml.py  (run on macOS with coremltools — NOT in the app)

Converts the SigLIP IMAGE encoder to a quantised Core ML model for on-device inference
(§6). SigLIP preprocessing (resize + normalise to [-1, 1]) is BAKED INTO the model via
the ImageType scale/bias, so the Swift side (CoreMLImageEmbedder) just hands over a
CGImage. The text encoder is NOT converted — it is precomputed (precompute_text_embeddings.py).

Output: Tastecard/Resources/SigLIPImageEncoder.mlpackage
    input  : image  (RGB, side×side)
    output : embedding (float32 vector, dim must equal the text vectors' dim)

Use the SAME checkpoint as precompute_text_embeddings.py so the spaces align.

Setup (macOS):
    pip install open_clip_torch torch coremltools numpy
Usage:
    python scripts/convert_siglip_coreml.py
"""

from __future__ import annotations

import argparse
from pathlib import Path

MODEL_NAME = "ViT-B-16-SigLIP"     # 768-dim; keep in sync with the text side
PRETRAINED = "webli"
INPUT_SIDE = 224                    # ViT-B-16-SigLIP input resolution


def main() -> int:
    here = Path(__file__).resolve().parent
    ap = argparse.ArgumentParser()
    ap.add_argument("--output", default=str(here.parent / "Tastecard" / "Resources" / "SigLIPImageEncoder.mlpackage"))
    ap.add_argument("--model", default=MODEL_NAME)
    ap.add_argument("--pretrained", default=PRETRAINED)
    ap.add_argument("--side", type=int, default=INPUT_SIDE)
    ap.add_argument("--quantize", choices=["int8", "palettize6", "none"], default="int8")
    args = ap.parse_args()

    import numpy as np
    import torch
    import open_clip
    import coremltools as ct
    from coremltools.optimize.coreml import (
        linear_quantize_weights, OpLinearQuantizerConfig, OptimizationConfig,
        palettize_weights, OpPalettizerConfig,
    )

    model = open_clip.create_model(args.model, pretrained=args.pretrained)
    model.eval()

    # Wrap so the traced module's sole job is image -> embedding.
    class ImageEncoder(torch.nn.Module):
        def __init__(self, clip):
            super().__init__()
            self.clip = clip

        def forward(self, image):
            return self.clip.encode_image(image)   # raw features; Swift L2-normalises

    wrapper = ImageEncoder(model).eval()
    example = torch.rand(1, 3, args.side, args.side)
    with torch.no_grad():
        traced = torch.jit.trace(wrapper, example)
        out_dim = int(wrapper(example).shape[-1])
    print(f"Image encoder output dim: {out_dim}")

    # SigLIP normalisation is mean=0.5, std=0.5 per channel  =>  x_norm = x/127.5 - 1.0
    # Bake it into the ImageType so the model consumes a plain image.
    image_input = ct.ImageType(
        name="image",
        shape=(1, 3, args.side, args.side),
        scale=1.0 / 127.5,
        bias=[-1.0, -1.0, -1.0],
        color_layout=ct.colorlayout.RGB,
        channel_first=True,
    )

    mlmodel = ct.convert(
        traced,
        inputs=[image_input],
        outputs=[ct.TensorType(name="embedding")],
        convert_to="mlprogram",
        compute_units=ct.ComputeUnit.ALL,
        minimum_deployment_target=ct.target.iOS16,
    )

    # Quantise to fit the <70MB budget (§6/§12). Measure the result; quantise harder or
    # pick a smaller backbone if still over budget.
    if args.quantize == "int8":
        cfg = OptimizationConfig(global_config=OpLinearQuantizerConfig(mode="linear_symmetric", dtype="int8"))
        mlmodel = linear_quantize_weights(mlmodel, config=cfg)
    elif args.quantize == "palettize6":
        cfg = OptimizationConfig(global_config=OpPalettizerConfig(mode="kmeans", nbits=6))
        mlmodel = palettize_weights(mlmodel, config=cfg)

    mlmodel.short_description = "Tastecard on-device SigLIP image encoder"
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    mlmodel.save(str(out))

    print(f"Saved -> {out}")
    print(f"Output embedding dim = {out_dim}. This MUST equal the text-vector dim "
          f"(precompute_text_embeddings.py). Verify the .mlpackage size is well under 70 MB.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
