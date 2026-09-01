# Reels Studio — Design Document

## v0.1.0 design — Editor walking skeleton

The flagship reference app for kadr's v0.9 / v0.6 / v0.4 / v0.4 surface. Real consumer codebase using every kadr + kadr-ui + kadr-captions + kadr-photos component end-to-end. Aims for "open this repo, read the source, understand how to use kadr in a real app."

### Problem

`kadr-ui`'s `Examples/SimpleViewer` is a single-file snippet — fine for "drop this into a fresh Xcode project to see kadr-ui render," not enough to demonstrate end-to-end editor flows (project state, clip add / reorder / trim / inspector / keyframe editor / caption ingest / export). Reels Studio fills that gap.

### Scope lock — v0.1.0

In scope:
- **Editor screen** — `EditorView` composing `VideoPreview` + `OverlayHost` + `TimelineView` against a `ProjectStore` (Observable, owns `[any Clip]` + overlays + audio + captions).
- **`ProjectStore`** value owner — rebuilds `Video` on every body invalidation. `@Observable` for SwiftUI driver.
- **Photos integration** — `PhotoPicker` from kadr-photos in a sheet; resolved clips append to the project's clips array.
- **Add overlay sheet** — text / sticker / watermark layouts; drag-to-position via `OverlayHost.onLayerDrag`.
- **Add music sheet** — pick from device library or sample bundle; volume + ducking sliders.
- **Add SFX sheet** — pick a one-shot sound; pin to a composition time via slider.
- **Inspector panel** — tap a clip on the timeline → `KadrUI.InspectorPanel` slides up. Transform + opacity + filter intensity sliders rebuild the project's clips.
- **Keyframe editor** — `KadrUI.KeyframeEditor` below the timeline; tap-to-add at playhead, long-press to remove, drag to retime.
- **Caption ingest** — drop a `.srt` / `.vtt` / `.itt` / `.ass` / `.ssa` file → cues attach via `Video.captions(_:)` or render as styled `TextOverlay`s through kadr-captions' v0.3 bridge.
- **Export flow** — preset selector, progress UI via `Exporter.run()`, share sheet on completion.
- **Bundled sample clips** — system-symbol `ImageClip`s following the `SimpleViewer` pattern, so the app runs first-launch without external setup.
- **Distribution.** Swift Package today (`swift build` / `swift test`). Xcode `.xcodeproj` wrapper for App Store distribution lands as a follow-up — the `Sources/ReelsStudio/` layout is already the app target's expected shape.

Out of scope (v0.2+ or rejected):
- **Project save / load to disk** — in-memory only at v0.1; serialization is v0.2's headline.
- **Cloud sync / templates / auto-captions / AR effects** — out of scope forever for the reference app (kadr-pro territory or non-goal).
- **Multi-project navigation** — single-project app at v0.1; project picker arrives with v0.2 persistence.
- **Speed-curve UI** — defer; kadr-ui doesn't ship the speed-curve editor yet.

### Architecture

```
ReelsStudioApp.swift                    // @main App, single window with EditorView
├── Editor/
│   ├── EditorView.swift               // VideoPreview + OverlayHost + TimelineView + toolbar
│   ├── PreviewArea.swift              // VideoPreview + OverlayHost composed
│   ├── TimelineArea.swift             // TimelineView wrapper with toolbar (+ Clip / + Overlay / etc.)
│   ├── InspectorArea.swift            // KadrUI.InspectorPanel wrapper, hidden when no selection
│   └── KeyframeArea.swift             // KadrUI.KeyframeEditor wrapper, hidden when no selection
├── Sheets/
│   ├── AddOverlaySheet.swift
│   ├── AddMusicSheet.swift
│   └── AddSFXSheet.swift
├── Project/
│   ├── Project.swift                  // value type holding clips / overlays / audio / captions
│   ├── ProjectStore.swift             // @Observable owner of Project
│   └── SampleProject.swift            // first-launch bundled clips
├── Captions/
│   └── CaptionImportFlow.swift        // file picker → kadr-captions → either Video.captions(...) or styledCaptions(...)
└── Export/
    └── ExportFlow.swift               // preset selector + progress UI + share sheet
```

State management: plain `@Observable` (iOS 17+ syntax, falls back to `ObservableObject` for iOS 16). No Redux / TCA — the example must be readable.

### Tier breakdown

- **Tier 0** *(this PR)* — design doc + scaffold (Package.swift, README, ROADMAP, CHANGELOG, .gitignore, LICENSE, CI). Source skeleton for `ReelsStudioApp.swift` + `Project` so the package compiles. No screens.
- **Tier 1** — `EditorView` walking skeleton: preview + timeline against the `ProjectStore` with bundled sample clips. ~250 LOC + tests.
- **Tier 2** — Photos integration: `PhotoPicker` sheet, resolved clips append. ~150 LOC.
- **Tier 3** — Add Overlay / Music / SFX sheets. ~300 LOC.
- **Tier 4** — Inspector + keyframe editor wired to project state. ~200 LOC.
- **Tier 5** — Caption ingest sheet (file picker → cues attach). ~150 LOC.
- **Tier 6** — Export flow (preset selector, progress UI, share sheet). ~200 LOC.
- **Tier 7** — Release prep: screenshots, README polish, develop → main, tag v0.1.0.

### Test strategy

UI-driven app — most coverage lives in pure helpers (`Project` mutation logic, `SampleProject` builder), plus SwiftUI-body smoke tests on each top-level screen. Live UX tested by running the app.

Target test count for v0.1: ~30 across the cycle.

### Compatibility

