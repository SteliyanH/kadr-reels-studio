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
