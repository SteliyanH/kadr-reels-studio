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

## v0.5 — Accessibility + settings *(planned)*

Sketch:
- Full a11y wiring sweep — `.accessibilityLabel` / `.accessibilityHint` / `.accessibilityValue` on every interactive element. Driven by an audit pass (Xcode Accessibility Inspector + VoiceOver QA).
- Empty / disabled state polish — greyed not hidden; tap-and-hold tooltips.
- Settings screen — accent picker, fixed-center-playhead toggle, haptic-strength toggle.

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
