import SwiftUI
import Kadr
import KadrUI

/// The timeline band — `KadrUI.TimelineView` wrapped on the studio ground,
/// with the app-drawn tick row above it.
///
/// v0.8 Tier 5b — the toolbar moved out of this file and up to ``EditorView``,
/// where the approved design puts it (below the inspector, at the bottom of
/// the stack). This view is now the timeline band and nothing else.
///
/// **What the app can style here.** The band's ground, its padding, the tick
/// row, and the four layout parameters `TimelineView` exposes
/// (`laneHeight` / `laneSpacing` / `showAudioWaveforms` / `showLaneLabels`).
/// Everything the component draws inside itself — clip cells, their fills and
/// 4pt corners, the red playhead, lane backgrounds, the waveform's colour —
/// is a private literal upstream with no theming API. Those are reported as
/// gaps, not worked around.
struct TimelineArea: View {

    var store: ProjectStore
    @Environment(\.modernistPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: Modernist.Space.s1) {
            tickRow
            timeline
        }
        .padding(.vertical, Modernist.Space.s2)
        .frame(maxWidth: .infinity)
        .background(palette.surface)
    }

    // MARK: - Tick row

    /// The scale legend above the timeline: numerals at whole-second
    /// intervals derived from the project's own zoom, with the "N px/s"
    /// readout pinned right.
    ///
    /// kadr-ui draws no ruler of its own, so this is presentation of state
    /// the app already owns (`Project.zoom`), not a new feature. It reads
    /// from t = 0: `TimelineView` keeps its scroll offset private, so the row
    /// can't track a scrolled or centre-locked playhead. Reported as a gap.
    private var tickRow: some View {
        let pixelsPerSecond = TimelineArea.pixelsPerSecond(of: store.project.zoom)
        let step = TimelineArea.tickStepSeconds(pixelsPerSecond: pixelsPerSecond)

        // The tick strip is deliberately wider than the screen — it has to be,
        // to lay numerals out at a fixed pixels-per-second scale. It rides in
        // an `.overlay` on a zero-content spacer so that width can never
        // propagate: an overlay is sized by its host, so the band keeps
        // reporting the screen's width instead of the strip's. (Laid out as a
        // plain child it widened the whole editor stack and pushed the nav
        // bar's cells off-screen — caught by the UI suite.)
        return Color.clear
            .frame(height: Modernist.Space.s4)
            .overlay(alignment: .leading) { ticks(step: step, pixelsPerSecond: pixelsPerSecond) }
            .clipped()
            .overlay(alignment: .trailing) { zoomReadout(pixelsPerSecond: pixelsPerSecond) }
            .padding(.horizontal, Modernist.Space.s4)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Timeline scale")
            .accessibilityValue(TimelineArea.zoomReadout(pixelsPerSecond: pixelsPerSecond))
    }

    private func ticks(step: Double, pixelsPerSecond: Double) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(0..<TimelineArea.tickCount, id: \.self) { index in
                Text(verbatim: TimelineArea.tickLabel(seconds: Double(index) * step))
                    .font(Modernist.Typography.numeric)
                    .foregroundStyle(palette.textMuted)
                    .frame(width: step * pixelsPerSecond, alignment: .leading)
            }
        }
        .fixedSize()
    }

    /// Pinned right, on its own `surface` block so the numerals scrolling
    /// under it don't collide with it — the same masking the design shows.
    private func zoomReadout(pixelsPerSecond: Double) -> some View {
        HStack(spacing: Modernist.Space.s1) {
            Image(systemName: "plus.magnifyingglass")
            Text(verbatim: TimelineArea.zoomReadout(pixelsPerSecond: pixelsPerSecond))
        }
        .font(Modernist.Typography.numeric)
        .foregroundStyle(palette.textMuted)
        .padding(.leading, Modernist.Space.s2)
        .background(palette.surface)
    }

    // MARK: - Timeline

    @ViewBuilder
    private var timeline: some View {
        TimelineView(
            store.video,
            currentTime: Binding(
                get: { store.currentTime },
                set: { store.currentTime = $0 }
            ),
            selectedClipID: Binding(
                get: { store.selectedClipID },
                set: { newValue in
                    // v0.4 Tier 5: in multi-select mode, kadr-ui's tap-to-
                    // select still writes here. We intercept and route the
                    // tapped id into the set toggle instead of replacing
                    // the single-select slot. Outside the mode the binding
                    // behaves normally.
                    if store.isMultiSelecting {
                        if let id = newValue {
                            if store.selectedClipIDs.contains(id) {
                                store.selectedClipIDs.remove(id)
                            } else {
                                store.selectedClipIDs.insert(id)
                            }
                        }
                    } else {
                        store.selectedClipID = newValue
                    }
                }
            ),
            selectedClipIDs: Binding(
                get: { store.selectedClipIDs },
                set: { store.selectedClipIDs = $0 }
            ),
            zoom: zoomBinding,
            // One value for every lane: the component takes a single
            // `laneHeight`, and the design's 44 / 18 / 22 split is
            // unreachable. The video lane wins — it's the one the user drags,
            // trims and reads filmstrips in.
            laneHeight: Modernist.timelineLaneHeight,
            laneSpacing: Modernist.Space.s1,
            showAudioWaveforms: true,
            showLaneLabels: true,
            onReorder: { event in
                store.replaceClips(event.newClips)
            },
            onTrackReorder: { event in
                // KadrUI hands us the full new top-level clips array with
                // the rebuilt Track substituted in place — same shape as
                // onReorder. Routes through the existing replaceClips
                // mutation.
                store.replaceClips(event.newClips)
            },
            onTrackTrim: { event in
                store.applyTrackTrim(
                    trackIndex: event.trackIndex,
                    clipIndex: event.clipIndex,
                    leadingTrim: event.leadingTrim,
                    trailingTrim: event.trailingTrim
                )
            }
        )
        .onAudioTrim { event in
            // v0.7 Tier 1 — kadr-ui v0.10.2's audio trim callback. Music and
            // SFX share the same `audioTracks` array; a single mutation
            // handles both.
            store.applyAudioTrim(
                trackIndex: event.trackIndex,
                leadingTrim: event.leadingTrim,
                trailingTrim: event.trailingTrim
            )
            HapticEngine.shared.snap()
        }
        .fixedCenterPlayhead(store.project.fixedCenterPlayhead)
        .onZoomSnap { _ in HapticEngine.shared.snap() }
        .onClipDragSnap { HapticEngine.shared.snap() }
        .onLongPressClip { id in
            // Enter multi-select mode + seed the set with the long-pressed
            // clip. Subsequent single taps toggle membership via the
            // intercepted selectedClipID binding above.
            HapticEngine.shared.thud()
            store.selectedClipID = nil  // clear single-select so the spring
                                        // doesn't transition through the clip row
            store.isMultiSelecting = true
            store.selectedClipIDs = [id]
        }
        .frame(height: TimelineArea.bandHeight(
            clips: store.project.clips,
            audioTrackCount: store.project.audioTracks.count
        ))
        .padding(.horizontal, Modernist.Space.s4)
        // The inner TimelineView's gesture surface is rich (tap to scrub,
        // pinch to zoom, drag to reorder, long-press to multi-select) and
        // not easily VoiceOver-introspectable. Label the wrapper so a
        // VoiceOver user at least gets oriented; per-clip a11y is gated on
        // a future kadr-ui surface. v0.5 Tier 2.
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Timeline")
        .accessibilityHint("\(store.project.clips.count) clip\(store.project.clips.count == 1 ? "" : "s"). Long-press a clip to start a multi-selection.")
    }

    /// Binding to ``Project/zoom`` that initializes a non-nil value on first
    /// access. Without this, the first pinch wouldn't have anywhere to
    /// write — `TimelineView`'s `Binding<TimelineZoom>?` accepts nil for
    /// the auto fit-to-width path, but kadr-ui needs a writable binding to
    /// honor pinch gestures. We seed with a starting density the first time
    /// the pinch handler reads it.
    private var zoomBinding: Binding<TimelineZoom>? {
        Binding(
            get: {
                store.project.zoom
                    ?? TimelineZoom(pixelsPerSecond: TimelineArea.defaultPixelsPerSecond)
            },
            set: { store.updateZoom($0) }
        )
    }
}

