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

## v0.4.0 — UX polish (foundations) ✓ shipped

Bumped kadr-ui floor to **≥ 0.9.2** (three mid-cycle micro-patches: v0.9 `fixedCenterPlayhead` + `onZoomSnap`; v0.9.1 `onClipDragSnap`; v0.9.2 multi-select binding + `onLongPressClip`). Seven tiers (Tier 1 split into 1a + 1b mid-cycle):

1. **Two-tier toolbar shell + simple action mutations** *(Tier 1a)* — `EditorToolbar` state machine swaps between root / clip / overlay rows with a spring crossfade. `removeClip` / `duplicateClip` / `removeOverlay` / `duplicateOverlay` / `moveOverlay` mutations.
2. **splitClip + FiltersSheet** *(Tier 1b)* — `splitClip(id:at:)` bisects at the playhead with structured `SplitResult` failure modes. `FiltersSheet` exposes the eleven scalar filter cases via leading `+` menu + swipe-to-delete.
3. **Fixed-center playhead + schema v3** — `Project.fixedCenterPlayhead: Bool` (default `true`) wires kadr-ui v0.9's modifier. Schema bumped 2 → 3 additively.
4. **Snap haptics + accent threading** — `HapticEngine` actor (`snap` / `thud` / `success`); `TimelineArea` wires both pinch-zoom + drag-snap. `Project.accentColor: Color?` persists as additive hex on v3; `.tint(_:)` at editor root.
5. **Spring detents + delete thud + export success** — uniform `.interactiveSpring(response: 0.35, dampingFraction: 0.78)` on toolbar mode-swap + inspector reveal. Haptics wired into delete + export-complete.
6. **Track creation UI** *(v0.3 carry-over)* — multi-select state (`isMultiSelecting` + `selectedClipIDs`), long-press to enter, `wrapInTrack(ids:)` with contiguous validation + structured failure modes.
7. **Overlay tap-to-select on `OverlayHost`** *(v0.3 carry-over)* — wired against kadr-ui v0.8's existing `.onLayerTap` (RFC errata mid-cycle).
8. **Release prep** — CHANGELOG / README / ROADMAP, develop → main, tag v0.4.0.

Suite: 149 → 210 (61 new tests across the cycle).

## v0.5.0 — Accessibility + settings ✓ shipped

Reels-studio-only cycle — first since v0.2 with no kadr-ui / kadr surface changes. Four tiers:

1. **`AppSettings` + `SettingsView`** — UserDefaults-backed app settings (haptic intensity); per-project prefs (accent / playhead) flow through new `ProjectStore.setAccentColor` (undoable) + `setFixedCenterPlayhead` (no undo) mutations. Gear icon in editor top toolbar.
2. **Accessibility wiring sweep** — `.accessibilityLabel` / `.accessibilityHint` / `.accessibilityValue` across every interactive surface. `ProjectRow.accessibilityDescription(for:)` pure helper for composed row labels.
3. **Empty / disabled state polish** — `.help(_:)` tooltips on every `ToolbarButton`; Export disables on empty project with branching `exportTooltip(hasClips:)`.
4. **Release prep** — CHANGELOG / README / ROADMAP, develop → main, tag v0.5.0.

Suite: 210 → 228 (18 new tests).

## v0.6.0 — Robustness + release engineering ✓ shipped

Bumped kadr floor to **≥ 0.11.0** and kadr-ui floor to **≥ 0.10.1**. Cross-package-audit response cycle — closed the robustness gaps the app had carried since v0.2 (corrupt / future-schema docs silently dropped, raw paths in error toasts, lost-on-force-quit edits, no privacy manifest, no localization extraction, no XCUITest coverage). Nine tiers:

1. **Floor bump + consumer migrations** — `TimelineArea` to event-struct callbacks; `applySpeedCurve` to `Speed.curved` / `.flat`; `ProjectStore+Filters` to keyed `setFilter(for:)` / `removeFilter(for:)`.
2. **Schema v4 migration shim + library recovery** — additive `filterIDs: [String]?` on `VideoClipData`; `ProjectLibrary.skippedProjects` surfaces corrupt / future-schema files; `ProjectListView` recovery section with swipe-to-Details / swipe-to-Discard.
3. **`@SceneStorage` + `scenePhase` flush** — `lastOpenedProjectID` re-pushes the editor on cold launch; `EditorView` persists playhead + selection gated on `documentID`; `.background` force-flushes `autoSave()`.
4. **Error sanitization + Photos permission pre-check** — `ErrorSanitizer` strips file URLs / sandbox paths from messages; `PhotosAuthorizationGate.ensureAccess()` routes `.denied` / `.restricted` to a Settings-redirect alert.
5. **Gesture-driver tests** — `GestureWiringTests` ViewInspector smokes. Snapshot tests trialed mid-cycle and dropped — `swift-snapshot-testing` UIImage baselines drift between contributor laptops and `macos-15` runners; deferred until a pinned-Xcode re-record job lands.
6. **XCUITest integration / E2E suite** — `ReelsStudioUITests` with five critical flows (empty state, new project, sample, settings gear, back navigation). `--ui-test-reset` launch arg wipes the projects directory between runs.
7. **Localization extraction** — `Resources/en.lproj/Localizable.strings` catalogues ~150 user-facing strings; SwiftUI's `LocalizedStringKey` auto-bridges literal call sites. Parameterized keys (counts / percentages / paths) carry format specifiers for future call-site migration.
8. **Release engineering** — `PrivacyInfo.xcprivacy` with FileTimestamp / UserDefaults / DiskSpace required-reason API categories; fastlane scaffolding (`Gemfile`, `Appfile`, `Matchfile`, `Fastfile` beta / release / refresh_match lanes); Sentry SDK wired with DSN-gated boot.
9. **Release prep** — CHANGELOG / README / ROADMAP, develop → main, tag v0.6.0.

