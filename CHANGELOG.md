# Changelog

All notable changes to Reels Studio will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.2.0] - 2026-05-04

Production-polish foundation. Closes the four "feels like a prototype" gaps from a survey of CapCut / VN / iMovie UX: **persistence**, **error surfacing**, **undo / redo**, and a real **first-run flow**.

### Added — persistence

- **`ProjectDocument`** — Codable on-disk JSON shape decoupled from runtime `Project`. Sumtype mirrors of every kadr `any Clip` / `any Overlay` / `Filter` case (`mono` / `lut(url:)` / `chromaKey(r:g:b:threshold:)` included), plus `ProjectTransform`, `ProjectAudioTrack`, `ProjectCaption`, `ProjectPreset`, font-weight / alignment / anchor enums. Schema-versioned (`schemaVersion: 1`); future-version files reject with `ProjectLibraryError.unsupportedSchema` rather than silently misinterpreting fields.
- **`ProjectLibrary`** — disk-backed `@MainActor ObservableObject`. Stores under `~/Library/Application Support/ReelsStudio/Projects/<uuid>.json`. CRUD: `newProject` / `load` / `save` / `delete` / `duplicate`. List sorted `modifiedAt`-desc. Corrupt JSON files skipped during load — one bad file doesn't take down the library.
- **Round-trip bridge** — every clip / overlay / filter survives. `LUT` reloads from its source `.cube` URL; if the file is missing the filter drops with the rest of the clip intact. `TextStyle.color` round-trips via `#RRGGBB(AA)` hex extracted via cross-platform PlatformColor component access. Image clips embed PNG data on disk.

### Added — first-run UX

- **`ProjectListView`** — new launch root. Lists every saved project (most-recently-modified first), shows an empty state with **+ New Project** + **Sample** CTAs, swipe-to-delete, toolbar plus button (auto-numbers `Untitled`, `Untitled 2`, …). Tapping a row pushes the editor for that project.
- **`LibraryHost` / `LibraryHostView`** — owns the lazy `ProjectLibrary` construction. If init throws (sandbox / permissions failure), surfaces the failure inline rather than crashing the app.
- **Auto-save** in `EditorView` — `.onReceive` pipeline observes `store.$project` with a 0.5s debounce, persists every mutation back through the library on the trailing edge. No Save button anywhere; closing the editor is enough.

### Added — error surfacing

- **`AppError` + `ToastCenter` + `ToastView`** — three-tier severity model. `.transient` → top toast, auto-dismiss 2s. `.resumable` → medium-detent sheet with Cancel / Retry. `.catastrophic` → standard alert. Single `.toastHost(_:)` modifier at the app root; every screen below inherits surfacing.
- **All four `print()` sites replaced.** `AddClipFlow` photo-resolution failure → transient toast with underlying error as detail. The three `KeyframeArea` print stubs dropped entirely — `KeyframeEditor` falls back to read-only display when callbacks are nil (correct v0.2 semantic; full authoring lands in v0.3).

### Added — undo / redo

- **`UndoManager`-backed history** on `ProjectStore`. Snapshot-based — every mutation captures the previous `Project` value, registers an undo block that walks both backward and forward. `groupsByEvent = false` so each user action is one undo step.
- **Action names** flow to `UndoManager.setActionName`: `Add Clip`, `Add Overlay`, `Edit Transform`, `Edit Opacity`, `Edit Filter`, `Reorder Clips`, `Change Preset`, `Add Captions`, `Add Audio`. System "Undo X" menu on iPad / Mac shows what's about to revert.
- **Two top-bar arrow buttons** in `EditorView` (accessibility-labeled). `@Published canUndo` / `canRedo` flags drive disabled state.

### Tests

64 new tests across the cycle (`ProjectDocumentTests` ×22, `ProjectLibraryTests` ×11, `ProjectListViewTests` ×5, `ToastCenterTests` ×11, `UndoRedoTests` ×15). Suite: 1 → 65.

### Dependencies

Floors unchanged from v0.1 — kadr ≥ 0.9.2, kadr-ui ≥ 0.6.0, kadr-captions ≥ 0.4.0, kadr-photos ≥ 0.4.0. v0.3 will bump kadr-ui to ≥ 0.8.0 to wire SpeedCurveEditor / CaptionEditor / OverlayInspectorPanel / OverlayKeyframeEditor.

### Notes

