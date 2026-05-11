# Changelog

All notable changes to Reels Studio will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.4.0] - 2026-05-11

UX-polish foundations. Closes the gap between "every button works" (v0.3) and "this feels like an app you'd actually use" — two-tier toolbar with selection-driven swap, fixed-center playhead, snap haptics on pinch-zoom + drag-to-reorder, accent-color threading, spring drawer detents, Track creation UI, and overlay tap-to-select on `OverlayHost`. Bumps kadr-ui ≥ **0.9.2** (three mid-cycle micro-patches shipped during this cycle).

### Added — two-tier toolbar (Tier 1a + 1b)

- **`EditorToolbar`** — state machine over `(selectedClipID, selectedOverlayID, isMultiSelecting)`. Four rows swap with a spring crossfade: root verbs (`+ Clip` / `+ Overlay` / `Layers` / `+ Music` / `+ SFX` / `Captions` / `Export`), clip-action (`Split` / `Duplicate` / `Speed` / `Filters` / `Delete`), overlay-action (`Duplicate` / `Forward` / `Back` / `Delete`), multi-select (`Cancel` / `N selected` / `Wrap`).
- **`ProjectStore.removeClip / duplicateClip / removeOverlay / duplicateOverlay / moveOverlay`** — simple array-op mutations powering Duplicate / Delete / Bring-forward / Send-back. Concrete-type dispatch through `.id()` modifiers for fresh UUID-backed clip / layer IDs.
- **`ProjectStore.splitClip(id:at:)`** — bisects the top-level clip at the playhead. `VideoClip` via `trimmed(to:)`; `ImageClip` via `.duration()`; `TitleSequence` rebuilds via the public `CMTime` init. Left half keeps the original `ClipID`; right half gets a fresh id. Returns `SplitResult` for toast surfacing (`.clipNotFound`, `.clipInsideTrack`, `.offsetOutOfRange`, `.unsupportedSpeedRate`).
- **`FiltersSheet`** — pushed from the Filters clip-action button. Per-filter intensity sliders + swipe-to-delete + leading `+` menu adding any of kadr's eleven scalar filter cases. LUT / chromaKey omitted from the menu pending URL / RGB pickers.
- **`ProjectStore.addFilter / removeFilter`** — append via `.filter(_:)`; remove via full clip rebuild without the indexed entry.

### Added — fixed-center playhead (Tier 2)

- **`Project.fixedCenterPlayhead: Bool`** — per-project opt-in (default `true`) for kadr-ui v0.9's `TimelineView.fixedCenterPlayhead(_:)` modifier. v0.5's settings screen will surface a toggle.
- **Schema v3** (additive `Bool?` field; `currentSchemaVersion` bumped 2 → 3). v1 / v2 / v3 all load; v4+ rejects. Re-saving an old document promotes it.

### Added — snap haptics + accent threading (Tier 3)

- **`HapticEngine`** — `@MainActor` singleton wrapping `UIImpactFeedbackGenerator` + `UINotificationFeedbackGenerator` with prep batching. Three entry points: `snap()` (light), `thud()` (medium), `success()` (notification). macOS / visionOS no-op via `canImport(UIKit)` gating.
- **`TimelineArea` wires `.onZoomSnap` + `.onClipDragSnap`** → `HapticEngine.shared.snap()`. Pinch-zoom crossings (kadr-ui v0.9 `ZoomSnapThreshold.standard`: 1f / 1s / 5s / 30s) and drag-to-reorder boundary crossings (kadr-ui v0.9.1 `onClipDragSnap`) both fire the same light haptic.
- **`Project.accentColor: Color?`** (nil = system tint) persists as `accentColorHex: String?` (additive on schema v3, no version bump — folds like `zoomPixelsPerSecond` did under v2). `EditorView` applies `.tint(_:)` at the root.

### Added — spring detents + export success + delete thud (Tier 4)

- **Uniform `.interactiveSpring(response: 0.35, dampingFraction: 0.78)`** on the toolbar mode-swap and inspector-pair reveal. `EditorView.inspectorPresentationKey(clip:overlay:)` static helper feeds `.animation(value:)`.
- **`HapticEngine.shared.thud()`** fires before every `removeClip` / `removeOverlay` (toolbar Delete + new `LayersSheet` swipe-to-delete).
- **`HapticEngine.shared.success()`** fires after `Exporter.run()` resolves, before the share sheet. Cancel / fail paths stay silent.

### Added — Track creation UI (Tier 5)