Reels Studio v0.1.0 requires:
- kadr ≥ 0.9.2
- kadr-ui ≥ 0.6.0
- kadr-captions ≥ 0.4.0
- kadr-photos ≥ 0.4.0
- iOS 16+, macOS 13+, visionOS 1+. tvOS excluded (kadr-photos doesn't ship there).

### Open questions

- **Xcode project wrapping.** When does the `.xcodeproj` land? Probably alongside Tier 7's release prep — the SPM layout works for development; App Store distribution needs the project file. Xcode 15+ supports SPM-based iOS apps directly, but the Xcode-project path stays the conventional choice for App Store assets / entitlements / Info.plist.
- **`@Observable` vs `ObservableObject`.** `@Observable` is iOS 17+; we target iOS 16+. For v0.1 we'll use `ObservableObject` to keep the deployment floor; a v0.2 patch can switch when iOS 17+ is acceptable.
- **App Store name.** "Reels Studio" likely conflicts with Meta trademarks. Working title only — final name decided alongside v1.0 submission.
- **State store choice.** Plain `ObservableObject` for v0.1. If state grows complicated, a v0.2+ swap to TCA / a real architecture is fine.

---

## v0.2 — Production polish (Foundation)

**Status:** RFC. No code yet.

### Motivation

v0.1 ships a walking-skeleton editor against the kadr v0.9.2 + kadr-ui v0.6 surface. Every toolbar button maps to a real flow, but the app feels like a prototype because it lacks four production-table-stakes layers:

1. **Persistence.** The current build launches into a hardcoded sample project; there is no way to save / load / list user work. Closing the app loses everything. (`Project.swift:8` notes "v0.1.0 keeps everything in memory — no persistence. v0.2 adds Codable + JSON.")
2. **Error surfacing.** Four `print()` sites silently swallow real failures: photo resolution failure (`AddClipFlow.swift:60`), and the three keyframe editor stubs (`KeyframeArea.swift:29, 32, 35`). Users see no feedback when something goes wrong.
3. **Undo / redo.** Every mutation is destructive; deleting a clip or moving a marker is permanent. Real editor apps treat undo as table stakes — top toolbar, always visible.
4. **First-run UX.** Launch jumps straight into a sample editor. There is no project list, no empty state, no way for the user to start from a blank canvas.

The v0.2 cycle closes these four gaps. The downstream cycles (v0.3 wire-up, v0.4→v1.0 polish) can't build a production-feeling app without them.

### Public surface

```swift
// MARK: - Persistence

public struct Project: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var name: String
    public var createdAt: Date
    public var modifiedAt: Date
    public var clips: [ProjectClip]    // sumtype mirroring `any Clip` for codable round-trip
    public var overlays: [ProjectOverlay]
    public var audioTracks: [ProjectAudioTrack]
    public var captions: [Caption]
    public var compositionDuration: CMTime
}

@MainActor
public final class ProjectStore: ObservableObject {
    @Published public private(set) var project: Project
    public let undoManager: UndoManager

    /// Apply a mutation through the undo stack. Pure store-side — the View calls
    /// these for every edit so undo / redo and auto-save happen transparently.
    public func apply(_ mutation: ProjectMutation)
    public func undo()
    public func redo()
}

public enum ProjectMutation: Sendable {
    case addClip(ProjectClip)
    case removeClip(id: UUID)
    case reorderClips(from: Int, to: Int)
    case trimClip(id: UUID, leadingTrim: CMTime, trailingTrim: CMTime)
    case setClipTransform(id: UUID, transform: Transform)
    case setClipOpacity(id: UUID, opacity: Double)
    case setClipFilterIntensity(id: UUID, filterIndex: Int, intensity: Double)
    case addOverlay(ProjectOverlay)
    case removeOverlay(id: UUID)
    case addAudioTrack(ProjectAudioTrack)
    case removeAudioTrack(id: UUID)
    case setCaptions([Caption])
    case rename(String)
    // v0.3 adds: addKeyframe / removeKeyframe / retimeKeyframe / setSpeedCurve
}

// MARK: - Project library

@MainActor
public final class ProjectLibrary: ObservableObject {
    @Published public private(set) var projects: [Project]

    public func newProject(name: String) -> Project
    public func load(id: UUID) throws -> Project
    public func save(_ project: Project) throws
    public func delete(id: UUID) throws
    public func duplicate(id: UUID) throws -> Project
}

// MARK: - Error surfacing

public enum AppError: LocalizedError, Sendable {
    /// Recoverable: photo resolution failed, file format unsupported, trim out
    /// of bounds. Surfaced as a top-anchored toast; auto-dismiss 2s.
    case transient(message: String, underlying: String? = nil)

    /// Resumable: export failed, save failed. Surfaced as inline sheet with
    /// Retry / Cancel.
    case resumable(message: String, retry: @Sendable () async -> Void)

    /// Catastrophic: project corrupt, can't reach Photos library. Surfaced as
    /// full alert with Recover / Quit.
    case catastrophic(message: String)
}

@MainActor
public final class ToastCenter: ObservableObject {
    @Published public private(set) var current: Toast?
    public func show(_ toast: Toast)
}

public struct ToastView: View { /* top-anchored, accent-bordered, auto-dismiss */ }

// MARK: - First-run flow

@available(iOS 16, *)
public struct ProjectListView: View {
    /// New launch screen. Lists existing projects, surfaces "+ New Project"
    /// CTA, taps a row → `EditorView` for that project. Auto-saves continuously
    /// in `EditorView`; no Save button anywhere.
    public init(library: ProjectLibrary)
}
```

### File layout (additions)

- `Sources/ReelsStudio/Persistence/Project+Codable.swift` — sumtype mirrors for `any Clip` / `any Overlay` (kadr's existential types aren't directly Codable; serialize by case)
- `Sources/ReelsStudio/Persistence/ProjectLibrary.swift` — JSON file IO under `~/Library/Application Support/ReelsStudio/Projects/<uuid>.json`
- `Sources/ReelsStudio/Persistence/ProjectMutation.swift` — mutation enum + apply implementation
- `Sources/ReelsStudio/State/ProjectStore.swift` — extended with undo / redo
- `Sources/ReelsStudio/Errors/AppError.swift` + `Errors/ToastCenter.swift` + `Errors/ToastView.swift`
- `Sources/ReelsStudio/Screens/ProjectListView.swift` — new launch root
- `Sources/ReelsStudio/ReelsStudioApp.swift` — root swap from `EditorView` → `NavigationStack { ProjectListView }`

### Tier breakdown

- **Tier 0** *(this PR)* — RFC only. No code.
- **Tier 1** — Codable `Project` + `ProjectLibrary` + JSON IO + sumtype mirrors for `any Clip` / `any Overlay`. ~400 LOC + 25 tests. Migrating the existing in-memory store to read / write through the library happens here.
- **Tier 2** — Project list launch screen + auto-save in `EditorView` + new-project flow. ~250 LOC + 10 tests.
- **Tier 3** — Error toast / alert infra + replace the four `print()` sites + integrate into existing flows (export, photo picker, file imports). ~200 LOC + 8 tests.
- **Tier 4** — Undo / redo via `UndoManager` + `ProjectMutation` apply path + top-toolbar arrows. ~300 LOC + 15 tests.
- **Tier 5** — Release prep + ship as **v0.2.0**.

### Test strategy

- **Codable round-trip** — every `ProjectMutation` case → encode → decode → verify equality. Stress test with sample projects covering clips / overlays / audio / captions.
- **Library IO** — save, load, list, delete, duplicate. Disk fixtures under a temp directory; cleanup in tearDown.
- **ProjectMutation apply** — pure-function tests for every case; property-based test that `apply(m).undo() == identity` for every mutation kind.
- **Toast / error surfacing** — view-state assertions (current toast non-nil after show, auto-dismiss timer). UI-level testing manual.
- **Project list** — body smoke + new-project / delete-project flows.

Target test count: ~60 new tests across the cycle. Suite floor ~30 → ~90.

### Compatibility

- **Source-breaking at the consumer (the app).** v0.1's hardcoded `EditorView(store:)` becomes `ProjectListView(library:)`. The store internals reshape too — `apply(_:)` replaces direct property writes.
- **No upstream library changes.** Stays on kadr ≥ 0.9.2 / kadr-ui ≥ 0.6.0. v0.3 will bump kadr-ui to 0.8.x for the new editor surfaces.
- **Storage format versioned.** `Project.schemaVersion: Int` field carried in JSON; migration path stays open for v0.3 / future cycles.

### Open questions (track in PRs, not blocking RFC)

- **iCloud sync.** Defer. App Support directory is local-only in v0.2; iCloud Documents container is a v1.x add if community demand surfaces.
- **Export queue.** Currently single export at a time, modal. v0.2 keeps that; queueing is post-v1.0.
- **Project versioning UI.** No "history" view of project versions in v0.2. Standard undo/redo only — checkpointed history is desktop-think.
- **Sumtype mirrors vs. type-erased Codable.** Going with sumtypes for explicit migration safety. Type-erased polymorphic Codable is tempting but fragile across kadr version bumps.

---

## v0.3 — Production polish (Wire-up)

**Status:** Sketch. Detailed RFC after v0.2 ships.

Closes the "kadr-ui v0.7 / v0.8 surfaces unused" gap.

- Wire `KeyframeEditor` callbacks to real `Animation<T>` mutations (`ProjectMutation.addKeyframe` / `removeKeyframe` / `retimeKeyframe`).
- Surface `SpeedCurveEditor` behind a per-clip "Speed curve…" inspector row.
- Replace `AddCaptionsSheet` (ingest-only) with `CaptionEditor` driving editable cues.
- Route overlay selection → `OverlayInspectorPanel` + `OverlayKeyframeEditor`. Add overlay-selection binding to `OverlayHost`.
- Bind `TimelineZoom` to a project-state field; persist zoom level per project.
- Multi-track UI: `Track {}` blocks visible, with `onTrackReorder` / `onTrackTrim` wired through `ProjectMutation`.
- Sticker / image overlay support in `AddOverlaySheet` (closes the v0.1.x deferral).

Bumps kadr-ui floor to **≥ 0.8.0**.

---

## v0.4 — UX polish (foundations)

**Status:** RFC. No code yet.

### Motivation

v0.2 + v0.3 shipped the *plumbing*: persistence, undo / redo, error infra, project list, every kadr-ui v0.7 / v0.8 editor surface wired in. Functionally the app is feature-complete against the kadr ecosystem as it exists today. What's left is the UX layer — the difference between "all the buttons work" and "this feels like an app you'd actually use." A 30-second hands-on with v0.3 surfaces the gaps: the bottom toolbar has the same six verbs whether you have a clip selected or not; the playhead drifts off-screen during scrub instead of staying centered; pinch-zoom has no snap haptic so you can't feel beat alignment; selecting a clip changes nothing chromatically about the inspector; sheet detents pop instead of spring; export completes silently. None of these are missing features — they're missing *feel*.

This cycle closes the foundational half of that gap. Accessibility wiring + empty-state polish + app icon + final name lock + App Store submission live in **v0.5 / v1.0** (separate cycles, sketched at the end of this doc).

### Scope lock — v0.4

In scope:
- **Two-tier bottom toolbar** with selection-driven swap (root verbs ↔ clip-specific actions, animated crossfade).
- **Fixed-center playhead** during scrub — timeline scrolls under it.
- **Snap haptics** on pinch-zoom + drag-snap-to-adjacent-clip.
- **Single accent-color thread** linking selected clip → active inspector tab.
- **Spring animation curves** on drawer detents; medium thud on delete; success haptic pattern on export.
- **Track creation UI** — "wrap selection in track" (carried over from v0.3 deferral; needs a multi-select model first).
- **Overlay tap-to-select on `OverlayHost`** — replaces v0.3's `LayersSheet`-only selection (carried over from v0.3 deferral; needs a kadr-ui callback).

Out of scope (v0.5 / v1.0 / rejected):
- **Accessibility sweep** — own cycle (v0.5). `.accessibilityLabel` / `.accessibilityHint` / `.accessibilityValue` on every interactive element is mechanical but exhaustive; bundling it with feel-polish would obscure both.
- **Empty / disabled state polish** — bundles with v0.5 accessibility (greyed-not-hidden + tap-and-hold tooltips share the same audit pass).
- **Real designed app icon family** — v1.0 (paired with name lock + App Store submission; designing an icon for a working title that's about to change is wasted work).
- **Final name lock** — v1.0. "Reels Studio" likely conflicts with Meta trademarks; revisit before submission.
- **Optimistic UI on trim handles** — partially landed in kadr-ui v0.7 (`liveTrimMetrics`); reels-studio side is wired and feels fine. No further work needed.

### Dependency floors

- **kadr-ui ≥ 0.9.0** (up from 0.8.0). New surface needed for Tiers 2 + 3 only:
  - `TimelineView.fixedCenterPlayhead(_:)` modifier — opt-in playhead-centered scroll mode (current default keeps the playhead anchored to its time position and lets it drift).
  - `TimelineView.onZoomSnap(_:)` callback — fires when pinch-zoom crosses a snap threshold (frame / second / 5s / 30s). reels-studio uses it to fire haptics; kadr-ui owns the threshold list because it already owns the zoom math.

  *Errata (post-RFC):* `OverlayHost.onLayerTap(_:)` was originally listed here for Tier 6, but it already ships in kadr-ui v0.8 — Tier 6 wires against the existing surface and doesn't need v0.9. The kadr-ui v0.9 RFC scope shrinks accordingly.

  This is a kadr-ui v0.9 RFC unblocked by — and shipping mid-cycle of — this v0.4 cycle, the same shape as the kadr v0.10.1 patch that landed mid-v0.3. Tier 2 ships against a local-path kadr-ui pin; flips to the released floor before the v0.4 release PR.
- kadr / kadr-captions / kadr-photos floors unchanged from v0.3 (≥ 0.10.1 / ≥ 0.4.0 / ≥ 0.4.0).

### Tier breakdown

#### Tier 1 — Two-tier bottom toolbar

The bottom toolbar today (`TimelineArea` / `EditorView` toolbar slot) shows the same verbs (`+ Clip`, `+ Overlay`, `+ Music`, `+ SFX`, `Captions`, `Layers`, `Export`) regardless of selection. CapCut / VN swap to a clip-specific row when a clip is selected (split / duplicate / speed / delete); reels-studio lacks this entirely.

**Approach.** Introduce `EditorToolbar` as a state machine over `(selectedClipID, selectedOverlayID)`:
- **No selection** → root row (existing verbs).
- **Clip selected** → clip-action row (`Split` / `Duplicate` / `Speed` / `Filters` / `Delete`).
- **Overlay selected** → overlay-action row (`Duplicate` / `Bring forward` / `Send back` / `Delete`).

`Split` routes to a new `ProjectStore.splitClip(id:at:)` mutation that walks the clip stack, splits the matched `VideoClip` / `ImageClip` at the current `playheadTime`, and replaces the single entry with the two halves. `Speed` pushes the existing `SpeedCurveSheet`. `Filters` pushes a new `FiltersSheet` (selected clip's filter stack — already round-trips through schema, just needs a UI). `Duplicate` / `Delete` route to existing mutations.

Crossfade: `.transition(.opacity.animation(.easeInOut(duration: 0.15)))` keyed by selection-state enum.

Files: `Sources/ReelsStudio/Editor/EditorToolbar.swift` (new), edits to `EditorView.swift` + `TimelineArea.swift`. Tests: state-machine row selection (`EditorToolbarTests`); `splitClip` correctness across clip kinds (`SplitClipTests`).

#### Tier 2 — Fixed-center playhead + kadr-ui v0.9 patch

kadr-ui v0.9 RFC ships first this tier (separate repo, separate PR). `TimelineView.fixedCenterPlayhead(_:)` modifier inverts the scroll model: the timeline scrolls under a screen-anchored playhead instead of the playhead drifting toward the right edge.

reels-studio side: opt-in via a per-project `Project.fixedCenterPlayhead: Bool` (default `true`; off only for users who prefer the legacy mode — toggle lands in v0.5 settings). Persists through `ProjectDocument` schema v3 (additive — `Bool?` field, missing = default).

Files: kadr-ui v0.9 patch (separate PR) + `ProjectDocument` schema v3 bump + `TimelineArea.swift` modifier wire-up. Tests: schema v3 forward / back-compat (`SchemaV3Tests`).

#### Tier 3 — Snap haptics + accent threading

**Snap haptics.** kadr-ui v0.9's `onZoomSnap(_:)` callback fires `UIImpactFeedbackGenerator(style: .light).impactOccurred()` on each threshold cross. Drag-snap-to-adjacent-clip mirrors the same call when `TimelineView.onClipDragSnap` (already in kadr-ui v0.8) fires. Single shared `HapticEngine` actor batches calls to avoid re-prep cost on rapid scrub.

**Accent threading.** Replace the four hardcoded `Color.accentColor` sites in `InspectorArea` / `OverlayInspectorArea` / `KeyframeArea` / `OverlayKeyframeArea` with a single `Project.accentColor: Color` (per-project, persisted, default = system accent). Selecting a clip / overlay tints the active inspector tab + the keyframe editor's playhead line + the timeline's selection ring. macOS / visionOS retain system-accent default; iOS users can pick from a palette in v0.5 settings.

Files: `Sources/ReelsStudio/Haptics/HapticEngine.swift` (new); `Project.accentColor` field; `ProjectDocument` schema v3 carries `accentColorHex: String?`. Tests: `HapticEngineTests` (no-op on macOS, gated by `#if canImport(UIKit)`); `AccentThreadingTests`.

#### Tier 4 — Spring drawer detents + export success haptic + delete thud

Sweep every sheet detent + drawer transition in the app and replace `.easeInOut` / linear with `.interactiveSpring(response: 0.35, dampingFraction: 0.78)` (rule of thumb from CapCut's drawer feel — picked by hand-tuning during this tier). One pattern, applied uniformly: `AddOverlaySheet`, `AddCaptionsSheet`, `SpeedCurveSheet`, `LayersSheet`, `ProjectListView`'s navigation push.

**Export success haptic.** `UINotificationFeedbackGenerator().notificationOccurred(.success)` after `Exporter.run()` resolves; followed by the existing share-sheet present.

**Delete thud.** `UIImpactFeedbackGenerator(style: .medium).impactOccurred()` before each `removeClip` / `removeOverlay` mutation (toolbar Delete + swipe-to-delete in `LayersSheet`).

Files: edits across `Sheets/*.swift` + `Editor/EditorToolbar.swift` + `ProjectListView.swift`. Tests: spring/timing values are visual; we lean on existing smoke tests + manual QA. Haptic call sites get unit tests via `HapticEngine` mock.

#### Tier 5 — Track creation UI

v0.3 carry-over. Empty `Track {}` blocks aren't engine-valid; "wrap selection in track" needs a multi-select model that doesn't exist today.

**Multi-select model.** `ProjectStore.selectedClipIDs: Set<LayerID>` replaces `selectedClipID: LayerID?`. Single-select callers read `selectedClipIDs.first` until they're updated. Long-press a clip on the timeline → multi-select mode (CapCut pattern); tap toggles membership; the bottom toolbar swaps to a multi-select row.

**Wrap-in-track.** New `ProjectStore.wrapInTrack(ids:)` mutation: walks `clips`, removes the matched contiguous range, inserts a `Track { ... }` block in their place. Non-contiguous selections are rejected with a transient toast ("Selection must be contiguous to wrap in a track").

Files: `ProjectStore` selection refactor; `EditorToolbar` multi-select row; `wrapInTrack` mutation. Tests: `MultiSelectTests`, `WrapInTrackTests`.

#### Tier 6 — Overlay tap-to-select on `OverlayHost`

v0.3 carry-over. `OverlayHost.onLayerTap(_:)` (kadr-ui v0.8, ships today — *errata: not v0.9 as Tier 2's RFC initially claimed*) fires with `LayerID` on tap of an overlay's hit region. reels-studio routes that to `store.selectedOverlayID = id`. `LayersSheet` becomes secondary (still useful for stacked / off-screen overlays); the primary path is direct.

Because this tier doesn't depend on the kadr-ui v0.9 patch, it could land before Tier 2 if scheduling preference flips. The current ordering keeps the RFC's tier flow intact.

Files: `EditorView.swift` `OverlayHost` modifier wiring. Tests: `OverlayTapToSelectTests` (smoke — verifies the callback writes the selection slot).

#### Tier 7 — Release prep + tag v0.4.0

CHANGELOG / README / ROADMAP / DESIGN updates; develop → main; tag v0.4.0; GH release; reset develop to main.

### Out-of-scope deferrals (recap)

| Deferral | Cycle | Why |
|---|---|---|
| Accessibility sweep | v0.5 | Mechanical + exhaustive; would obscure feel-polish if bundled. |
| Empty / disabled state polish | v0.5 | Same audit pass as accessibility (every interactive element). |
| iOS accent-color picker | v0.5 | Settings UI doesn't exist yet; v0.5 introduces it alongside the legacy-playhead toggle. |
| Real designed app icon | v1.0 | Paired with name lock — designing for a working title is wasted work. |
| Final name lock | v1.0 | "Reels Studio" likely conflicts with Meta. |
| App Store submission | v1.0 | Pairs with the above two. |

## v0.5 — Accessibility + settings

**Status:** RFC. No code yet.

### Motivation

v0.4 closed the feel-polish gap (haptics, springs, accent threading, fixed-center playhead). The two things keeping reels-studio from feeling like a *shippable* iOS app — and from being App-Store-acceptable — are the missing accessibility wiring and the missing surface for the per-project / per-app preferences v0.4 introduced but never exposed.

- **Accessibility.** Every interactive element ships with the default SF Symbol or text label as its sole VoiceOver hint. Long-press multi-select, swipe-to-delete, tap-to-add-keyframe, drag-to-trim — all invisible to a VoiceOver user. App Store reviewers flag this; even setting that aside, omitting a11y is a v1.0 blocker for the "complete reference consumer of the kadr ecosystem" pitch.
- **No way to change v0.4 preferences.** `Project.accentColor` defaults to `nil` (system tint) and the only way to set a custom color is editing JSON on disk. `fixedCenterPlayhead` defaults to `true` with no toggle. `HapticEngine` has no off switch (some users hate haptics; some devices can't render them). All three need a UI.
- **Empty / disabled state polish.** Several places (empty Layers sheet, no-clips export, disabled toolbar buttons) hide rather than grey-out, which makes the editor feel non-deterministic — buttons appear and disappear. Tap-and-hold tooltips help users understand *why* a button is disabled.

This cycle is reels-studio-only — no kadr-ui or kadr surface changes anticipated.

### Scope lock — v0.5

In scope:
- **`SettingsView`** — single-screen sheet pushed from the editor's top toolbar (gear icon). Houses per-project + app-level preferences with the same visual treatment.
- **Accent picker (iOS)** — `ColorPicker` writing to `Project.accentColor`. macOS / visionOS retain the system tint (no picker until the platform-specific surface is worth the cost).
- **Fixed-center-playhead toggle** — bound to `Project.fixedCenterPlayhead`.
- **Haptic strength** — app-level (`AppSettings.hapticIntensity: HapticIntensity`); reels-studio shouldn't ask the user to toggle haptics per project. `HapticEngine`'s public methods route through the setting (off → no-op, light → light/notification, medium → medium/notification).
- **Accessibility wiring sweep** — every interactive element gets `.accessibilityLabel`, `.accessibilityHint`, and `.accessibilityValue` (the latter on stateful controls). Driven by an Xcode Accessibility Inspector pass followed by manual VoiceOver QA.
- **Empty / disabled state polish** — greyed-not-hidden for disabled toolbar buttons + sheet rows; tap-and-hold tooltips on toolbar buttons via `.help(_:)` (iOS 16+ surface).

Out of scope (v1.0 / rejected):
- **Per-project haptic toggles** — overkill; haptic preference is environmental, not creative.
- **VoiceOver-only authoring flows** — best-effort scrub / select / inspector navigation. Full alternative gesture set for VoiceOver is a separate cycle if a real consumer surfaces a need.
- **Dynamic Type / large-text layout audit** — likely needed for v1.0, but its own cycle. v0.5 ships `.accessibilityLabel`s; layout audit lives in v1.0 prep.
- **Reduce Motion** awareness — spring animations could `respond` to `accessibilityReduceMotion`. Not in v0.5 scope; track if QA flags.
- **Custom designed app icon** — v1.0 (paired with name lock).

### Persistence

`AppSettings` — UserDefaults-backed, app-wide. Separate from `ProjectDocument` because the preferences are device-environment scoped, not project-scoped:

```swift
@MainActor
final class AppSettings: ObservableObject {
    @Published var hapticIntensity: HapticIntensity   // .off / .light / .medium
    // future: prefersReducedMotion override, default playhead behavior, etc.
}

enum HapticIntensity: String, Codable, CaseIterable {
    case off, light, medium
}
```

- One `AppSettings` instance hangs off the app root via `@StateObject`, distributed through `@EnvironmentObject` like `ToastCenter`.
- `HapticEngine.shared.snap()` etc. read `AppSettings.hapticIntensity` before firing; off → return early.
- No new schema bump on `ProjectDocument` — the per-project settings already round-trip through the v3 fields added in v0.4 (`accentColorHex`, `fixedCenterPlayhead`).

### Tier breakdown

#### Tier 1 — `AppSettings` + `SettingsView` scaffolding

- `AppSettings` `ObservableObject` (UserDefaults-backed via `@AppStorage` or explicit shims; explicit is simpler given the small surface).
- `SettingsView` — `Form`-based sheet, three sections (Appearance / Playback / Haptics).
  - Appearance: per-project accent (`ColorPicker`); "Use system tint" toggle when the user wants to clear an explicit color.
  - Playback: fixed-center-playhead toggle (per project).
  - Haptics: segmented control (off / light / medium); app-level.
- Editor toolbar gets a gear icon (top-left? — top-right is taken by undo / redo) that pushes the sheet.
- `HapticEngine` routes every fire through `AppSettings.hapticIntensity`. `off` returns early; `light` is unchanged; `medium` upgrades `snap` from light → medium impact and keeps `thud` / `success` as-is.

~250 LOC + ~12 tests (AppSettings persistence round-trip, HapticEngine intensity gating, SettingsView body construction per section).

#### Tier 2 — Accessibility wiring sweep

Audit pass driven by Xcode Accessibility Inspector + manual VoiceOver run. Every interactive site gets at minimum `.accessibilityLabel`; stateful controls get `.accessibilityValue` (e.g. "Opacity, 80%"); buttons with non-obvious action get `.accessibilityHint`.

Targets, in audit order:
- **`ProjectListView`** — row label includes project name + modified date; swipe-to-delete announces action.
- **`EditorView` toolbar** — gear / undo / redo / export each get explicit labels.
- **`EditorToolbar` (all four modes)** — every button gets a value (e.g. disabled state announces "dimmed"; multi-select counter announces "3 selected").
- **`TimelineArea`** — `TimelineView` itself is kadr-ui's; we add `.accessibilityLabel` on the wrapping container ("Timeline, scrub to seek"); long-press hint exposed.
- **`InspectorArea` / `OverlayInspectorArea`** — sliders announce label + current value (`accessibilityValue`).
- **`KeyframeArea` / `OverlayKeyframeArea`** — keyframe markers each announce their property + time.
- **Sheets** — `AddOverlaySheet`, `AddCaptionsSheet`, `SpeedCurveSheet`, `LayersSheet`, `FiltersSheet`, `SettingsView`. Top-level navigation labels + per-row labels.
- **Toasts** — `ToastView` announces via `.accessibilityLiveRegion(.assertive)` (transient) / `.polite` (resumable).

~200 LOC of `.accessibility*` modifier calls + ~8 tests (the harness can read `accessibilityLabel` off rendered views; we lock down the labels for high-signal surfaces — toolbar buttons, inspector slider values).

#### Tier 3 — Empty / disabled state polish

- **Greyed-not-hidden.** Sites currently hiding disabled state instead of dimming get a uniform `.disabled(...)` + `.opacity(0.4)` treatment. Audit list: toolbar buttons that depend on selection (export when no clips, share when no clip); Layers sheet "Wrap" button (Tier 5 already does this — confirm).
- **Tap-and-hold tooltips.** `.help("…")` on every `ToolbarButton` (iOS 16+ shows tooltip on long-press hover; macOS / visionOS show on hover). Tooltips explain *why* a control is disabled when applicable ("Add a clip to enable export").
- **Empty-state polish** — `ProjectListView` empty state already exists; audit `LayersSheet`, `FiltersSheet` (already shows "No filters"), `AddCaptionsSheet`'s Edit tab when no cues exist. Ensure each empty state has an icon + headline + body + CTA where applicable.

~100 LOC + ~6 tests (empty-state body construction, `.disabled` propagation to the inner control).

#### Tier 4 — Release prep + tag v0.5.0

CHANGELOG / README / ROADMAP / DESIGN updates; develop → main; tag v0.5.0; GH release; reset develop.

### Out-of-scope deferrals (recap)

| Item | Cycle | Why |
|---|---|---|
| Real designed app icon | v1.0 | Pairs with name lock. |
| Final name lock | v1.0 | "Reels Studio" likely conflicts with Meta. |
| App Store submission | v1.0 | Pairs with the above. |
| Dynamic Type layout audit | v1.0 prep | Layout review is its own cycle. |
| Reduce Motion override | v1.0 prep | Audit-time decision. |
| VoiceOver-only authoring flows | post-v1.0 | Real-but-niche; track if requested. |

### Open questions

- **Where does the gear icon live?** Top-left navigation slot in the editor? Inside the project list's top toolbar? Both? RFC defaults to "editor toolbar, top-left" for fastest access during editing; revisit if QA flags as discoverable.
- **Accent picker semantics on iOS.** SwiftUI's `ColorPicker` always returns a non-nil `Color`; "use system tint" needs a separate clear button or a "Custom / System" two-state toggle. RFC ships the latter — segmented control between System (nil) and Custom (picker reveal).
- **Haptic strength gating on iPad / Mac.** iPad has a haptic engine on some models; Mac doesn't. RFC keeps the setting visible everywhere but `HapticEngine` already no-ops on non-iOS — the toggle on Mac does nothing observable. Worth a polite "iPhone-only" label, or leave as-is? Lean toward leaving as-is — the no-op is consistent.

## v0.6 — Robustness + release engineering

**Status:** RFC. No code yet.

### Motivation

A cross-package audit before the v1.0 stability commitment surfaced a cluster of robustness gaps the app has been carrying since v0.2 — none of them are user-visible in the happy path, all of them surface as App Store reviewer complaints, lost-work bug reports, or "first launch crashes on locale es-MX" issues. v0.6 is the cycle that closes them.

Pairs with two upstream cycles that have to land first:
- **kadr v0.11** — `CancellationToken` atomicity + `Speed` enum + `FilterID` keyed animations. Schema v3 → v4 migration needed downstream for the filter-id surface.
- **kadr-ui v0.10.0** — callback payload structs + overlay multi-select. Breaking; consumed call sites in `TimelineArea` migrate.
- **kadr-ui v0.10.1** — snapshot + gesture test infrastructure. Reels-studio v0.6 Tier 5 builds on the same harness.

This is the largest reels-studio cycle yet (9 tiers). v0.7 (UX catch-up) and v0.8 (on-device AI) follow.

### Scope lock — v0.6

In scope:
- **Floor bump** to kadr 0.11 + kadr-ui 0.10.1. Migrate every consumer call site to the new event-struct callbacks; pass `Speed` cases through `applySpeedCurve`; key filter animations by `FilterID`.
- **Schema v4 + forward-migration shim.** Adds `filterID: String?` per filter (lazy id generation for v3 docs). Reject only v5+ documents with `ProjectLibraryError.unsupportedSchema`; surface as a "Project too new" inline error instead of silent-skip on `ProjectListView`.
- **Project library recovery screen.** Today: a corrupt JSON file is silently skipped from the list. Tier 2 adds a "Skipped projects" affordance in `ProjectListView` listing corrupt / unsupported files with options to discard, view raw JSON, or attempt re-encode.
- **`@SceneStorage` of editor state.** Last-opened project id, playhead time, selected clip / overlay id; restored on app cold-launch into the same context. Force-flush auto-save on `scenePhase: .background`.
- **Integration / E2E test suite via XCUITest.** 5–10 flows covering: add clip → trim → split → add overlay → export → share; permission denial paths; corrupt-document recovery; multi-select wrap-in-track.
- **Snapshot tests** on `ProjectListView`, `EditorView`, `EditorToolbar` (all four modes), `SettingsView` via kadr-ui v0.10.1's harness.
- **Error-string sanitization.** No file URLs in transient toasts (Photos export temp paths, App Support paths, ...).
- **Photos permission pre-check** in `AddClipFlow`: detect denied / `.limited` access up front and route to a "Grant access" CTA that opens Settings.app instead of failing silently mid-resolution.
- **Localization extraction.** Every user-facing string → `Localizable.strings`. Initial bundle ships en-US only; structure is ready for follow-up locales.
- **Release engineering.** `PrivacyInfo.xcprivacy` manifest; fastlane + match + gym + TestFlight pipeline; Crashlytics integration (or equivalent — Sentry SDK is a one-liner).

Out of scope:
- **Editor UX gaps** (audio waveform editing, transitions picker UI, text effects, chroma key UI, project thumbnails). All v0.7.
- **On-device AI** (auto-captions via SpeechAnalyzer, person cutout via Vision). v0.8.
- **iOS 17 floor / `@Observable` migration.** v0.8 when the kadr-ui floor moves.
- **Multi-device sync / iCloud Documents.** Architecture leaves a door (overridable `ProjectLibrary` directory); no actual sync.

### Tier breakdown

#### Tier 1 — Floor bump

kadr 0.10.1 → 0.11.0. kadr-ui 0.9.2 → 0.10.1 (Tier 1 = 0.10.0 callback structs; gets bumped again at Tier 5 once 0.10.1 ships).

- Migrate `TimelineArea` callbacks to event structs.
- Migrate `applySpeedCurve` to take `Kadr.Speed` cases.
- Migrate `ProjectStore+Filters.swift` to keyed-animation API.

~150 LOC + ~8 tests covering the migration shape.

#### Tier 2 — Schema v4 migration shim + recovery screen

- `ProjectDocument` schema v4 — adds `filterID` per filter; on-load fallback generates a deterministic id from `(clipID, arrayIndex)` for v3 docs so existing projects open cleanly.
- `ProjectLibrary.loadAll()` retains the silent-skip path but **records skipped files** with a reason (`.corruptJSON` / `.unsupportedSchema(version: Int)`).
- New "Skipped projects" inline section in `ProjectListView` with discard / view / re-encode actions.
- "Project too new" UI when v5+ documents are encountered.

~250 LOC + ~12 tests covering v3 → v4 round-trip, corrupt-file detection, recovery actions.

#### Tier 3 — `@SceneStorage` + `scenePhase` flush

- `@SceneStorage("editorProjectID") var lastEditorProjectID: String?` in `LibraryHostView`; on cold launch with a non-nil id, route into the editor.
- Per-project session state — playhead time, selectedClipID, selectedOverlayID — persisted via `@SceneStorage` keyed by project UUID. (Document state already auto-saves; this is *session* state.)
- `scenePhase` observer in `EditorView`: on transition to `.background`, force-flush auto-save bypassing the 0.5s debounce.
- Background task identifier for in-flight export to give iOS more grace before suspension.

~180 LOC + ~10 tests covering state-restoration round-trip, background flush bypassing debounce.

#### Tier 4 — Error sanitization + Photos permission pre-check

- Audit every `toasts.show(.transient(...))` call site — replace any error that may carry a file URL with a sanitized message.
- `AppError.transient(_:prefix:)` factory grows a `redactingPaths: Bool` option (default true).
- `AddClipFlow` checks `PHPhotoLibrary.authorizationStatus(for: .readWrite)` before presenting the picker. `.denied` / `.restricted` → CTA sheet routing to `UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)`. `.limited` → toast + picker (matches current behavior, but now intentional).

~120 LOC + ~8 tests.

#### Tier 5 — Snapshot + gesture-driver tests

- Floor bump to kadr-ui 0.10.1 (gestures + snapshot harness).
- Snapshot baselines for: `ProjectListView` (empty / populated), `EditorView` (no selection / clip selected / overlay selected / multi-selecting), `EditorToolbar` (all four modes), `SettingsView` (Custom accent + System accent + every haptic intensity), `LayersSheet` (empty / populated), `FiltersSheet` (empty / populated).
- Gesture-driver tests via kadr-ui's new harness: long-press → multi-select toggle; pinch-zoom → haptic; export-completion → success haptic.

~300 LOC of snapshot fixtures + ~15 gesture tests.

#### Tier 6 — Integration / E2E suite (XCUITest)

- New test target: `ReelsStudioUITests`.
- 5–10 flow tests:
  1. Sample project → trim first clip → split second clip → export → share-sheet appears.
  2. Empty project → add 3 clips from Photos → multi-select 2 → wrap in track → undo.
  3. Photos permission denied → CTA → routes to Settings.
  4. Corrupt project file in library directory → "Skipped projects" surfaces → discard.
  5. Background app mid-edit → relaunch → editor restores playhead + selection.
  6. Generate captions (placeholder — wires Tier 8's localization but real path is v0.8).
  7. Toggle haptics off → pinch-zoom → no haptic fires (verify via `HapticEngine` test mode).
  8. Force-kill app during export → recovery state surfaces on relaunch.

~400 LOC of XCUITest. Runs in CI on a single iOS simulator config.

#### Tier 7 — Localization extraction

- Audit every user-facing `String` literal across the source tree.
- Move to `Localizable.strings`; wrap call sites with `String(localized:)`.
- Initial bundle: en-US only.
- Strategy doc for adding en-GB, es-ES, es-MX, fr-FR, de-DE, ja-JP, pt-BR, zh-Hans as follow-ups.

~600 LOC of string extraction across ~39 source files. Mechanical but tedious; no behavior change.

#### Tier 8 — Release engineering

- `PrivacyInfo.xcprivacy` manifest enumerating Photos / Camera / Microphone / File-system access; required-reason API declarations.
- `fastlane init` + `fastlane match` (for signing) + `fastlane gym` (build) + `fastlane pilot` (TestFlight upload).
- CI workflow (`.github/workflows/release.yml`) tied to `release/*` branches.
- Crash analytics: Sentry SDK (lighter than Firebase Crashlytics; no GCP dependency). Captures crashes + breadcrumbs; opt-out toggle in `SettingsView`.

~200 LOC of config + manifest. New CI dependencies.

#### Tier 9 — Release prep + tag v0.6.0

CHANGELOG / README / ROADMAP / DESIGN updates; develop → main; tag v0.6.0; GH release; reset develop.

### Compatibility

- **Floor bumps:** kadr ≥ 0.11.0; kadr-ui ≥ 0.10.1.
- **Schema:** v4 documents written by v0.6+; v1 / v2 / v3 still load (additive migration).
- **`Localizable.strings`:** en-US bundle; no behavior change for en-US users.
- **Privacy manifest:** required for App Store submission post-2024; ships now so v0.7+ doesn't have to scramble.

### Open questions

- **Sentry vs. Crashlytics vs. neither.** Sentry is simpler to drop in and doesn't bind to Firebase / GCP; Crashlytics is free + Apple-friendly but pulls in the Firebase SDK. RFC defaults to Sentry. If the user prefers Crashlytics, swap.
- **Multi-device sync architecture today vs. defer.** RFC defers — overridable `ProjectLibrary` directory is the only hook; no real CloudKit / iCloud Documents work. Multi-device is a v0.7+ decision.
- **iOS 17 floor move now or in v0.8.** v0.6 stays on iOS 16+. Moving to iOS 17 unlocks `@Observable` + `accessibilityLiveRegion` on toasts; the cost is dropping the small iOS 16 install base. Decide at v0.8.

## v0.7 — Editor UX catch-up

**Status:** RFC. No code yet.

### Motivation

v0.1 → v0.6 stabilized the editor's foundation: persistence, undo/redo, accessibility, robustness, release engineering. What's still missing is the *creator surface* — the obvious moves a returning CapCut / TikTok / Reels user expects to find on day one:

- They can't see the shape of a music track. Audio rows render as flat color bars, so trimming "the chorus to the drop" means scrubbing the preview by ear.
- They can't pick a transition. The data model supports `.fade` / `.dissolve` since v0.1, but nothing in the toolbar inserts one.
- Their text overlays can't take a stroke, a shadow, or an animated entrance. `TitleSequence` and `TextOverlayData` only expose color + alignment + weight.
- They can't isolate a green-screen subject. `Filter.chromaKey` ships in kadr v0.9+ but isn't surfaced in `FiltersSheet`.
- The project list is a wall of names. No frame thumbnail.

v0.7 closes that surface gap. Each tier is a CapCut-baseline feature with a kadr-ui or kadr surface dependency where one is needed; we follow the v0.3 / v0.6 pattern of opening upstream patches mid-cycle when the editor design forces it.

### Pairs with — upstream patches

- **kadr-ui v0.10.2** *(Tier 1 prerequisite — surface design first, ship before reels-studio Tier 1 lands)* — audio trim handles on `TimelineView` audio rows. Two new callbacks: `onAudioTrim(_ event: AudioTrimEvent)` and `onAudioScrubStart(_ event: AudioScrubEvent)`. The waveform peak rendering already exists; this exposes the gesture surface.
- **kadr v0.12** *(Tier 3 prerequisite)* — `TextStyle` gains `stroke: TextStroke?`, `shadow: TextShadow?` fields plus the engine compositor pipeline for both. `TextStroke` carries `width: Double` + `color: PlatformColor`; `TextShadow` carries `offset: CGSize` + `blur: Double` + `color: PlatformColor`. Additive; v0.11 docs continue rendering with both nil.

Tier 4 (chroma key) and Tier 5 (thumbnails) need no upstream changes — kadr already exposes the underlying APIs.

### Scope lock — v0.7

In scope:
- **Audio waveform trim handles** on every `ProjectAudioTrack` row. Drag handles bind to new `ProjectStore.applyMusicTrim(_:)` / `applySFXTrim(_:)` mutations. Scrubbing the audio row updates `currentTime` so the user can hear the trim point.
- **Transitions picker sheet.** Grid of transition kinds (Fade, Dissolve — same set the data model supports today). Duration slider 0.1s–2.0s. Inserted between two selected adjacent clips via a new "+ between" affordance in the timeline gap. Mutation: `insertTransition(afterClipID:kind:duration:)`.
- **Text effects inspector.** `OverlayInspectorArea`'s text-overlay subview gains stroke + shadow rows. Stroke: width 0–10 + color. Shadow: offset (slider per axis) + blur + color. Bindings route through new `setTextStroke(_:)` / `setTextShadow(_:)` mutations on `ProjectStore`.
- **Chroma key UI.** `FiltersSheet`'s + menu gains a "Chroma Key" entry. On tap, pushes a dedicated `ChromaKeySheet` with a color preview tile, a `ColorPicker`, and a threshold slider. Mutation: `addChromaKey(id:color:threshold:)` wraps the existing `addFilter` path with the `Filter.chromaKey` case.
- **Project thumbnails.** `ProjectRow` gains an 80×80 thumbnail rendered from frame 0 of the first `VideoClip` / `ImageClip` in the project. Cached under `App Support/ReelsStudio/Thumbnails/<projectID>.jpg`, invalidated when `modifiedAt` advances. Empty projects render a gradient placeholder.

Out of scope:
- **More transition kinds.** Today's model exposes `.fade` and `.dissolve` only — adding `.slide` / `.zoom` / `.wipe` is a kadr v0.12+ surface bump we'd rather not bundle into v0.7's UX cycle.
- **Animated text entrances.** Stroke + shadow are static. "Bounce in" / "type-on" animations are a v0.8 AI-adjacent feature that pairs with auto-captions.
- **Audio waveform *generation* during import.** kadr-ui already computes peaks at render time; we don't pre-bake.
- **iOS 17 floor.** Still on iOS 16 — `@Observable` migration waits for v0.8.

### Tier breakdown

#### Tier 1 — Audio waveform trim handles

**Upstream:** kadr-ui v0.10.2 (must merge first). Adds `AudioTrimEvent` Sendable struct + `onAudioTrim(_:)` modifier on `TimelineView`. Mirrors the existing `onTrackTrim` pattern.

**Downstream:**
- `ProjectStore.applyMusicTrim(_:)` — applies leading/trailing trim to `audioTracks[index].startTimeSeconds` + `.explicitDurationSeconds`. Undoable, named "Trim Music".
- `ProjectStore.applySFXTrim(_:)` — same for SFX rows.
- `TimelineArea` wires `onAudioTrim` to the right mutation based on the lane kind.

~120 LOC + ~10 tests (mutation correctness, undo round-trip, edge cases for trims past clip length).

#### Tier 2 — Transitions picker UI

**No upstream changes** — `TransitionData` ships in schema v1+.

- New `TransitionsSheet` view: `LazyVGrid` of transition tiles (icon + label), `Slider` for duration.
- `EditorToolbar` clip-action row gains a "Transition" button when a clip has a successor. Tapping pushes `TransitionsSheet` for that gap.
- `ProjectStore.insertTransition(afterClipID:kind:duration:)` — inserts `ProjectClip.transition(TransitionData)` between the named clip and its successor in `project.clips`. Replaces an existing transition at the same gap (not duplicates). Undoable, named "Add Transition" / "Change Transition".

~180 LOC + ~12 tests (gap detection, replace-not-duplicate, undo, removing the trailing clip removes the transition too).

#### Tier 3 — Text effects inspector

**Upstream:** kadr v0.12 (must merge first). Adds `TextStyle.stroke: TextStroke?` + `TextStyle.shadow: TextShadow?` and the engine compositor wiring for both. Schema needs no bump on the reels-studio side because `TextOverlayData` doesn't currently mirror `TextStyle` fully — we add `strokeWidth: Double?`, `strokeColorHex: String?`, `shadowOffsetX: Double?`, `shadowOffsetY: Double?`, `shadowBlur: Double?`, `shadowColorHex: String?` as additive fields on `TextOverlayData` (schema v4 → v5 minor bump).

**Downstream:**
- `OverlayInspectorArea` text section gains a "Stroke" disclosure group (width slider, color picker) and a "Shadow" disclosure group (X/Y offset sliders, blur slider, color picker).
- `ProjectStore.setTextStroke(layerID:_:)` + `setTextShadow(layerID:_:)` mutations. Both undoable.
- Persistence bridge updated.
- Schema v5 round-trip tests + v4-decodes-without-fields test.

~260 LOC + ~16 tests.

#### Tier 4 — Chroma key UI

**No upstream changes** — `Filter.chromaKey(ChromaKey)` exists since kadr v0.9.

- `FiltersSheet`'s "+" menu gains a "Chroma Key" entry as the twelfth filter kind. Tapping opens a dedicated `ChromaKeySheet` (separate from the scalar-filter row UI because it needs a color picker + a "Pick from preview" affordance that the existing slider row can't host).
- `ChromaKeySheet`: color preview tile + `ColorPicker` + threshold slider (0.0–1.0).
- `ProjectStore.addChromaKey(clipID:r:g:b:threshold:)` — builds a `Filter.chromaKey(ChromaKey(color: PlatformColor, threshold:))` and routes through the existing `addFilter` path.
- "Pick from preview" gesture is filed as a follow-up — needs `VideoPreview` to expose tap → color sampling.

~150 LOC + ~10 tests.

#### Tier 5 — Project thumbnails

- `ProjectThumbnailRenderer` — `@MainActor` actor-equivalent that, given a `ProjectDocument`, renders frame 0 of the first non-transition clip to a JPEG at 80×80 (2× retina = 160×160 stored). Saves under `App Support/ReelsStudio/Thumbnails/<projectID>.jpg`. Returns a `UIImage` on success, nil on failure.
- `ProjectRow` adds an 80×80 thumbnail tile to the leading edge. Loads from cache on appear; renders + caches on cache miss via a `Task { ... }`. Empty projects render a `LinearGradient` placeholder keyed off `projectID.hashValue` so each empty project looks visually distinct.
- Cache invalidation: keyed by `<projectID>-<modifiedAt-unix>.jpg` so a save bumps the filename and old thumbnails are GC'd lazily on next load.
- Optional: a "regenerate thumbnails" action in Settings for debugging.

~220 LOC + ~12 tests (render correctness, cache hit/miss, empty-project placeholder, invalidation on modifiedAt change).

#### Tier 6 — Release prep + tag v0.7.0

CHANGELOG, README, ROADMAP, develop → main, tag v0.7.0, GitHub release, back-merge.

### Risks

- **Tier 1 timing** — kadr-ui v0.10.2 must land cleanly before downstream Tier 1 can start. Track via the upstream RFC.
- **Tier 3 timing** — kadr v0.12 stroke/shadow surface is the deepest upstream dependency. Slipping it slides the whole reels-studio cycle.
- **Tier 5 perf** — rendering a thumbnail for every project on first launch could spike CPU. Mitigation: render lazily on `.onAppear` of each `ProjectRow`, not eagerly at launch. Confirm with Instruments before merge.

## Modernist design-system migration

**Status:** ✓ Implemented (Tiers 1–5 + fixes landed on feature/modernist-design-system)

### Motivation

v0.7.1 completed the kadr-ecosystem iOS 17 migration, but the app's visual layer remained on a hardcoded baseline of values without a published design system. The Modernist system — a Swiss-precision grid with mono color + one red accent, built on Archivo (variable font, 400/600/800) — brings the editor's look and feel into a production-grade state and codifies the token layer as reusable Swift types for downstream apps.

### Scope lock — Modernist migration

In scope — visual design only; zero feature changes, zero state mutations:
- **Token layer** (`ReelTheme.swift` + `ReelStyles.swift`) — two palettes (print + studio ground), accent ramp, spacing / type / rule constants, environment-keyed appearance modifiers.
- **Call-site migration** — every hardcoded color / radius / material / font across ~25 view files moves onto the token layer; screens restructured to match the approved design.
- **Archivo font** — bundled as static instances (400 / 600 / 800 weight) generated from Google Fonts variable, OFL.txt shipped, LICENSE attribution added.
- **Constrained accent picker** — `setAccentColor(_:)` mutation unchanged; UI narrowed from free `ColorPicker` to `ReelSegmentedControl` over the three accent ramp steps + System option.

Out of scope (carried forward from v0.7+ or deferred):
- Dynamic Type audit (v1.0 prep).
- Transport band (play/skip/loop/fullscreen), real eyedropper tool, editor rename affordance — all dropped by ruling per the handoff.
- Snapshot test re-recording (none existed; skipped by standing ruling).

### Five binding decisions (verbatim from handoff)

1. **Two grounds, one system.** Modernist is a light print system; a video editor cannot grade footage against a light field. The theme ships two palettes of the same token system:
   - `ReelPalette.print` — all app chrome (library, sheets, settings, export).
   - `ReelPalette.studio` — dark grading surround (#0C0C0E / #151517 / #1D1D20) for the editor only (nav, stage, transport, timeline, inspector, toolbar).
   Both use the same accent, same ramps, zero radius, 2px rules, flush-left labels and Archivo.

2. **The accent is red, not blue.** Modernist is a mono scheme with one accent. Every blue in the previous design becomes `#EC3013` on print, `#FF563C` (Accent.a500) on studio, per the system's rule about using a lighter ramp step on dark grounds.

3. **`Project.accentColor`'s free `ColorPicker` is constrained.** v0.5 shipped a per-project accent with an unconstrained picker, which breaks a mono scheme immediately. Replaced with a `ReelSegmentedControl` over the three accent ramp steps (`a500` / `a600` / `a700`) plus a System option that clears to `nil`. Persisted field, hex round-trip, and `ProjectDocument` schema v5 unchanged.

4. **Semantic colors collapse into the mono scheme.** No success / warning / destructive roles. Delete uses `ReelSecondaryButtonStyle` (accent outline, not red fill — red is already the accent). Auto-save status uses neutral `n400`. Playhead is `text` white (2pt) — it sits over accent-tinted footage; white reads on any frame and stops competing with the accent. This is the one place the design deviates from "red = accent."

5. **Footage is grayscale — except on the stage.** Apply `.reelGrayscale()` to project thumbnails, timeline filmstrips and layer thumbnails. **Do not** apply it to the preview stage — the user is grading color there.

### Archivo provenance

- **Source.** Google Fonts ships Archivo as a variable font only (wght 100–900).
- **Static instances.** Generated at 400 / 600 / 800 weight using fontTools, with name tables rebuilt (ID 16 family grouping for SwiftUI weight resolution).
- **Licensing.** OFL 1.1. The `OFL.txt` file ships in `Resources/Fonts/` alongside the `.ttf` instances; attribution recorded in the root `LICENSE` file.
- **Proven.** SwiftUI weight resolution tested on-simulator — `family+trait` path resolves ExtraBold (800) and SemiBold (600) correctly; guarded by `ReelTypographyTests`.

### ReelStyles.swift amendment

One production fix applied during Tier 2: the nested view `Body` renamed to `StyleBody` to avoid a `ButtonStyle` associated-type witness collision in several contexts (compile blocker, zero visual change). The change is internal to `ReelStyles.swift` and surfaces nowhere in call sites.

### kadr-ui 0.12.0 as upstream RFC — closed in 0.13.0

The Modernist design exposed hard limits in kadr-ui's customization surface. kadr-ui ships with a zero-theming API by documented policy — the library is the reference implementation, not a theming substrate. Downstream apps are named the v1.0 reference consumer (this app).

> **Resolved.** kadr-ui 0.13.0 shipped `KadrAppearance` (issue #101, PR #103), and `EditorView.studioAppearance(accent:)` now maps `ReelPalette.studio` onto it. The list below is kept as the record of what the ceiling was, not as an open gap. What remains upstream is the eyedropper's tap-to-sample (#102).

**Was unreachable with kadr-ui 0.12.0:**
- Red playhead (currently system accent, but playhead should be white per decision 4).
- Clip-cell background colours, hues, and radius-4 corners.
- Waveform colour on audio rows.
- Keyframe diamond colour (accent-filled today).
- Lane background colours and selection ring colour (white today).
- Per-lane heights (single `laneHeight` — and it is ignored on the common single-non-audio-lane path).
- Unhiddable 14pt scrub strip.
- AVKit transport chrome on VideoPreview.
- Time ruler (the app draws its own as a t=0 legend pending a scroll-offset API).
- Filmstrips in clip cells.

**One accidental match:** single-select ring is already white 2pt, aligning with Modernist by chance.

**Proposed upstream shape:** An `EnvironmentValues`-based appearance modifier layered through the existing private helpers, allowing downstream consumers to set colour / radius / typography / layer height at the cost of a new protocol adoption. Carve out as a separate RFC if community demand surfaces.

**Where dependency versions live.** `ReelsStudio.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`. This is an Xcode-project app with no `Package.swift`, so a root `Package.resolved` is never authoritative here — if one appears it is local residue from someone running `swift build` in the directory, it is gitignored, and it will drift (a stale one pinned kadr-ui 0.6.0 while the build used 0.13.0). Read the `.xcodeproj` one.

### Dropped by ruling

Three features that initially appeared in design drafts but were cut:
- **Transport band** — play/skip/loop/fullscreen controls. Status: reopened and scoped for v0.9.0 (see § v0.9.0 — Transport band). A feature request deferred during the Modernist migration, now implemented.
- **Real eyedropper tool** — "Pick from preview" for chroma key + colour overlays. Pre-existing `ColorPicker` stands in; a real eyedropper needs `VideoPreview` tap-coordinate exposure.
- **Editor rename** — the navigation pencil glyph. Was decorative; a11y-hidden per v0.5; dropped as unnecessary affordance.

### Known gaps closed by ruling

- **Sheet backdrop.** Spec calls for an exact 55% black scrim. Implemented using system dimming (no custom presentation machinery). Perceptually equivalent, achieves the goal, avoids modal-presentation surgery.
- **Tick row.** Designed as a zoom legend (showing "48 px/s" readout), not scroll-tracking. Implemented as specified.

### The swipe-back regression — and the lesson

Hiding the system navigation bar during the design migration killed the interactive pop gesture (swipe from left edge to go back). Restored via a `UIGestureRecognizerDelegate` shim in the nav stack.

**The lesson:** When a test is retargeted because the chrome it targets moved, ask what the old target was *also proving*. An edge-swipe UI test now stands witness to the interactive-pop affordance.

### Dynamic Type and snapshot baselines

- **Dynamic Type.** Fixed Modernist scale makes a Dynamic Type audit *more* necessary, not less, for v1.0 prep. Deferred.
- **Snapshot tests.** Re-recording was deferred by standing ruling until a pinned-Xcode re-record job landed — the job is now live. v0.10 lands the harness end-to-end: the determinism seam, seven snapshot test cases, the pinned `snapshot:` CI job, and the recording workflow (`.github/workflows/snapshot-record.yml`). **No baseline images are committed** — a fresh checkout has zero, and that is the intended state. Baselines are produced by dispatching that workflow after this lands, and arrive through a PR where a human reviews each PNG by eye. See v0.10 section below for the full determinism seam, why baselines are not committed, and why tests self-skip locally.

### Compatibility

- **No schema changes.** `ProjectDocument` v4 and `AppSettings` structures unchanged; `Project.accentColor` hex round-trip works identically.
- **No `@Observable` or iOS 17 requirement bump.** Design layer works on iOS 16 runtime (v0.7.1 raised the floor; this migration is orthogonal).
- **Archivo assets required.** Static font instances must be declared under `UIAppFonts` in `project.yml` (`Info.plist` is generated by XcodeGen) for the design to render correctly. Fallback to system face at the same size / weight ensures nothing breaks, but the intended look requires the font.

---

## v0.9.0 — Transport band

**Status:** ✓ Implemented

The editor shipped with a stage and timeline but no way to *run* a composition — the only playhead control was tapping the timeline. The transport band fills that gap: a horizontal strip below the stage with skip-back · play/pause · skip-forward buttons, a centered elapsed/total timecode readout, and loop / fullscreen toggles.

### Scope lock — v0.9.0

In scope:
- **Transport band UI** — strip between stage and timeline.
  - Leading group (3 cells): skip-back, play/pause (26pt glyph, accent fill), skip-forward.
  - Center: "0:01 / 0:06" timecode in `Typography.numeric` (elapsed at full text colour, total at textMuted).
  - Trailing group (2 cells): loop toggle, fullscreen button.
- **Skip behaviour** — fixed 1.0-second intervals, clamped to [zero, duration]. Each button disabled at its bound. Frame-step rejected: `VideoPreview` ignores seeks under 0.05s, one frame at 30fps is 0.033s, button would silently fail.
- **Loop implementation** — in the app, not `VideoPreview(loops:)`. kadr-ui captures that parameter at player construction and does not rebuild on `loops` change; the toggle would be inert. The app restarts playback when `isPlaying` falls and loop is on.
- **Loop persistence** — session state on `ProjectStore`, no disk persistence. No schema change; `ProjectDocument` remains schema v5. Loop state does not enter undo timeline.
- **Playhead flush gating** — scene-storage write does not fire on every playback tick (~10 times per second). Explicit flushes fire on playback stop and app background.
- **Fullscreen mode** — collapses editor chrome in place (no new route). Transport band stays visible for its exit affordance.
- **kadr-ui dependency** — requires 0.14.0 for `VideoPreview`'s `isPlaying` and `currentTime` two-way bindings. No upstream kadr changes needed.

Out of scope:
- **Frame-step controls** — rejected per the seek-floor reasoning above.
- **Variable skip intervals** — always 1.0 second.
- **Playback speed controls** — speed editing is v0.7's `SpeedCurveEditor`, separate from playback rate UI.
- **Scrubbing on the transport band** — scrub affordance lives on the timeline.
- **Playback loop on `VideoPreview`** — architectural decision tied to kadr-ui's construction-time parameter capture.

### Compatibility

- **kadr-ui ≥ 0.14.0** (no floor change; already required by chroma-key work). Requires `VideoPreview(isPlaying:currentTime:)` two-way bindings.
- **No schema changes.** `ProjectDocument` v5 persists identically.
- **No undo impact.** Loop and play state are transient; session-level state does not enter undo timeline.

---

## v0.10.0 — Snapshot testing harness

**Status:** ✓ Implemented

A thin slice of pixel-snapshot coverage over the editor view group (`EditorView`, `PreviewArea`, `TransportBand`, `EditorToolbar`). Proves layout, colour, and spacing invariants the unit/UI suite cannot reach — every other test is behavior (a binding wired, a computed string, a selection slot). First harness ship over one screen group; foundation for v1.0's pixel-perfect audit.

### The determinism seam

The live stage is an AVKit player built asynchronously inside `.task` on `VideoPreview` appear, racing a loading spinner against a failure glyph. A baseline captured during that race is unrepeatable. `StageRendering` is an `EnvironmentKey` with two cases: `.live` (default, never written in production) and `.placeholder` (test-only). Snapshot tests set it to `.placeholder`, swapping the player for the stage's own letterbox ground — no `AVPlayer`, no async load, no spinner-versus-glyph race. Every store is built from a fixed fixture (one `/dev/null` clip trimmed to 6 seconds) with `currentTime` and `isPlaying` pinned, so nothing in the tree is mid-animation or mid-load when the frame is captured. See `Sources/ReelsStudio/Editor/StageRendering.swift` for the seam; production is unaffected by its existence — the app never writes the key, and `Tests/ReelsStudioTests/StageRenderingTests.swift` asserts the default is `.live`, so a silent flip would fail a test.

### Why baselines are not in the repo

A fresh checkout has ZERO baseline images. That is the intended state, not a bug. Baselines live only in CI's pinned-runtime job and land via a PR where a human reviews each PNG as an image before merge. The `snapshot:` job is knowingly RED until that first record PR merges — a missing baseline is a failure, not a pass. This is honest: snapshot tests that never ran are not a feature; snapshot tests that always pass without anyone reviewing them are dangerous.

### Two runtimes, on purpose

The main `test:` job (ci.yml) keeps its documented highest-available-runtime float — unit assertions do not care which iOS point release renders them. The `snapshot:` job pins Xcode 26.3 + iOS 26.2 + iPhone 17 Pro and refuses to fall back. Pixel baselines drift across iOS point releases and device screen geometry. A fallback to a different runtime or device would be drift wearing green, silently unreviewed.

### A documented trap

`PreviewArea` and `EditorToolbar` declare `@Environment(ToastCenter.self)`. SwiftUI's Observation lookup TRAPS AT HOST TIME even when the value is never read — including in the `.placeholder` branch that never touches `toasts`. Standing up any SwiftUI host or snapshot test against these views crashes with "No Observable object of type ToastCenter found" unless the test injects `.environment(ToastCenter())`. **RULED: production will NOT be changed to tolerate its absence** — trapping is correct fail-fast, and making it optional would silently swallow the auto-save and preview-load error toasts users depend on. Tests inject a real `ToastCenter`. This is not a bug in the seam; it is intentional harness surface.

### The harness's first catch

The snapshot harness caught a real, user-visible defect in already-merged code on its first recording run (issue #75): `TransportBand` used SF Symbol names `gobackward.1` and `goforward.1`, which have never existed. The numbered "go" family runs `.5 / .10 / .15 / .30 / .45 / .60 / .75 / .90` — there is no `.1` member. Both skip buttons rendered a missing-symbol placeholder on device. It shipped in PR #84 and passed every existing gate: a11y tests assert spoken labels, ViewInspector asserts structure, the compiler only ever sees a `String`. Nothing looked at pixels. Fixed to `gobackward` / `goforward` with a regression test asserting `UIImage(systemName:)` resolves for both. The skip interval (1.0 second) did not change — it rested on kadr-ui's 0.05s seek floor, never on a glyph.

### Scope lock — v0.10.0

In scope:
- **Snapshot test harness** — seven test cases (`SnapshotTests.swift`) covering the editor view group on CI's pinned runtime (Xcode 26.3 + iOS 26.2 + iPhone 17 Pro).
  - `EditorView` in default session state.
  - `PreviewArea` alone, placeholder-rendered, with and without overlay.
  - `TransportBand` at composition start and mid-composition (both skip states).
  - `EditorToolbar` in root mode and clip-selected mode.
- **Determinism via `StageRendering` seam** — environment key with `.live` (default) and `.placeholder` (test-only) cases.
- **Baseline recording** — manual workflow (`.github/workflows/snapshot-record.yml`) for human-reviewed baseline PRs. Pinned Xcode 26.3 / iOS 26.2 / iPhone 17 Pro, no auto-heal, no fallback.
- **CI execution** — `snapshot:` job in ci.yml; knowingly red until first baselines land, then green on pixel match.
- **Local skip guard** — every snapshot test calls `requireCIPinnedRuntime()` and self-skips unless `SNAPSHOT_RUNTIME_PINNED=1` is set in the booted simulator's launchd.

Out of scope:
- **Baselines on disk** — deferred to recorded PR; fresh checkout has none.
- **Snapshot coverage outside editor group** — sliced to the one screen group the approved design cares about pixel-for-pixel. Other screens' behavior is proven by unit/UI.
- **Portrait + landscape variants** — v0.10 captures one size (390×844 for full editor, 270×480 for preview). Additional device / orientation coverage deferred.

### Compatibility

- **No schema changes.** `ProjectDocument` v5 persists identically.
- **No app changes outside tests.** `StageRendering` key added; production always uses `.live`, never written by app code.
- **swift-snapshot-testing ≥ 1.19.4** — added to test target dependencies.

---

## v0.8 — On-device AI *(planned, sketch)*

Apple-platform-commodity AI features:

1. ~~**iOS 17 floor bump** + `@Observable` migration~~ **Shipped in v0.7.1.** Remaining work:
2. **Auto-captions** via kadr-captions v0.7's `AutoCaptionGenerator` (SpeechAnalyzer-backed). "Generate from audio" button in `AddCaptionsSheet`.
3. **Person cutout** via Vision framework `PersonSegmentation`. New `Filter.mask(.person)` case (requires kadr engine update — track as kadr v0.13.x).
4. Release prep + tag v0.8.0.

## v1.0 — App Store *(planned)*

Sketch:
- Final name lock (revisit "Reels Studio" before submission).
- Real designed app icon family (replaces SF Symbol placeholder).
- App Store metadata — screenshots, description, age rating, privacy manifest.
- Submission alongside kadr v1.0.

---

## v0.3 — Wire-up cycle

**Status:** RFC. No code yet.

### Motivation

v0.2 shipped the production foundation (persistence, error infra, undo/redo, project list). v0.7 + v0.8 of kadr-ui shipped four major editor surfaces (`SpeedCurveEditor`, `CaptionEditor`, `OverlayInspectorPanel`, `OverlayKeyframeEditor`) plus `TimelineZoom` + Track-internal editing. **None of those surfaces are wired up in reels-studio yet.** The v0.2 audit confirmed: `KeyframeArea` is read-only (callbacks dropped to nil); `AddCaptionsSheet` is ingest-only (no edit path); overlays have no inspector at all; the timeline doesn't support multi-track or zoom; sticker overlays are deferred.

This cycle integrates everything that's already shipping in the kadr ecosystem — no new kadr / kadr-ui surface required, just wiring against ≥ kadr-ui 0.8.0.

### Dependency floors

- **kadr-ui ≥ 0.8.0** (up from 0.6.0). Brings `SpeedCurveEditor` / `CaptionEditor` / `OverlayInspectorPanel` / `OverlayKeyframeEditor` / `TimelineZoom` / `onTrackReorder` / `onTrackTrim` / sticker overlay support.
- kadr / kadr-captions / kadr-photos floors unchanged from v0.2 (≥ 0.9.2 / ≥ 0.4.0 / ≥ 0.4.0).

### Persistence extensions (lives in Tier 1 alongside the keyframe path)

The v0.2 `ProjectDocument` doesn't carry per-property animations or speed curves. Tier 1 extends the schema:

```swift
struct VideoClipData {
    // ...existing fields
    var transformAnimation: ProjectAnimation<ProjectTransform>?    // new
    var opacityAnimation: ProjectAnimation<Double>?                // new
    var filterAnimations: [ProjectAnimation<Double>?]              // parallel to filters
    var speedCurve: ProjectAnimation<Double>?                      // new
}

struct ImageClipData {
    var transformAnimation: ProjectAnimation<ProjectTransform>?    // new
    var opacityAnimation: ProjectAnimation<Double>?                // new
}

struct ProjectAnimation<Value: Codable & Sendable & Equatable>: Codable, Sendable, Equatable {
    var keyframes: [ProjectKeyframe<Value>]
    var timing: ProjectTimingFunction
}
struct ProjectKeyframe<Value: Codable & Sendable & Equatable>: Codable, Sendable, Equatable {
    var timeSeconds: Double
    var value: Value
}
enum ProjectTimingFunction: Codable, Sendable, Equatable {
    case linear, easeIn, easeOut, easeInOut
    case cubicBezier(p1x: Double, p1y: Double, p2x: Double, p2y: Double)
}
```

Schema bump to **`schemaVersion: 2`**. Loaders for v1 documents continue working — the new fields default to `nil` (additive migration; no data loss).

Track support also lands in Tier 1 (or earlier — see Tier breakdown):

```swift
enum ProjectClip {
    // ...existing cases
    case track(TrackData)
}
struct TrackData: Codable, Sendable, Equatable {
    var startTimeSeconds: Double
    var name: String?
    var opacityFactor: Double
    var clips: [ProjectClip]   // recursive — Track inside Track is theoretically allowed but rejected by kadr's runtime
}
```

### Tier breakdown

- **Tier 0** *(this PR)* — RFC only. No code.

- **Tier 1 — Persistence schema v2 + keyframe authoring** *(largest)*
  - Bump `schemaVersion` to 2; add the animation / track / speed-curve fields above.
  - Add `Animation<T>` ↔ `ProjectAnimation<T>` bridge (kadr's generic `Animation<Value: Animatable>` can't directly conform Codable; bridge per concrete value type — `Transform`, `Double`, `Position`, `Size`).
  - Replace v0.2's read-only `KeyframeArea` with real authoring: wire `KeyframeEditor.onAdd` / `.onRemove` / `.onRetime` to new `ProjectStore.addKeyframe(...)` / `removeKeyframe(...)` / `retimeKeyframe(...)` mutations.
  - Mutations use the existing `applyMutation(actionName:)` so undo/redo Just Works.
  - **~500 LOC + ~30 tests.**

- **Tier 2 — SpeedCurveEditor wiring**
  - Add a "Speed curve…" row to `InspectorPanel` (or push a sheet) when a `VideoClip` is selected.
  - `SpeedCurveEditor(clip:onUpdate:)` callback routes through `ProjectStore.applySpeedCurve(id:_:)` — built on top of Tier 1's mutation infrastructure.
  - **~200 LOC + ~10 tests.**

- **Tier 3 — Caption editor (replaces AddCaptionsSheet)**
  - Refactor `AddCaptionsSheet` to a two-tab sheet: "Import from file" (existing) and "Edit cues" (new — wraps `CaptionEditor`).
  - Caption mutations route through `ProjectStore.setCaptions(_:)` (already exists) → undo-tracked.
  - **~250 LOC + ~10 tests.**

- **Tier 4 — Overlay inspector + overlay keyframe editor**
  - Add a `selectedOverlayID: Binding<LayerID?>` to `ProjectStore`. `OverlayHost` selection routes here when v0.4+ adds tap-to-select on overlays; for v0.3 selection comes from a thumbnail strip in the editor body or a "Edit overlay" button on a list.
  - When `selectedOverlayID != nil`, swap `InspectorArea`'s body to `OverlayInspectorPanel`, and `KeyframeArea`'s body to `OverlayKeyframeEditor`.
  - Mutations: `ProjectStore.applyOverlay(id:transform:)` / `applyOverlayOpacity(...)` / etc.
  - **~400 LOC + ~20 tests.**

- **Tier 5 — Timeline zoom + multi-track UI**
  - Add `zoom: TimelineZoom` to `ProjectStore` (persisted in `ProjectDocument` as `zoomPixelsPerSecond: Double?` — defaults to fit-to-width on load).
  - Pass `zoom: $store.zoom` to `TimelineView`.
  - Multi-track: `Track {}` blocks already render via kadr-ui's stacked-lane mode; wire `onTrackReorder` / `onTrackTrim` callbacks through `ProjectStore.applyTrackReorder(trackIndex:newClips:)` / `applyTrackTrim(trackIndex:clipIndex:leadingTrim:trailingTrim:)`. Persist Track via `ProjectClip.track` (added in Tier 1).
  - **~350 LOC + ~15 tests.**

- **Tier 6 — Sticker / image overlay support**
  - Closes the `AddOverlaySheet` v0.1.x deferral — extend the sheet from text-only to a tabbed Text / Image / Sticker picker.
  - Image / sticker source: photo picker (`PhotoPicker` from kadr-photos) → resolve to `PlatformImage` → embed via `ProjectOverlay.image` / `.sticker`.
  - **~250 LOC + ~12 tests.**

- **Tier 7 — Release prep + ship as v0.3.0.**

### UI / UX placement decisions

- **"Speed curve…" entry point**: as a row inside `InspectorPanel`'s VideoClip section. Tap → push a full-screen sheet with `SpeedCurveEditor`. Don't try to inline it (the editor needs vertical space for the log-scale multiplier axis).
- **Caption editor sheet**: matches the "Music" / "SFX" sheet pattern. Tabbed — Import / Edit. Default to Edit when there are existing cues; Import when empty.
- **Overlay selection**: v0.3 uses a "Layers" button in the toolbar that pushes a sheet listing every overlay; tap a row → close sheet, set `selectedOverlayID`. Future tier (v0.4 UX) adds tap-to-select directly on `OverlayHost`.
- **TimelineZoom UI**: pinch on the timeline (kadr-ui v0.7's gesture). No explicit zoom slider — the gesture is the affordance.
- **Multi-track UI**: timeline stacks horizontally as today; Track {} blocks render as additional lanes per kadr-ui's existing layout. The user creates a Track via "+ Track" toolbar button (new — appears alongside `+ Clip`).

### Test strategy

- **Animation mutations**: round-trip every `addKeyframe` / `removeKeyframe` / `retimeKeyframe` per property kind through undo / redo + persistence.
- **Schema migration**: v1 documents on disk continue loading after the v2 schema lands.
- **Bridges**: `Animation<T>` ↔ `ProjectAnimation<T>` per `Value` type (`Transform` / `Double` / `Position` / `Size`).
- **Body smoke**: every new screen / sheet constructs without crashing under the same patterns as v0.2's tests.

Target: **~100 new tests** across the cycle. Suite floor 65 → ~165.

### Open questions (track in PRs, not blocking RFC merge)

- **`Track` round-trip and the recursive sumtype**: `ProjectClip.track(TrackData)` where `TrackData.clips: [ProjectClip]`. Swift handles indirect enum cases natively; `[ProjectClip]` inside `TrackData` works since enum recursion through arrays doesn't need `indirect`. Verify in Tier 1.
- **Animation timing function on import**: kadr's `TimingFunction.cubicBezier` carries `CGPoint`s; the persisted form uses `Double` x/y per point. Round-trip exact.
- **Speed-curve UI entry point persistence**: should the sheet's open state itself persist? No — UX state, not document state. Same rule as `selectedClipID`.
- **Multi-select on overlays**: deferred to v0.4 (matches kadr-ui v0.8's same scope decision).
- **Track-lane trim handles** are kadr-ui v0.7.1; included transparently when we wire `onTrackTrim`.

### Compatibility

- **Schema bump** v1 → v2. Forward migration is automatic — v1 fields read; v2-only fields default to `nil` / `[]`. Backward migration *not* supported (a v2 document opened by an old build rejects with `unsupportedSchema`).
- Every v0.2 user flow continues working unchanged.

---

## Two-theme chrome (v0.16)

**Status:** ✓ Implemented

App chrome — library, sheets, settings, export — follows the system appearance.
The editor does not: it is dark in both, because footage cannot be colour-judged
against a light field. The step from a light library into a dark editor is
intentional and marks the change of mode.

### The decision that had to be made first

The approved v0.7 design and the Modernist migration recorded above are two
different languages, and they collide on three tokens: **radius** (8–16 vs 0),
**separators** (0.5px hairline vs 2px rule) and **accent** (system blue vs red).

**Resolution: the handoff governs chrome, Modernist governs the editor.** Chrome
gets its own geometry under `Reel.Chrome` — `Radius.sm/md/lg/sheet` and
`ruleWidth = 0.5` — leaving `Reel.Radius` at 0 and `Reel.ruleWidth` at 2 for the
editor, untouched. Two languages in one app, on purpose, divided along the line
where the app changes mode.

This is a deliberate narrowing of the Modernist migration's scope, not a
reversal of it. The section above still describes the editor exactly.

### The accent picker

`Project.accentColor` stays. The icon quotes system blue and does not track it —
an app icon is branding, not a live reflection of user state, the same way
Photos and Notes do not follow their in-app accents.

### Palettes

| Palette | Ground | Accent | Where |
|---|---|---|---|
| `chromeLight` | `#F2F2F7` | `#007AFF` | chrome, light appearance |
| `chromeDark` | `#0C0C0E` | `#0A84FF` | chrome, dark appearance |
| `print` | `#F3F2F2` | `#EC3013` | Modernist print ground (unchanged) |
| `studio` | `#0C0C0E` | `#FF563C` | the editor (unchanged) |

Resolved by `ReelPalette.chrome(for:)`, which deliberately cannot return
`studio` — routing the editor through an appearance resolver would make its
darkness an accident waiting to be "fixed".

### Two things the audit changed

- **A new `warning` role.** On the Modernist grounds it *is* the accent, which
  keeps that system's mono-plus-one rule. On chrome it is `#FF9500`, because
  chrome's accent is system blue and a blue warning reads as information.
- **`accentText` is darker than `accent` on light chrome.** `#007AFF` on a white
  row is 4.02:1 — it clears AA for large text and fails for body. `#0062CC` is
  5.80:1. The dark ground needs no such step: `#0A84FF` on `#1D1D20` is 4.61:1.
  `ChromeThemeTests` asserts the ratios rather than the values.

### A bug this surfaced

The project duration chip filled with `palette.text` and labelled with
`palette.onAccent`. On `chromeDark` both are white, so the label vanished into
its own background. It is an *inverted* chip, not an accent one, so the label is
`palette.bg` — which is what `ToastView` had been doing correctly all along.
