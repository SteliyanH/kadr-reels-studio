# Reels Studio

[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2017+-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](LICENSE)
[![Sponsor](https://img.shields.io/badge/Sponsor-Buy%20me%20a%20coffee-FFDD00?logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/steliyanh)

**Reels-style video editor — flagship reference app for [Kadr](https://github.com/SteliyanH/kadr).**

A real consumer codebase using every kadr + kadr-ui + kadr-captions + kadr-photos component end-to-end. Pick clips from Photos, drop them on a multi-lane timeline, layer overlays + filters + animated text, attach background music with auto-ducking, ingest captions from a file, and export to a Reels / TikTok / Square / Cinema preset.

## Status

**v0.11.0 shipped — correctness catch-up.** Runs on kadr 0.17.x + kadr-ui 0.16.x + kadr-captions 0.10.x + kadr-photos 0.9.x, current with the family after three cycles a release behind. No new features: three guaranteed stack overflows in the colour pickers are fixed, kadr's error text now reaches the interface with the recovery suggestion attached rather than the description alone, and the app reports its own version honestly for the first time since v0.1.0. `SWIFT_TREAT_WARNINGS_AS_ERRORS` is on — the recursions had been warned about for three releases and nothing had to act on it. Earlier cycles: v0.10.0 (transport band + snapshot harness + the Modernist design system), v0.7.0 (editor UX catch-up to CapCut-baseline parity).

| Layer | What's wired |
|---|---|
| **Launch** | `ProjectListView` → tap a project to open the editor; `+ New Project` / `Sample` empty-state CTAs; swipe-to-delete |
| **Persistence** | schema v5 Codable `ProjectDocument` — round-trips every kadr clip / overlay / filter (with kadr v0.11 `FilterID`s) + per-property `Animation<T>` keyframes + speed curves + per-project zoom + fixed-center-playhead flag + accent color + text stroke / shadow on text overlays and titles; v1 – v4 documents continue loading; corrupt / future-schema files surface in a "Skipped projects" recovery section |
| **Errors** | three-tier `AppError` model — transient toast / resumable sheet / catastrophic alert; single `.toastHost(_:)` modifier installed at app root |
| **Undo / Redo** | `UndoManager`-backed snapshot history with action names; per-action granularity via `groupsByEvent = false`; top-bar arrow buttons |
| **Two-tier toolbar** | `EditorToolbar` swaps between root verbs / clip-action / overlay-action / multi-select rows with a uniform spring crossfade; selection-driven; long-press a clip → multi-select mode |
| **Clip actions** | `Split` (`splitClip(id:at:)` at the playhead), `Duplicate`, `Speed` (pushes `SpeedCurveSheet`), `Filters` (pushes `FiltersSheet` — per-filter sliders + add-menu + swipe-to-delete), `Delete` (with medium-thud haptic) |
| **Overlay actions** | `Duplicate`, `Forward` / `Back` (z-order shift), `Delete` (with thud). Tap an overlay directly on the preview → `OverlayHost.onLayerTap` routes to selection |
| **Track creation** | Long-press a clip → multi-select mode → tap to extend → toolbar `Wrap` collapses the contiguous range into a `Track {}` block (transitions ride along). Failure modes surface as transient toasts |
| **Haptics** | `HapticEngine` actor (`snap` / `thud` / `success`): pinch-zoom + drag-to-reorder fire `snap`; delete fires `thud`; export completion fires `success` |
| **Timeline** | per-project pinch-zoom (no undo pollution); fixed-center playhead with `ScrollViewReader` + 1×1 anchor; multi-track `Track {}` blocks with reorder / trim wiring |
| **Accent threading** | `Project.accentColor: Color?` (per-project, persisted, nil = system tint); `.tint(_:)` applied at the editor root threads through every `.tint`-aware surface |
| **Captions** | tabbed `AddCaptionsSheet` — Edit (`KadrUI.CaptionEditor`) / Import (SRT / VTT / iTT / ASS / SSA) |
| **Add Overlay** | three-tab sheet — Text / Image / Sticker, backed by kadr-photos `PhotoPicker` |
| **Settings** | gear icon → `SettingsView`: Appearance (System/Custom accent + `ColorPicker`), Playback (fixed-center playhead), Haptics (Off/Light/Medium). `AppSettings` UserDefaults-backed for app-level prefs; per-project prefs live on `Project` and round-trip through schema v3 |
| **Accessibility** | every interactive site has `.accessibilityLabel` / `.accessibilityHint` / `.accessibilityValue` where applicable. `.help(_:)` tooltips on iPad + Mac. Disabled state (e.g. Export with no clips) greyed-not-hidden with a "why" tooltip |

See [CHANGELOG.md](CHANGELOG.md) for the full release entry, [ROADMAP.md](ROADMAP.md) for what's next (v1.0 App Store submission — name lock, icon, metadata, Dynamic Type / Reduce Motion audit), and [DESIGN.md](DESIGN.md) for the v0.1 → v0.5 RFCs.

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

Contributions are accepted under the [Contributor License Agreement](CLA.md), which is signed once and covers all future contributions. It does not transfer ownership — you keep the copyright in your work.