- **Caught silent-data-loss gaps mid-cycle.** The first cut of the persistence bridge dropped `TextStyle.color`, `VideoClip.filters`, and `Transform` on clips. All three were user-reachable through existing v0.1 UI; closed in a Tier 1.5 patch before continuing.
- **Rapid slider-edit coalescing** isn't implemented — every InspectorPanel edit lands on slider commit (not continuous tracking), so each becomes one undo step. A future tier could add debounced grouping for continuous-edit sessions.
- **Keyframe authoring is read-only in v0.2.** Full authoring (with `Animation<T>` mutation helpers) lands in v0.3 alongside SpeedCurveEditor / OverlayKeyframeEditor wire-up.

## [0.1.0] - 2026-04-30

First release. End-to-end editor walking skeleton — every toolbar button maps to a real flow against the kadr v0.9.2 + kadr-ui v0.6 + kadr-captions v0.4 + kadr-photos v0.4 surface. Distributed via xcodegen + Xcode (`brew install xcodegen && make project && open ReelsStudio.xcodeproj`).

### Added

- **Project structure** — `Project` value type, `ProjectStore` ObservableObject owning the editor state, `SampleProject` first-launch builder (three swatch `ImageClip`s + a "Reels Studio" title overlay).
- **`EditorView`** — root composing `PreviewArea` (`VideoPreview` + `OverlayHost`, aspect-locked) on top + `TimelineArea` (toolbar row + multi-lane `TimelineView`) below.
- **`+ Clip` toolbar** — kadr-photos `PhotoPicker` sheet → `PhotosClipResolver.clips(from:)` → appended to project.
- **`+ Overlay` toolbar** — text overlay editor sheet (`TextField` + size slider + weight picker + `ColorPicker` + live preview) → centered `TextOverlay` appended.
- **`+ Music` toolbar** — file importer + volume slider + auto-duck toggle. Defaults: fade-in 0.5s, fade-out 1.0s, ducking 0.3 when enabled.
- **`+ SFX` toolbar** — file importer + pin-time slider (`0...video.duration`) + volume. Appends `AudioTrack.at(time:)`.
- **`Captions` toolbar** — file importer (`.srt` / `.vtt` / `.itt` / `.ass` / `.ssa`) + auto-detect via `Caption.load(_:)` + parsed-cue counter.
- **`Export` toolbar** — preset picker (Reels/Shorts, TikTok, Square, Cinema), `Exporter.run()`-driven progress, share sheet on completion.
- **Inspector + Keyframe editor** — slide in when a clip is selected. `InspectorPanel` wraps kadr-ui's panel; transform / opacity / filter-intensity callbacks rebuild the targeted clip via store helpers (`applyTransform`, `applyOpacity`, `applyFilterIntensity`). `KeyframeArea` wraps `KeyframeEditor` (read-only in v0.1; write callbacks log).
- **CI** — `xcodebuild test` against the highest-runtime iPhone simulator (UDID-based selection survives runner-image churn).

### Distribution

- **xcodegen** — `project.yml` declares the iOS app, `ReelsStudioTests` XCTest bundle, all four kadr-ecosystem SPM deps, Info.plist properties, and Debug/Release schemes. `Makefile` runs `xcodegen generate`.
- `*.xcodeproj` and `Sources/ReelsStudio/Info.plist` are `.gitignore`'d (regenerated from `project.yml`).
- Bootstrap: `brew install xcodegen && git clone && make project && open ReelsStudio.xcodeproj`.

### Compatibility

- iOS 16+, macOS 13+, visionOS 1+. tvOS excluded (kadr-photos requires `Photos.framework`).
- Swift 6, strict concurrency.
- kadr ≥ 0.9.2, kadr-ui ≥ 0.6.0, kadr-captions ≥ 0.4.0, kadr-photos ≥ 0.4.0.

### Known limitations

- **Keyframe authoring** — `KeyframeEditor`'s add / remove / retime callbacks log to console. Full keyframe authoring needs `Animation<T>` mutation helpers + a clip-rebuild path; a v0.1.x patch wires the writes.
- **Styled VTT bridge** — caption ingest uses `Caption.load(_:)` (plain). The v0.3 `Caption.loadStyled(vtt:)` + `Video.styledCaptions(_:)` styled-overlay path is a v0.1.x patch.
- **Sticker / watermark overlays** — `+ Overlay` ships text-only.
- **Project save / load to disk** — in-memory only at v0.1; serialization is the v0.2 headline.
- **App Store distribution** — `project.yml` builds a runnable simulator/device app today; signed-and-notarized App Store submission is post-v0.1.

### Notes

This is the flagship reference app for the kadr ecosystem. Real consumer code beats unit tests for "how do I use this" questions — read `Sources/ReelsStudio/` instead of squinting at adapter unit tests.
