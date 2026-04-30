# Reels Studio

[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2016+%20|%20macOS%2013+%20|%20visionOS%201+-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](LICENSE)

**Reels-style video editor — flagship reference app for [Kadr](https://github.com/SteliyanH/kadr).**

A real consumer codebase using every kadr + kadr-ui + kadr-captions + kadr-photos component end-to-end. Pick clips from Photos, drop them on a multi-lane timeline, layer overlays + filters + animated text, attach background music with auto-ducking, ingest captions from a file, and export to a Reels / TikTok / Square / Cinema preset.

## Status

Early scaffolding — see [ROADMAP.md](ROADMAP.md) for the full plan and [DESIGN.md](DESIGN.md) for the v0.1 RFC. The first usable build lands once Tier 1 (editor screen with timeline + preview + project state) merges.

## Why this exists

1. **Integration test for the kadr ecosystem.** Feature gaps surface as missing UI in the app. If `InspectorPanel` can't bind to a property, that property's surface in kadr core is wrong.
2. **Marketing material.** Screenshots / GIFs into launch posts; App Store listing as a real free indie app.
3. **Reference implementation.** New contributors read the source instead of squinting at unit tests. Real consumer code beats unit tests for "how do I use this" questions.

## Why "reels"

- Aligns with the launch narrative — FFmpegKit / Pixel SDK retired, vertical short-form video is exactly the gap kadr fills.
- Maps onto kadr's surface — `Preset.reelsAndShorts` is top-billed; multi-track + overlays + BGM ducking + pinned SFX + filters are exactly the reels-style editor primitives.
- Concrete scope. Story / reels editors have well-understood UI conventions (CapCut, InShot, Indie Aesthetic Editor); less product-design thrash than a "general video editor".

## Building

The project is a Swift Package today (`swift build` / `swift test` work). Distribution via Xcode `.xcodeproj` lands in a follow-up — the source layout in `Sources/ReelsStudio/` is already the editor app's expected shape, so wrapping in an Xcode iOS app target is mechanical.

```bash
git clone https://github.com/SteliyanH/kadr-reels-studio.git
cd kadr-reels-studio
swift build
```

## License

Apache-2.0. See [LICENSE](LICENSE).
