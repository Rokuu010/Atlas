# Tastecard — Native iOS app

Analyse your camera roll **entirely on-device**, surface your dominant visual "themes,"
and package them into a beautiful, shareable 9:16 card. No network. No accounts. No data
leaves your phone.

This is a **native SwiftUI app** (iOS 16+), ported from the React/Tailwind mockup in the
original `Atlas` repo per `Tastecard_Production_Prompt.md`.

## Architecture decision

The production prompt's *primary* path was a Capacitor hybrid (the React UI inside a
`WKWebView`). That is a web app in a native shell — explicitly not what was wanted here.
We took the prompt's documented **SwiftUI fallback** (§2): the UI is rebuilt natively and
the export uses SwiftUI's `ImageRenderer` instead of `html-to-image`. The native substance
(Photos + on-device Core ML + native share) clears App Review Guideline 4.2.

- **On-device inference:** quantised SigLIP **image encoder** in Core ML. The text side is
  **precomputed at build time** and bundled as vectors — the text encoder never ships.
- **Zero network, zero secrets** in the core app.
- Two flagged product decisions (§11): the `#0000` serial is a **local random code**
  (e.g. `#A7F3`), not a fake global rank; sharing exports a **PNG** via the native sheet
  (no dead "copy link").

## Prerequisites

- **macOS + Xcode 15+** to build/run (the app cannot be compiled on Windows/Linux).
- **XcodeGen**: `brew install xcodegen`
- **Python 3.10+** for the build-time scripts (a venv is recommended).

## Build steps

```bash
# 1. Generate the bundled category dataset (cross-platform; already committed).
python scripts/generate_categories.py

# 2. (macOS) Produce the on-device model + precomputed text vectors.
python -m venv .venv && source .venv/bin/activate
pip install open_clip_torch torch coremltools numpy
python scripts/precompute_text_embeddings.py        # -> Tastecard/Resources/category_text_embeddings.bin
python scripts/convert_siglip_coreml.py             # -> Tastecard/Resources/SigLIPImageEncoder.mlpackage

# 3. (Optional) Add the .ttf fonts — see Tastecard/Resources/Fonts/README.md.

# 4. Generate and open the Xcode project.
xcodegen generate
open Tastecard.xcodeproj
# Set your DEVELOPMENT_TEAM in project.yml (or the target's Signing tab), then Run (⌘R).

# 5. Run the unit tests (⌘U), or:
xcodebuild test -scheme Tastecard -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation)'
```

> **Before the model is added,** the app builds and runs but shows an "analysis engine not
> installed" setup screen instead of crashing. After step 2 it goes fully live. The two
> scripts MUST use the same SigLIP checkpoint (they do by default) so the image/text
> embedding spaces align; the image encoder's output dimension must equal the text-vector
> dimension (both 768 for `ViT-B-16-SigLIP`).

## App size (< 70 MB budget, §12)

The bundle = quantised image encoder + precomputed text vectors (~a few hundred KB) +
fonts + assets. `convert_siglip_coreml.py` applies int8 quantisation by default; if the
`.mlpackage` is still over budget, switch `--quantize palettize6` or pick a smaller
backbone. Verify in Xcode's Organizer (App Thinning size report).

## Project layout

```
project.yml                     XcodeGen project definition (app + test targets)
scripts/                        generate_categories.py, precompute_text_embeddings.py, convert_siglip_coreml.py
Tastecard/
  TastecardApp.swift            @main + root flow router
  AppModel.swift                orchestration: phase, analysis lifecycle, deletion
  Info.plist / PrivacyInfo.xcprivacy
  DesignSystem/                 themes, glass, typography, brightness, rarity, droplet, flow layout
  Models/                       Tastecard, EmergentTheme, Category, Rarity (+ validated loader)
  Engine/                       Photos, EXIF, ImageEmbedder, CoreML embedder, text store, cache,
                                ThemeSelector, HeroPhotoPicker, AnalysisEngine
  Persistence/                  TastecardStore, LocalImageStore, DataDeletion
  Security/                     InputSanitizer
  Support/                      Haptics, ImageDownsampler, AssetImage
  Features/                     Greeting, Permission, Generation, Card, Detail, Snapshot, Share,
                                WarmingUp, Settings, Setup
  Resources/                    categories.json, PrivacyPolicy.md, Terms.md, Fonts/ (+ model outputs)
TastecardTests/                 ThemeSelector, Rarity, ExifClustering, InputSanitizer, CategoryLoading
```

## What was removed from the mockup (§3)

CreatorStudio / PhoneFrame, the fake QR + fake social buttons + `ais.studio` mock, the
`Testimonial` guestbook, all mock URLs, the `followers===2300?'Photos'` hack, the
hardcoded `#0000` and `bookworm→common` rarity map, Unsplash hotlinks, and the
`@google/genai` / Express / `dotenv` / Gemini server stub. The on-device analysis engine,
which was entirely absent, was built from scratch.

## Privacy & review

- `NSPhotoLibraryUsageDescription` is specific and honest; limited library is supported and
  offered. `PrivacyInfo.xcprivacy` declares required-reason APIs and **Data Not Collected**.
- One-tap "Delete my Tastecard data" (Settings) wipes the card, the embedding cache, and
  any custom background.
- Privacy Policy / Terms are bundled (`Resources/*.md`) and shown in-app; host the same
  files and add the URLs in App Store Connect.