Suite: 228 → 252 unit + 5 UI (29 unit + 5 UI new across the cycle).

## v0.7.0 — Editor UX catch-up ✓ shipped

CapCut-baseline parity. Closed the *creator surface* gaps a returning CapCut / TikTok / Reels user expects on day one. Bumped kadr floor to **≥ 0.12.0** and kadr-ui floor to **≥ 0.10.2**. Six tiers:

1. **Audio trim wiring** — `ProjectStore.applyAudioTrim(...)` shifts startTime + reduces explicitDuration; `TimelineArea.onAudioTrim` wires kadr-ui v0.10.2's callback + snap haptic. Music + SFX share the same `audioTracks` array → single mutation handles both. Trailing trim on a row without `explicitDuration` is a no-op (asset length not synchronously available).
2. **Transitions picker UI** — `TransitionKind` UI mirror (fade + dissolve; kadr's slide deliberately omitted from persistence scope). `insertTransition` / `removeTransition` mutations with distinct action names. `TransitionsSheet` (`LazyVGrid` of tiles + 0.1–2.0s duration slider). Toolbar "Transition" button gated on `clipHasSuccessor`.
3. **Text effects inspector + schema v5** — additive `strokeWidth` / `strokeColorHex` / `shadowOffsetX/Y` / `shadowBlur` / `shadowColorHex` on `TextOverlayData` AND `TitleSequenceData`. v1–v4 docs decode with nil. `setTextStroke` / `setTextShadow` mutations + `rebuildTextOverlay` pure helper. `TextEffectsSection` view appended under `OverlayInspectorPanel` for text overlays.
4. **Chroma key UI** — `addChromaKey(id:color:threshold:)` mutation routes through `addFilter`. Dedicated `ChromaKeySheet` with color preview + `ColorPicker` + threshold slider, defaults green / 0.4. `FiltersSheet`'s + menu gains "Chroma Key…" entry.
5. **Project thumbnails** — `ProjectThumbnailRenderer` (VideoClip via `AVAssetImageGenerator`, ImageClip via `CGImageSource`). JPEG cache under App Support keyed by `<id>-<modifiedAt-unix>.jpg` for lazy invalidation. `ProjectThumbnailTile` sync-lookup + async render-on-appear; deterministic gradient placeholder for empty projects.
6. **Release prep** — CHANGELOG / README / ROADMAP, develop → main, tag v0.7.0.

Suite: 254 → 291 unit + 5 UI (37 unit new across the cycle).

Paired with **kadr v0.12.0** + **kadr-ui v0.10.2** which shipped during the cycle.

## v0.7.1 — iOS 17 floor + `@Observable` migration ✓ shipped

Platform modernization, not features. Raises the deployment floor to **iOS 17** and migrates the five app stores (`ProjectStore`, `ProjectLibrary`, `AppSettings`, `ToastCenter`, `LibraryHost`) from `ObservableObject` to the `@Observable` macro — the payoff of the coordinated ecosystem iOS 17 move (kadr v0.15 / kadr-ui v0.12 / kadr-captions v0.8 / kadr-photos v0.7 / this). Auto-save debounce rebuilt on structured concurrency (no Combine); the removed kadr `filterAnimation(at:)` call migrated to the keyed API. 291 unit + 5 UI tests pass. No user-facing change; v0.8 features are unaffected.

## Modernist design-system migration

**Status:** ✓ Implemented (Tiers 1–5 + fixes landed on feature/modernist-design-system)

Design-only cycle — zero features, zero state mutations. Visual overhaul of every app screen via a published token layer: `ReelTheme.swift` (two palettes for print chrome + dark studio ground) + `ReelStyles.swift` (reusable component styles), Archivo variable font (400/600/800 instanced), constrained accent picker, and a complete call-site migration across ~25 view files. Five binding decisions shape the system: two grounds one palette, red accent, constrained accent control, collapsed semantic colours, and grayscale footage everywhere except the preview stage. Known gaps include kadr-ui 0.12.0 ceiling on customization (zero-theming API by design policy), swipe-back regression fixed via UIGestureRecognizerDelegate, and Dynamic Type audit deferred to v1.0.

See `DESIGN.md` § Modernist design-system migration for the full RFC.

## v0.8.0 — Platform polish + import/export *(planned)*

Last cycle before v1.0 App Store submission. **iOS 17 floor and `@Observable` migration shipped in v0.7.1.** No new AI features — auto-captions, person cutout, and Vision-based smart crop all moved to kadr-pro per the [Kadr Pro scope](https://github.com/SteliyanH/kadr/blob/main/ROADMAP.md#kadr-pro). What's left to ship in the OSS app:

1. **iPad polish.** Split-view layout (project list on the leading column, editor on the trailing), hardware-keyboard shortcuts (⌘N new project, ⌘Z undo / ⇧⌘Z redo, ⌘. cancel export, space play/pause), Apple Pencil scrubbing with hover state.
2. **Project import/export.** `.kadr` documents — zipped bundle of `ProjectDocument.json` + every embedded image / LUT / caption file referenced. SwiftUI `.fileExporter` / `.fileImporter` on the project list. Enables "share to TestFlight tester" without screen-recording the editor.
3. **PiP export preview.** While `Exporter.run()` is in flight, render the in-progress frame in a corner-pinned overlay so the user can continue editing the next project. Pairs with kadr v0.13's `AVAssetImageGenerator` reuse (perf cycle).
4. **Sentry DSN wiring + crash reporting end-to-end.** v0.6 Tier 8 scaffolded `CrashReporter.startIfConfigured()` but never connected to a real DSN. Wire the `SentryDSN` Info.plist entry via fastlane, validate the trace-sample-rate plumbing, ship a "Help → Send diagnostic info" affordance.
5. **kadr-ui styling RFC** *(upstream, blocks full editor fidelity).* Modernist design cycle exposed hard limits in kadr-ui v0.12.0's zero-theming API. Propose and implement an `EnvironmentValues`-based appearance modifier through existing private helpers, allowing downstream apps to customize playhead / clip-cell colours, lane heights, and waveform rendering. Track as a separate kadr-ui RFC; depends on community demand.
6. **Release prep + tag v0.8.0.**

Six tiers. Pairs with **kadr v0.13** (engine perf); v0.8 doesn't depend on kadr-ui v0.12 anymore (v0.7.1 already uses it).

## v0.9.0 — Transport band

Playback controls missing since v0.1 — the editor had a stage and a timeline but no affordance between them to run a composition. A single-tier cycle scoped at the transport band (skip-back · play/pause · skip-forward · time readout · loop · fullscreen). Targets **kadr-ui 0.14.0** (VideoPreview bindings already ship); no upstream kadr changes needed (#73).

1. **Transport band UI** — horizontal strip between stage and timeline. Leading group: skip-back / play/pause (26pt prominent accent fill) / skip-forward. Center: elapsed/total timecode readout ("0:01 / 0:06") in numeric type token (elapsed full text, total muted). Trailing: loop toggle and fullscreen button. Skip step is 1.0 second (fixed, not frame-step — VideoPreview ignores seeks under 0.05s and one frame at 30fps is 0.033s, so the button would silently do nothing; a second is clear of the floor and matches the timecode unit). Play on a finished composition restarts at zero. Loop is implemented in the app rather than `VideoPreview(loops:)` because kadr-ui captures that parameter at player construction and does not rebuild on change, which would make the toggle inert; the app restarts playback itself when `isPlaying` falls. Loop is session state on `ProjectStore` — no persistence, no schema change (ProjectDocument stays v5), no undo timeline. Scene-storage playhead write is gated so it does not fire on every playback tick; flushes fire when playback stops and when the app backgrounds. Fullscreen collapses editor chrome in place (no new route); the band stays visible so the exit control stays reachable.

## v1.0.0 — App Store *(planned)*

- Final name lock (revisit "Reels Studio" before submission — likely conflicts with Meta trademarks).
- Real designed app icon family (replaces SF Symbol placeholder).
- App Store metadata — screenshots, description, age rating, privacy manifest.
- Submission alongside kadr v1.0.

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
| 0.4.0 | ≥ 0.10.1 | ≥ 0.9.2 | ≥ 0.4.0 | ≥ 0.4.0 |
| 0.5.0 | ≥ 0.10.1 | ≥ 0.9.2 | ≥ 0.4.0 | ≥ 0.4.0 |
| 0.6.0 | ≥ 0.11.0 | ≥ 0.10.1 | ≥ 0.4.0 | ≥ 0.4.0 |
| 0.7.0 | ≥ 0.12.0 | ≥ 0.10.2 | ≥ 0.4.0 | ≥ 0.4.0 |