// MARK: - Pure layout helpers

extension TimelineArea {

    /// The density the zoom binding seeds on first pinch. Named once so the
    /// tick row's readout can't drift from what the timeline actually uses.
    static let defaultPixelsPerSecond: Double = 50

    /// How many ticks the row emits. The viewport is at most ~1100pt wide on
    /// any supported device and ticks never sit closer than
    /// `Modernist.timelineTickMinSpacing`, so this is a generous ceiling on
    /// what can be visible; the row is clipped, and emitting more would be
    /// building views nobody can see.
    static let tickCount = 32

    /// Effective scale, falling back to the seed the zoom binding uses.
    nonisolated static func pixelsPerSecond(of zoom: TimelineZoom?) -> Double {
        guard let zoom, zoom.pixelsPerSecond > 0 else { return defaultPixelsPerSecond }
        return zoom.pixelsPerSecond
    }

    /// Seconds between labelled ticks: the finest interval from the standard
    /// ladder that still keeps two numerals `timelineTickMinSpacing` apart.
    /// Pure for testability.
    nonisolated static func tickStepSeconds(pixelsPerSecond: Double) -> Double {
        let ladder: [Double] = [1, 2, 5, 10, 30, 60]
        let minimum = Double(Modernist.timelineTickMinSpacing)
        guard pixelsPerSecond > 0 else { return ladder[ladder.count - 1] }
        return ladder.first { $0 * pixelsPerSecond >= minimum } ?? ladder[ladder.count - 1]
    }

