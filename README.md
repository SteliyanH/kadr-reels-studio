# Kadr Studio

[![CI](https://github.com/SteliyanH/kadr-reels-studio/actions/workflows/ci.yml/badge.svg)](https://github.com/SteliyanH/kadr-reels-studio/actions/workflows/ci.yml)
[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2017+-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](LICENSE)
[![Sponsor](https://img.shields.io/badge/Sponsor-Buy%20me%20a%20coffee-FFDD00?logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/steliyanh)

**A short-form vertical video editor, and the reference app for [kadr](https://github.com/SteliyanH/kadr).**

A real consumer codebase exercising all six kadr packages end to end. Import from Photos, arrange on a multi-lane timeline, layer overlays, filters and animated text, add music with auto-ducking or record a voiceover, bring in captions from a file, and export to a vertical, square or cinema preset — with projects that save and reopen exactly as you left them.

## Status

Actively developed. See [Releases](https://github.com/SteliyanH/kadr-reels-studio/releases)
for what shipped and [CHANGELOG.md](CHANGELOG.md) for the detail — linked rather
than summarised, because a README that restates its own latest version is wrong
within a week. This one claimed v0.11.0 for four releases.

Not yet on the App Store.

## Why this exists

1. **Integration test for the kadr ecosystem.** Feature gaps surface as missing UI in the app. If `InspectorPanel` can't bind to a property, that property's surface in kadr core is wrong.
2. **Marketing material.** Screenshots / GIFs into launch posts; App Store listing as a real free indie app.
3. **Reference implementation.** New contributors read the source instead of squinting at unit tests. Real consumer code beats unit tests for "how do I use this" questions.

## Why a short-form editor

- **It maps onto kadr's surface.** `Preset.reelsAndShorts` is top-billed, and
  multi-track composition, overlays, ducked background music and per-clip filters
  are exactly the primitives this kind of editor needs. Building it exercises the
  library where the library claims to be strong.
- **The scope is concrete.** Short-form editors have well-understood conventions,
  which means less product-design thrash than a "general video editor" and more
  time spent on whether the API underneath actually works.

> **On the name.** This was *Reels Studio* until v0.13.0. "Reels" is a Meta
> trademark for short-form video, and the app's positioning was precisely the
> association that made the name useful and made it a risk under App Store
> guideline 5.2.5. It is **Kadr Studio** now — named for the engine, which was
> always the more honest description. The repository keeps its original name so
> existing links and release URLs still resolve.

## Building

The Xcode project is **generated** from `project.yml` by
[XcodeGen](https://github.com/yonaskolb/XcodeGen) and is not committed, so
generate it first:

```bash
git clone https://github.com/SteliyanH/kadr-reels-studio.git
cd kadr-reels-studio
brew install xcodegen
make project
open ReelsStudio.xcodeproj
```

Edit `project.yml`, not the `.xcodeproj` — the latter is overwritten on every
generate. `Info.plist` values live there too.

Signing needs your own team: set `DEVELOPMENT_TEAM` in `project.yml`, or build
for the Simulator with `CODE_SIGNING_ALLOWED=NO`.

## Requirements

iOS 17 · Xcode 16 · Swift 6 · [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## The kadr ecosystem

This app is the consumer; the libraries are the point.

| Package | What this app uses it for |
|---|---|
| [`kadr`](https://github.com/SteliyanH/kadr) | Composition and export — the whole timeline is a `Video`. |
| [`kadr-ui`](https://github.com/SteliyanH/kadr-ui) | Preview, timeline, transport, inspector, keyframe editor. |
| [`kadr-persistence`](https://github.com/SteliyanH/kadr-persistence) | Saving and reopening projects. |
| [`kadr-audio`](https://github.com/SteliyanH/kadr-audio) | Music library, voiceover recording, loudness. |
| [`kadr-captions`](https://github.com/SteliyanH/kadr-captions) | Importing SRT / VTT caption files. |
| [`kadr-photos`](https://github.com/SteliyanH/kadr-photos) | The photo-library picker and asset resolution. |

Most of the API gaps closed across those packages were found here, by building
against the published surface rather than from inside them.

## License

Apache-2.0. See [LICENSE](LICENSE).

Contributions are accepted under the [Contributor License Agreement](CLA.md), which is signed once and covers all future contributions. It does not transfer ownership — you keep the copyright in your work.