- **`ProjectStore.isMultiSelecting: Bool` + `selectedClipIDs: Set<ClipID>`** — transient multi-select mode. `didSet` clears the set on `false`. Drives kadr-ui v0.9.2's `selectedClipIDs:` binding for visible selection rings on every member.
- **`TimelineArea.onLongPressClip`** — 0.5s long-press enters multi-select + seeds with the long-pressed clip + fires `thud()`. Subsequent single taps route through an intercepted `selectedClipID` setter that toggles set membership.
- **`ProjectStore.wrapInTrack(ids:)`** — validates contiguous at the top level (transitions in the range travel into the Track because they have no `clipID`); replaces the range with a single `Track {}` block in one `applyMutation`. Returns `WrapInTrackResult` for toolbar toast surfacing.

### Added — overlay tap-to-select (Tier 6)

- **`PreviewArea.OverlayHost.onLayerTap { store.selectedOverlayID = $0 }`** — uses kadr-ui v0.8's already-shipping surface (the v0.4 RFC's claim it was v0.9 was corrected mid-cycle). `LayersSheet` stays as the secondary affordance for stacked / off-screen layers.

### Tests

61 new tests across the cycle. Suite: 149 → 210.

### Dependencies

- **kadr-ui ≥ 0.9.2** (up from 0.8.0). Brings (across three mid-cycle micro-patches):
  - `TimelineView.fixedCenterPlayhead(_:)` + `onZoomSnap(_:)` + `ZoomSnapThreshold.standard` (v0.9).
  - `TimelineView.onClipDragSnap(_:)` + `snapTransition(previous:current:)` (v0.9.1).
  - `TimelineView(... selectedClipIDs:)` additive parameter + `onLongPressClip(_:)` + `clipMatchesSelection(id:single:set:)` (v0.9.2).
- kadr / kadr-captions / kadr-photos floors unchanged (≥ 0.10.1 / ≥ 0.4.0 / ≥ 0.4.0).

### Notes

- **Three mid-cycle kadr-ui patches.** The v0.4 RFC underestimated the kadr-ui surface area twice (`OverlayHost.onLayerTap` already shipped in v0.8 — errata corrected; `onClipDragSnap` didn't exist; long-press + multi-select binding didn't exist). v0.9 / v0.9.1 / v0.9.2 shipped during the cycle to close each gap. The pattern — downstream cycle drives narrow upstream additions — is the same shape as kadr v0.10.1 mid-v0.3.
- **iOS accent-color picker** lives in v0.5's settings screen. v0.4 ships the persistence + `.tint` plumbing; the picker UI lands later.
- **Reorder of multi-selected clips as a group** is out of scope — kadr's `Video` builder doesn't model "swap N clips as one block" yet.

## [0.3.0] - 2026-05-05

Wire-up cycle. Integrates every kadr-ui v0.7 / v0.8 editor surface that shipped during the v0.2 production-polish cycle but wasn't yet plumbed in: real keyframe authoring, speed-curve editing, caption editing, overlay inspector + overlay keyframe editor, timeline pinch-zoom, multi-track reorder/trim, sticker / image overlay creation. Bumps kadr ≥ **0.10.1** and kadr-ui ≥ **0.8.0**.

### Added — schema v2 + keyframe authoring

- **`ProjectAnimation<Value>`** generic + per-value-type bridges (`Double`, `Transform`); `ProjectClip.track(TrackData)` for `Kadr.Track {}` blocks; `transformAnimation` / `opacityAnimation` / `filterAnimations` / `speedCurve` fields on `VideoClipData`; `transformAnimation` / `opacityAnimation` on `ImageClipData`; `TitleSequenceData.transform`; bumps `currentSchemaVersion` to **2**. Forward-only and additive — every v1 field continues reading; v1 documents on disk load fine.
- **`ProjectStore.addKeyframe / removeKeyframe / retimeKeyframe`** — replaces v0.2's read-only `KeyframeArea`. `KeyframeEditor`'s tap-to-add / long-press-to-remove / drag-to-retime gestures now produce real edits, routed through `applyMutation` so undo / redo + auto-save inherit.

### Added — speed curve