    /// A tick's label — "0s", "5s", "1:00". Minutes cross over at 60s so a
    /// zoomed-out timeline doesn't read "120s".
    nonisolated static func tickLabel(seconds: Double) -> String {
        let total = Int(seconds.rounded())
        guard total >= 60 else { return "\(total)s" }
        return "\(total / 60):" + String(format: "%02d", total % 60)
    }

    /// The zoom readout pinned to the row's trailing edge — "48 px/s". The
    /// unit is a symbol, not prose, so it stays verbatim.
    nonisolated static func zoomReadout(pixelsPerSecond: Double) -> String {
        "\(Int(pixelsPerSecond.rounded())) px/s"
    }

    /// How many *non-audio* lanes `TimelineView` will draw for this project.
    ///
    /// Mirrors the lane order kadr-ui documents on `assignLanes` — implicit
    /// chain (always emitted, even when empty), then one lane per `Track`,
    /// then the free-floater pack. The component's own assignment is
    /// package-internal, so the free-floater pack is approximated as a single
    /// row: it is greedy-packed upstream and only splits when floaters
    /// overlap in time, which the app can't observe without duplicating the
    /// algorithm. Under-counting costs height, never correctness — the band
    /// clips, it doesn't misalign.
    nonisolated static func nonAudioLaneCount(clips: [any Clip]) -> Int {
        var count = 1
        count += clips.filter { $0 is Track }.count
        let hasFloaters = clips.contains { !($0 is Track) && $0.startTime != nil }
        if hasFloaters { count += 1 }
        return count
    }

    // MARK: kadr-ui v0.12.0 layout constants, mirrored
    //
    // `TimelineView` is `GeometryReader`-driven: it fills whatever frame it is
    // handed and reports no intrinsic height, so the band has to know how tall
    // the component intends to be. These four values are the component's own
    // private metrics, mirrored here because there is no API that exposes
    // them — the scrub strip the component always draws above the lanes, the
    // fixed clip- and audio-lane heights it uses on its single-lane path
    // (where `laneHeight` is ignored entirely), and its internal stack
    // spacing. They are upstream constants, not design values: they don't
    // belong in `ModernistTheme`, which is this app's system, not kadr-ui's.
    // Both facts are on the gap list.

    /// The scrub strip drawn above every lane stack whenever a `currentTime`
    /// binding is passed — which the editor always does.
    private static let upstreamScrubStripHeight: CGFloat = 14
    /// The clip lane's height on the single-lane path. `laneHeight` does not
    /// apply there; the component hard-codes this.
    private static let upstreamSingleLaneClipHeight: CGFloat = 40
    /// The audio lane's height on the single-lane path.
    private static let upstreamSingleLaneAudioHeight: CGFloat = 12
    /// The component's internal stack spacing on the single-lane path.
    private static let upstreamSingleLaneSpacing: CGFloat = 4

    /// Height the band gives the component.
    ///
    /// kadr-ui takes two different layout paths, and they don't agree with
    /// each other: with one non-audio lane it renders a fixed-metric strip
    /// that ignores `laneHeight` outright, and with more than one it renders
    /// `laneHeight`-tall lanes. The band mirrors whichever path the project
    /// will take, so the lanes are never clipped and never swim in dead space.
    /// The multi-lane path is capped at `Modernist.timelineMaxVisibleLanes`:
    /// the component doesn't scroll vertically, so an uncapped stack of audio
    /// lanes would push the stage off the screen.
    nonisolated static func bandHeight(clips: [any Clip], audioTrackCount: Int) -> CGFloat {
        let audioLanes = max(0, audioTrackCount)
        let nonAudio = nonAudioLaneCount(clips: clips)

        guard nonAudio > 1 else {
            var height = upstreamScrubStripHeight
                + upstreamSingleLaneSpacing
                + upstreamSingleLaneClipHeight
            if audioLanes > 0 {
                height += upstreamSingleLaneSpacing + upstreamSingleLaneAudioHeight
            }
            return height
        }

        let lanes = min(nonAudio + audioLanes, Modernist.timelineMaxVisibleLanes)
        return upstreamScrubStripHeight
            + CGFloat(lanes) * Modernist.timelineLaneHeight
            + CGFloat(lanes) * Modernist.Space.s1
    }
}
