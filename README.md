# Reels Studio

[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2016+%20|%20macOS%2013+%20|%20visionOS%201+-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](LICENSE)

**Reels-style video editor — flagship reference app for [Kadr](https://github.com/SteliyanH/kadr).**

A real consumer codebase using every kadr + kadr-ui + kadr-captions + kadr-photos component end-to-end. Pick clips from Photos, drop them on a multi-lane timeline, layer overlays + filters + animated text, attach background music with auto-ducking, ingest captions from a file, and export to a Reels / TikTok / Square / Cinema preset.

## Status

**v0.6.0 shipped — robustness + release engineering.** Cross-package-audit response cycle. Closes the corrupt-doc / future-schema silent-drop, lost-on-force-quit, raw-path-in-toast, missing-PrivacyInfo, no-XCUITest, no-localization-extraction gaps the app had carried since v0.2. Bumps kadr ≥ 0.11.0 (atomic CancellationToken, Speed enum, FilterID + keyed filter ops) and kadr-ui ≥ 0.10.1 (Sendable event-struct callbacks, OverlayHost multi-select, snapshot + gesture-driver harness). Adds schema v4 + library recovery screen, `@SceneStorage` + scenePhase background flush, `ErrorSanitizer` + Photos permission pre-check, `ReelsStudioUITests` (5 critical flows), en-US `Localizable.strings` (~150 keys), `PrivacyInfo.xcprivacy`, fastlane scaffolding, opt-in Sentry crash reporting.

| Layer | What's wired |
|---|---|
| **Launch** | `ProjectListView` → tap a project to open the editor; `+ New Project` / `Sample` empty-state CTAs; swipe-to-delete |
| **Persistence** | schema v4 Codable `ProjectDocument` — round-trips every kadr clip / overlay / filter (with kadr v0.11 `FilterID`s) + per-property `Animation<T>` keyframes + speed curves + per-project zoom + fixed-center-playhead flag + accent color; v1 / v2 / v3 documents continue loading; corrupt / future-schema files surface in a "Skipped projects" recovery section |
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
