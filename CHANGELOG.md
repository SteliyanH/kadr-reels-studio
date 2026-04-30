# Changelog

All notable changes to Reels Studio will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

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
