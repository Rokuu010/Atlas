# Rollcard — Privacy Policy

_Last updated: 2026-06-17_

Rollcard is built around a single promise: **your photos and everything we derive from them never leave your device.**

## What we access

- **Your photo library (read-only).** With your permission, Rollcard reads images from your photo library to build your card. You may grant access to **all** photos or only a **selected** subset (limited library) — your choice, changeable at any time in iOS Settings.
- **Photo location & timestamp (on-device only).** To count the distinct "Places" on your card, we read each photo's GPS coordinate and date directly from the photo metadata, **immediately group them into coarse clusters in memory, and discard the raw coordinates.** We never store or transmit precise locations.

## What we do with it

- All analysis runs **entirely on your device** using an on-device machine-learning model. 
- We compute which visual themes appear across your photos, pick representative photos, and assemble your card.
- **No photos, embeddings, locations, or derived data are ever uploaded, transmitted, or shared.** The app makes no network calls for its core experience.

## What we store

On your device only:

- Your card's derived results (theme identifiers, counts, chosen photo identifiers, your chosen display name, theme color, and a local random card code).
- A local cache of per-photo analysis results so re-runs are faster.
- Any custom background image you choose, stored in the app's private storage.

We do **not** store copies of your photos, and we do **not** store precise location coordinates.

## Sharing

When you share your card, the app exports an **image (PNG)** and hands it to the standard iOS share sheet. You decide where it goes. We are not involved in, and do not see, what you share.

## Third parties, ads, tracking

There are **none**. No analytics, no advertising, no trackers, no third-party SDKs that collect data, and no Advertising Identifier (IDFA). We do not ask for tracking permission because we do not track you.

## Your rights (including GDPR)

Because all data is local and nothing is collected by us, you remain in full control:

- **Right to erasure:** "Delete my Rollcard data" in Settings permanently removes your saved card, the on-device analysis cache, and any custom background from your device.
- **Access control:** You can revoke or change photo access any time in iOS Settings.

## Children

Rollcard does not knowingly collect data from anyone; it shows you only your own photos, on your own device.

## Contact

Questions about this policy: privacy@rollcard.app
