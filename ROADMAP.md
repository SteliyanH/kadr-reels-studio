# Reels Studio Roadmap

## v0.1.0 — Editor walking skeleton ✓ shipped

End-to-end editor with the kadr v0.9 + kadr-ui v0.6 + kadr-captions v0.4 + kadr-photos v0.4 surface. Loads sample clips, lets the user pick from Photos, drop overlays, attach music, edit on the timeline, and export.

Tiers:

1. **Editor walking skeleton** — `EditorView` wiring `VideoPreview` + `OverlayHost` + `TimelineView` against a `ProjectStore`. In-memory `[any Clip]` array; rebuild `Video` on each body. Sample clips bundled (system-symbol `ImageClip`s, mirroring kadr-ui's `SimpleViewer`).
2. **PhotosPicker integration** — `PhotoPicker` from kadr-photos in a sheet; tapping + adds resolved clips to the project.
3. **Add Overlay / Music / SFX sheets** — text / sticker / watermark, BGM with auto-ducking, time-pinned SFX with `.at(time:)`.
4. **Inspector + keyframe editor** — `InspectorPanel` + `KeyframeEditor` from kadr-ui v0.6. Tap a clip on the timeline → property panel; per-property keyframe tracks below.
5. **Caption ingest** — drop a `.srt` / `.vtt` / `.itt` / `.ass` / `.ssa` file → cues land as styled overlays via kadr-captions' styled-VTT bridge or as plain `Caption`s via `Video.captions(_:)`.
6. **Export flow** — preset selector (Reels / TikTok / Square / Cinema), progress UI via `Exporter.run()`, share sheet on completion.
7. **Release prep** — README screenshots, ROADMAP, CHANGELOG, develop → main, tag v0.1.0.

## v0.2.0 — Production polish foundation ✓ shipped

Closes the four "feels like a prototype" gaps: persistence, error surfacing, undo / redo, first-run flow. Five tiers (one a mid-cycle audit fix):

1. **Codable Project + JSON library** — `ProjectDocument` sumtype mirrors of every kadr clip / overlay / filter case; `ProjectLibrary` disk-backed CRUD under App Support; schema-versioned with reject-on-future-version safety.
2. **Project list launch + auto-save** — `ProjectListView` is the new launch root; `EditorView` takes `(document:library:)` and persists every mutation via 0.5s-debounced `.onReceive` Combine pipeline.
3. **Tier 1.5 — close persistence silent-data-loss gaps** *(mid-cycle audit fix)* — TextStyle.color, VideoClip.filters, and Transform on clips now round-trip cleanly. Every kadr Filter case (mono / lut / chromaKey included) survives.
4. **Error toast/alert infra + replace prints** — `AppError` / `ToastCenter` / `ToastView` three-tier severity model. All four `print()` sites replaced; `KeyframeArea` print stubs dropped (read-only is correct for v0.2).
5. **Undo / redo** — `UndoManager`-backed snapshot history; per-action granularity via `groupsByEvent = false`; action-named entries flow to system menu; `@Published canUndo` / `canRedo` flags drive top-bar arrow buttons.

## v0.3.0 — Wire-up ✓ shipped

Bumped kadr floor to **≥ 0.10.1** and kadr-ui floor to **≥ 0.8.0**. Wired every kadr-ui v0.7 / v0.8 surface that shipped during the v0.2 cycle. Seven tiers (one mid-cycle kadr patch):

1. **Schema v2 + keyframe authoring** — `ProjectAnimation<Value>` generic + per-value-type bridges; `transformAnimation` / `opacityAnimation` / `filterAnimations` / `speedCurve` fields on `VideoClipData`; `ProjectStore.addKeyframe / removeKeyframe / retimeKeyframe` route through `applyMutation` for undo + auto-save inheritance.
2. **kadr v0.10.1 patch + speed curve** *(mid-cycle)* — kadr ships animation-clearing modifiers (`transformAnimation(_:)` / `opacityAnimation(_:)` / `filterAnimation(at:_:)` / overlay variants); editor drops ~120 LOC of rebuild helpers. **`SpeedCurveSheet`** wrapping `KadrUI.SpeedCurveEditor` pushed from a per-clip "Speed curve…" inspector row.
3. **Caption editor** — tabbed `AddCaptionsSheet` (Edit / Import). `KadrUI.CaptionEditor` for live cue authoring; existing v0.2 file picker for SRT / VTT / iTT / ASS / SSA. Single `setCaptions(_:)` mutation covers add / remove / retime / text changes uniformly.
4. **Overlay inspector + overlay keyframe editor** — `OverlayInspectorArea` / `OverlayKeyframeArea` siblings to clip-targeted areas. `selectedOverlayID: LayerID?` slot mutually exclusive with `selectedClipID` via `didSet`. `LayersSheet` for selection (overlay-host tap-to-select deferred to v0.4).
5. **Timeline zoom + multi-track** — `Project.zoom: TimelineZoom?` persists per project but bypasses undo (viewport state, not document). `onTrackReorder` routes to `replaceClips`; `onTrackTrim` walks Track + inner clip and applies trim modifiers per kind.
6. **Sticker / image overlay creation** — `AddOverlaySheet` refactored into three tabs (Text / Image / Sticker). Image / Sticker share `PhotoOverlayTab` backed by kadr-photos `PhotoPicker` + `PhotosClipResolver.image` (1024×1024 cap).
7. **Release prep** — README / ROADMAP / CHANGELOG, develop → main, tag v0.3.0.

Suite: 65 → 149 (84 new tests across the cycle).

## v0.4 → v1.0 — UX polish layer *(planned)*

- Two-tier bottom toolbar with selection-driven swap (root verbs ↔ clip-specific actions, animated crossfade).
- Fixed-center playhead during scrub.
- Snap haptics on pinch + drag-snap-to-adjacent-clip.
- Single accent-color thread linking selected clip → active inspector tab.
- Empty / disabled state polish — greyed not hidden; tap-and-hold tooltips.
- Real designed app icon + custom icon family (replace SF Symbols).
- Accessibility wiring — `.accessibilityLabel` / `.accessibilityHint` on every interactive element.
- Spring animation curves on drawer detents; medium thud on delete; success haptic pattern on export.
- **Track creation UI** — "wrap selection in track" (carried over from v0.3 deferral; needs a selection model first).
- **Overlay tap-to-select on `OverlayHost`** — replaces v0.3's `LayersSheet`-only selection.

## v1.0.0 — App Store *(planned)*

Submission alongside kadr v1.0. Working title to be locked here ("Reels Studio" likely conflicts with Meta trademarks; rename before submission).

## Out of scope

- Cloud sync (kadr-pro feature).
- Templates (kadr-pro feature).
- Auto-captions / speech recognition (kadr-pro feature).
- AR effects (not on any kadr roadmap).

## Compatibility

| Reels Studio | kadr | kadr-ui | kadr-captions | kadr-photos |
|---|---|---|---|---|
| 0.1.0 | ≥ 0.9.2 | ≥ 0.6.0 | ≥ 0.4.0 | ≥ 0.4.0 |
| 0.2.0 | ≥ 0.9.2 | ≥ 0.6.0 | ≥ 0.4.0 | ≥ 0.4.0 |
| 0.3.0 | ≥ 0.10.1 | ≥ 0.8.0 | ≥ 0.4.0 | ≥ 0.4.0 |
