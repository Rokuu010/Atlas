#!/usr/bin/env python3
"""
convert_siglip_onnx.py  (run on Linux/macOS — NOT in the app)

Exports the SigLIP IMAGE encoder to ONNX for the Android app (ONNX Runtime Mobile).
Mirrors convert_siglip_coreml.py but for Android. Uses the SAME checkpoint as
precompute_text_embeddings.py so the image/text embedding spaces align.

Unlike the Core ML build, preprocessing is NOT baked in — the Kotlin side normalises the
bitmap to [-1, 1] (x/127.5 - 1) before inference, matching SigLIP's mean=std=0.5.

Output: android/app/src/main/assets/siglip_image_encoder.onnx
    input  : image      float32 [1, 3, 224, 224]  (already normalised by the app)
    output : embedding  float32 [1, D]             (Kotlin L2-normalises)

Setup:
    pip install torch open_clip_torch transformers sentencepiece numpy onnx onnxruntime
Usage:
    python scripts/convert_siglip_onnx.py
"""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path

MODEL_NAME = "ViT-B-16-SigLIP"
PRETRAINED = "webli"
INPUT_SIDE = 224


def main() -> int:
    here = Path(__file__).resolve().parent
    ap = argparse.ArgumentParser()
    ap.add_argument("--output", default=str(here.parent / "android" / "app" / "src" / "main" / "assets" / "siglip_image_encoder.onnx"))
    ap.add_argument("--model", default=MODEL_NAME)
    ap.add_argument("--pretrained", default=PRETRAINED)
    ap.add_argument("--side", type=int, default=INPUT_SIDE)
    # int8 dynamic quantisation mirrors the Core ML int8 build: a full-precision
    # ViT-B/16 image tower is ~340 MB — far too large to bundle in an APK. Quantised it is
    # ~90 MB and the embedding space stays aligned with the (fp32) text vectors. Falls back
    # to fp32 if onnxruntime's quantiser is unavailable, so a model is always produced.
    ap.add_argument("--quantize", choices=["int8", "none"], default="int8")
    args = ap.parse_args()

    import torch
    import open_clip

    model = open_clip.create_model(args.model, pretrained=args.pretrained)
    model.eval()

    class ImageEncoder(torch.nn.Module):
        def __init__(self, clip):
            super().__init__()
            self.clip = clip

        def forward(self, image):
            return self.clip.encode_image(image)   # raw features; Kotlin L2-normalises

    wrapper = ImageEncoder(model).eval()
    dummy = torch.randn(1, 3, args.side, args.side)
    with torch.no_grad():
        out_dim = int(wrapper(dummy).shape[-1])
    print(f"Image encoder output dim: {out_dim}")

    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)

    # Export full-precision first to a staging path; quantise into the final path below.
    fp32_path = out.with_name("_fp32_" + out.name)
    torch.onnx.export(
        wrapper,
        dummy,
        str(fp32_path),
        input_names=["image"],
        output_names=["embedding"],
        opset_version=17,
        do_constant_folding=True,
        dynamic_axes={"image": {0: "batch"}, "embedding": {0: "batch"}},
    )

    if args.quantize == "int8":
        try:
            from onnxruntime.quantization import quantize_dynamic, QuantType
            quantize_dynamic(str(fp32_path), str(out), weight_type=QuantType.QInt8)
            fp32_path.unlink(missing_ok=True)
            print("Applied int8 dynamic quantisation.")
        except Exception as e:  # noqa: BLE001 — never let quantisation block model output
            print(f"WARNING: int8 quantisation failed ({e}); shipping full-precision model.")
            shutil.move(str(fp32_path), str(out))
    else:
        shutil.move(str(fp32_path), str(out))

    size_mb = out.stat().st_size / (1024 * 1024)
    print(f"Saved -> {out}  ({size_mb:.1f} MB)")
    print(f"Output embedding dim = {out_dim}. Must equal the text-vector dim "
          f"(precompute_text_embeddings.py).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
