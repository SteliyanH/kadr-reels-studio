# Reels Studio

[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2016+%20|%20macOS%2013+%20|%20visionOS%201+-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](LICENSE)

**Reels-style video editor — flagship reference app for [Kadr](https://github.com/SteliyanH/kadr).**

A real consumer codebase using every kadr + kadr-ui + kadr-captions + kadr-photos component end-to-end. Pick clips from Photos, drop them on a multi-lane timeline, layer overlays + filters + animated text, attach background music with auto-ducking, ingest captions from a file, and export to a Reels / TikTok / Square / Cinema preset.

## Status

**v0.3.0 shipped — wire-up cycle.** Every kadr-ui v0.7 / v0.8 editor surface that landed during the v0.2 polish cycle is now plumbed in: real keyframe authoring, speed-curve editing, caption editing, overlay inspector + overlay keyframe editor, timeline pinch-zoom, multi-track reorder/trim, sticker / image overlay creation. Built on v0.2's persistence + undo / redo + toast infra against kadr ≥ 0.10.1 + kadr-ui ≥ 0.8.0 + kadr-captions ≥ 0.4 + kadr-photos ≥ 0.4.

| Layer | What's wired |
|---|---|
| **Launch** | `ProjectListView` → tap a project to open the editor; `+ New Project` / `Sample` empty-state CTAs; swipe-to-delete |
| **Persistence** | schema v2 Codable `ProjectDocument` — round-trips every kadr clip / overlay / filter + per-property `Animation<T>` keyframes + speed curves + per-project zoom; v1 documents continue loading |
| **Errors** | three-tier `AppError` model — transient toast / resumable sheet / catastrophic alert; single `.toastHost(_:)` modifier installed at app root |
| **Undo / Redo** | `UndoManager`-backed snapshot history with action names; per-action granularity via `groupsByEvent = false`; top-bar arrow buttons |
| **Editor body** | `+ Clip` / `+ Overlay` / `+ Music` / `+ SFX` / `Captions` / `Layers` / `Export` — every toolbar button maps to a real flow |
| **Clip inspector** | tap a clip → transform / opacity / filter-intensity sliders; per-property keyframe authoring (tap-to-add, long-press-to-remove, drag-to-retime); "Speed curve…" row pushes `SpeedCurveSheet` |
| **Overlay inspector** | tap a layer in `LayersSheet` → `OverlayInspectorPanel` (position / size / anchor / opacity / type-specific) + `OverlayKeyframeEditor` for position / size on Image / Sticker overlays |
| **Captions** | tabbed `AddCaptionsSheet` — Edit (`KadrUI.CaptionEditor`) / Import (SRT / VTT / iTT / ASS / SSA) |
| **Timeline** | pinch-zoom persists per project (no undo pollution); multi-track `Track {}` blocks with `onTrackReorder` / `onTrackTrim` wired through `ProjectStore` |
| **Add Overlay** | three-tab sheet — Text / Image / Sticker. Image + Sticker share a `PhotoOverlayTab` backed by kadr-photos `PhotoPicker` |

See [CHANGELOG.md](CHANGELOG.md) for the full release entry, [ROADMAP.md](ROADMAP.md) for what's next (v0.4 → v1.0 UX polish layer — two-tier toolbar, fixed-center playhead, snap haptics, accent threading, accessibility), and [DESIGN.md](DESIGN.md) for the v0.1 / v0.2 / v0.3 RFCs.

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
