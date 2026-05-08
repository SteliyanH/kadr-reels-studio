import Foundation
import CoreMedia
import SwiftUI
import Kadr
import KadrUI

/// In-memory editor state. Owned by ``ProjectStore``; mutating it through the store's
/// methods triggers SwiftUI body invalidation and rebuilds the underlying `Video`.
///
/// v0.1.0 keeps everything in memory — no persistence. v0.2 adds Codable + JSON
/// round-trip; the value-type shape makes that mechanical.
struct Project {

    /// Clip stack — chain order is render order. `[any Clip]` accommodates
    /// `VideoClip` / `ImageClip` / `Transition` / `Track` from kadr.
    var clips: [any Clip]

    /// Overlays drawn on top of the composition. Order is z-order (last draws on top).
    var overlays: [any Overlay]

    /// Background audio tracks — music, narration, SFX. Order matters only for the
    /// declaration-order crossfade pairing engine in kadr.
    var audioTracks: [AudioTrack]

    /// Captions baked as `AVMetadataItem` group at export. Empty by default.
    var captions: [Caption]

    /// Export preset. Reels Studio defaults to `.reelsAndShorts` (vertical 1080×1920);
    /// the export sheet lets the user override.
    var preset: Preset

    /// Timeline pinch-zoom state, persisted per project. `nil` means "use
    /// kadr-ui's auto fit-to-width" — the editor passes no zoom binding to
    /// `TimelineView` in that case. The first user pinch initializes a
    /// non-nil value; subsequent edits update it. v0.3 Tier 5.
    var zoom: TimelineZoom?

    /// Whether to anchor the playhead to the viewport center and scroll the
    /// timeline content under it (kadr-ui v0.9's
    /// `TimelineView.fixedCenterPlayhead(_:)`). Defaults to `true` — the
    /// CapCut / VN / iMovie behavior most users expect. v0.5's settings
    /// screen will surface a per-project toggle. v0.4 Tier 2.
    var fixedCenterPlayhead: Bool

    /// Per-project accent color. `nil` = follow the system tint (the v0.4
    /// default). Non-nil tints inspector tabs, keyframe playhead, timeline
    /// selection ring, and any other `.tint`-aware surface inside the
    /// editor via the editor-root `.tint(_:)` modifier in `EditorView`.
    /// v0.5's settings screen will add an iOS palette picker. v0.4 Tier 3.
    var accentColor: Color?

    init(
        clips: [any Clip] = [],
        overlays: [any Overlay] = [],
        audioTracks: [AudioTrack] = [],
        captions: [Caption] = [],
        preset: Preset = .reelsAndShorts,
        zoom: TimelineZoom? = nil,
        fixedCenterPlayhead: Bool = true,
        accentColor: Color? = nil
    ) {
        self.clips = clips
        self.overlays = overlays
        self.audioTracks = audioTracks
        self.captions = captions
        self.preset = preset
        self.zoom = zoom
        self.fixedCenterPlayhead = fixedCenterPlayhead
        self.accentColor = accentColor
    }

    /// Build a kadr `Video` from the current editor state. Called on every SwiftUI
    /// body invalidation — `ProjectStore.video` re-derives this each render.
    func makeVideo() -> Video {
        var video = Video {
            for clip in clips { clip }
        }
        .preset(preset)
        for overlay in overlays {
            video = video.overlay(overlay)
        }
        for track in audioTracks {
            video = video.audio { track }
        }
        if !captions.isEmpty {
            video = video.captions(captions)
        }
        return video
    }
}
