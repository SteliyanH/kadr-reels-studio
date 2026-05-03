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

## v0.4 → v1.0 — Production polish (UX layer)

**Status:** Sketch.

- **Two-tier bottom toolbar** with selection-driven swap (root verbs ↔ clip-specific actions, animated crossfade).
- **Fixed-center playhead** during scrub — timeline scrolls under it.
- **Snap haptics** on pinch-zoom (frame / second / 5s / 30s) + drag-snap-to-adjacent-clip.
- **Single accent-color thread** linking selected clip → active inspector tab.
- **Empty / disabled states** — greyed not hidden; tap-and-hold tooltips.
- **Real designed app icon** family (replaces placeholder).
- **Accessibility wiring** — `.accessibilityLabel` / `.accessibilityHint` / `.accessibilityValue` on every interactive element.
- **Spring animation curves** on drawer detents; medium thud on delete; success haptic pattern on export.
- **Optimistic UI** on trim handles (already partially done by kadr-ui's `liveTrimMetrics`).

v1.0.0 = App Store submission. Final name decided here ("Reels Studio" likely conflicts with Meta — tentative; revisit before submission).