- **`SpeedCurveSheet`** wrapping `KadrUI.SpeedCurveEditor` — pushed from a per-clip "Speed curve…" inspector row when a `VideoClip` is selected. The log-scaled multiplier axis (0.25× ... 4×) needs vertical room a row can't give.
- **`ProjectStore.applySpeedCurve(id:_:)`** — `nil` clears via `clip.speed(rate)` (kadr's modifier nils `speedCurve`); non-nil sets via `clip.speed(curve:)`.

### Added — caption editor

- **Tabbed `AddCaptionsSheet`** — Edit (default when cues exist; wraps `KadrUI.CaptionEditor` for live cue authoring) / Import (defaults when empty; existing v0.2 file picker for SRT / VTT / iTT / ASS / SSA).
- **`ProjectStore.setCaptions(_:)`** — replaces the full caption array. `CaptionEditor` emits the full sorted-by-start list on every commit, so a single replace covers add / remove / retime / text changes uniformly.

### Added — overlay inspector + overlay keyframe editor

- **`OverlayInspectorArea`** and **`OverlayKeyframeArea`** — sibling views to clip-targeted `InspectorArea` / `KeyframeArea`, wrap `KadrUI.OverlayInspectorPanel` / `OverlayKeyframeEditor`. Selection lives on the new `ProjectStore.selectedOverlayID: LayerID?` slot, mutually exclusive with `selectedClipID` via `didSet` observers.
- **`LayersSheet`** — lists every overlay with type-specific icon + tap-to-select (text / image / sticker). v0.4 will replace this with tap-to-select directly on `OverlayHost`.
- **Overlay mutation surface** — common (`Position` / `Size` / `Anchor` / `Opacity`) + type-specific (TextOverlay text + animation, StickerOverlay rotation) + overlay keyframe authoring (`addOverlayKeyframe` / `removeOverlayKeyframe` / `retimeOverlayKeyframe` for `.position` / `.size` on Image / Sticker).

### Added — timeline zoom + multi-track

- **`Project.zoom: TimelineZoom?`** + **`ProjectDocument.zoomPixelsPerSecond`** — pinch-zoom persists per project; **does not** push undo (viewport state, not document state). Auto-save still picks it up on the trailing debounce edge.
- **`onTrackReorder`** routes to existing `replaceClips`. **`onTrackTrim`** routes to new **`ProjectStore.applyTrackTrim`** — walks to the right Track + inner clip and applies trim modifiers per kind. Multi-track projects loaded from disk render and edit correctly today.

### Added — sticker / image overlay creation

- **`AddOverlaySheet`** refactored into three tabs — Text (existing v0.2 editor, factored into a subview) / Image (`Kadr.ImageOverlay`) / Sticker (`Kadr.StickerOverlay`). Image / Sticker share a `PhotoOverlayTab` backed by kadr-photos `PhotoPicker` and `PhotosClipResolver.image` (1024×1024 target size cap).

### Tests

84 new tests across the cycle (`SchemaV2Tests` ×8, `KeyframeAuthoringTests` ×16, `SpeedCurveSheetTests` ×9, `AddCaptionsSheetTests` ×8, `OverlayInspectorTests` ×24, `TimelineZoomAndTracksTests` ×14, `AddOverlaySheetTests` ×5). Suite: 65 → 149.

### Dependencies

- **kadr ≥ 0.10.1** (up from 0.9.2). Brings the animation-clearing modifiers (`transformAnimation(_:)` / `opacityAnimation(_:)` / `filterAnimation(at:_:)` / overlay positionAnimation / sizeAnimation), which let the editor drop the ~120 LOC of `rebuildVideoClip` / `rebuildImageClip` / `rebuildTitleSequence` helpers Tier 1 had to ship.
- **kadr-ui ≥ 0.8.0** (up from 0.6.0). Brings `SpeedCurveEditor` / `CaptionEditor` / `OverlayInspectorPanel` / `OverlayKeyframeEditor` / `TimelineZoom` / `onTrackReorder` / `onTrackTrim`.
- kadr-captions / kadr-photos floors unchanged (≥ 0.4.0 / ≥ 0.4.0).

### Notes

- **Tier 1.5-style cleanup baked into Tier 2.** Tier 1 had to ship full-rebuild helpers because kadr's animation modifiers were install-only. The kadr v0.10.1 patch (proposed mid-cycle, shipped before Tier 2) added clearing modifiers; Tier 2 dropped the ~120 LOC of helper code in the same PR as the SpeedCurveEditor wire-up.
- **Track creation UI deferred to v0.4** — empty Tracks aren't engine-valid; "wrap selection in track" needs a selection model that doesn't exist yet. Multi-track projects loaded from disk render and edit today.
- **Overlay tap-to-select on `OverlayHost` deferred to v0.4** — v0.3 uses the `LayersSheet` for selection.
- **Schema migration is forward-only**: v2 documents opened by an old build still reject cleanly via `ProjectLibraryError.unsupportedSchema` — v1 documents on disk continue loading.

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
