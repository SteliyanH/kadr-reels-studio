# Reels Studio Roadmap

## v0.1.0 — Editor walking skeleton *(planned)*

End-to-end editor with the kadr v0.9 + kadr-ui v0.6 + kadr-captions v0.4 + kadr-photos v0.4 surface. Loads sample clips, lets the user pick from Photos, drop overlays, attach music, edit on the timeline, and export.

Tiers:

1. **Editor walking skeleton** — `EditorView` wiring `VideoPreview` + `OverlayHost` + `TimelineView` against a `ProjectStore`. In-memory `[any Clip]` array; rebuild `Video` on each body. Sample clips bundled (system-symbol `ImageClip`s, mirroring kadr-ui's `SimpleViewer`).
2. **PhotosPicker integration** — `PhotoPicker` from kadr-photos in a sheet; tapping + adds resolved clips to the project.
3. **Add Overlay / Music / SFX sheets** — text / sticker / watermark, BGM with auto-ducking, time-pinned SFX with `.at(time:)`.
4. **Inspector + keyframe editor** — `InspectorPanel` + `KeyframeEditor` from kadr-ui v0.6. Tap a clip on the timeline → property panel; per-property keyframe tracks below.
5. **Caption ingest** — drop a `.srt` / `.vtt` / `.itt` / `.ass` / `.ssa` file → cues land as styled overlays via kadr-captions' styled-VTT bridge or as plain `Caption`s via `Video.captions(_:)`.
6. **Export flow** — preset selector (Reels / TikTok / Square / Cinema), progress UI via `Exporter.run()`, share sheet on completion.
7. **Release prep** — README screenshots, ROADMAP, CHANGELOG, develop → main, tag v0.1.0.

## v0.2.0 — Project save / load *(planned)*

Round-trip the editor state to disk so users keep work between sessions. Codable `Project` value type + JSON persistence.

## v1.0.0 — App Store *(planned)*

Polish, App Store listing copy + screenshots, App Store submission alongside kadr v1.0. Working title to be locked here ("Reels Studio" likely conflicts with Meta trademarks; rename before submission).

## Out of scope

- Cloud sync (kadr-pro feature).
- Templates (kadr-pro feature).
- Auto-captions / speech recognition (kadr-pro feature).
- AR effects (not on any kadr roadmap).

## Compatibility

| Reels Studio | kadr | kadr-ui | kadr-captions | kadr-photos |
|---|---|---|---|---|
| 0.1.0 *(planned)* | ≥ 0.9.2 | ≥ 0.6.0 | ≥ 0.4.0 | ≥ 0.4.0 |
