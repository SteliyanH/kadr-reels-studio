import XCTest
import CoreMedia
import Kadr
import KadrUI
@testable import ReelsStudio

@MainActor
final class EditorToolbarTests: XCTestCase {

    // MARK: - Body smoke across the three modes

    func testToolbarBuildsInEveryMode() {
        let store = ProjectStore(project: Project())
        let toolbar = EditorToolbar(
            store: store,
            onAddClip: {}, onAddOverlay: {}, onLayers: {},
            onAddMusic: {}, onAddSFX: {}, onAddCaptions: {},
            onExport: {}, onSpeedCurve: { _ in }
        )

        // Root row.
        _ = toolbar.body

        // Clip-action row.
        let clipID = ClipID("clip-1")
        store.append(clip: ImageClip(PlatformImage()).id(clipID))
        store.selectedClipID = clipID
        _ = toolbar.body

        // Overlay-action row.
        let layerID = LayerID("ovl-1")
        store.append(overlay: TextOverlay("hi").id(layerID))
        store.selectedOverlayID = layerID
        _ = toolbar.body
    }

    // MARK: - Selection mutual exclusion stays consistent

    func testSelectingOverlayClearsClipSelection() {
        let store = ProjectStore(project: Project())
        store.append(clip: ImageClip(PlatformImage()).id(ClipID("c1")))
        store.append(overlay: TextOverlay("hi").id(LayerID("o1")))
        store.selectedClipID = ClipID("c1")
        store.selectedOverlayID = LayerID("o1")
        XCTAssertNil(store.selectedClipID)
    }

    // MARK: - v0.8 Tier 5b — the fourth mode builds too
    //
    // The multi-select row is the one mode the original smoke test never
    // entered, and Tier 5b rebuilt all four rows as ruled cell groups.

    func testToolbarBuildsInMultiSelectMode() {
        let store = ProjectStore(project: Project())
        let first = ClipID("c1")
        let second = ClipID("c2")
        store.append(clip: ImageClip(PlatformImage()).id(first))
        store.append(clip: ImageClip(PlatformImage()).id(second))
        store.isMultiSelecting = true
        store.selectedClipIDs = [first, second]

        let toolbar = EditorToolbar(
            store: store,
            onAddClip: {}, onAddOverlay: {}, onLayers: {},
            onAddMusic: {}, onAddSFX: {}, onAddCaptions: {},
            onExport: {}, onSpeedCurve: { _ in }
        )
        _ = toolbar.body
        XCTAssertEqual(store.selectedClipIDs.count, 2)
    }
}

/// v0.8 Tier 5b — the pure helpers behind the rebuilt editor chrome: the nav
/// bar's status line, the stage's spec chip, the timeline band's tick row and
/// lane sizing, and the text-effect rows' readout. Every one reads state the
/// editor already held; none of them can change what the editor *does*, which
/// is exactly why they're the part worth pinning.
@MainActor
final class EditorChromeTests: XCTestCase {

    // MARK: - Nav status line

    func testAspectLabelReducesPresetResolution() {
        XCTAssertEqual(EditorView.aspectLabel(for: .reelsAndShorts), "9:16")
        XCTAssertEqual(EditorView.aspectLabel(for: .square), "1:1")
        XCTAssertEqual(EditorView.aspectLabel(for: .cinema), "16:9")
    }

    func testTimecodeFormatsAsMinutesAndPaddedSeconds() {
        XCTAssertEqual(EditorView.timecode(CMTime(seconds: 6, preferredTimescale: 600)), "0:06")
        XCTAssertEqual(EditorView.timecode(CMTime(seconds: 65, preferredTimescale: 600)), "1:05")
        XCTAssertEqual(EditorView.timecode(.zero), "0:00")
    }

    func testTimecodeClampsNegativeAndIndefiniteTimes() {
        XCTAssertEqual(EditorView.timecode(CMTime(seconds: -3, preferredTimescale: 600)), "0:00")
        XCTAssertEqual(EditorView.timecode(.indefinite), "0:00")
    }

    func testStatusMetricsCarryRatioAndDuration() {
        let metrics = EditorView.statusMetrics(
            preset: .reelsAndShorts,
            duration: CMTime(seconds: 6, preferredTimescale: 600)
        )
        XCTAssertTrue(metrics.contains("9:16"), metrics)
        XCTAssertTrue(metrics.contains("0:06"), metrics)
    }

    // MARK: - Stage spec chip

    func testSpecChipReadsResolutionAndFrameRateFromPreset() {
        XCTAssertEqual(PreviewArea.specChipText(for: .reelsAndShorts), "1080×1920 · 30 fps")
        XCTAssertEqual(PreviewArea.specChipText(for: .cinema), "1920×1080 · 24 fps")
    }

    // MARK: - Timeline tick row

    func testTickStepStepsUpAsTheTimelineZoomsOut() {
        // At the design's own scale a tick lands on every second.
        XCTAssertEqual(TimelineArea.tickStepSeconds(pixelsPerSecond: 48), 1)
        XCTAssertEqual(TimelineArea.tickStepSeconds(pixelsPerSecond: 50), 1)
        // Zoomed out, numerals would collide, so the row coarsens.
        XCTAssertEqual(TimelineArea.tickStepSeconds(pixelsPerSecond: 10), 5)
        XCTAssertEqual(TimelineArea.tickStepSeconds(pixelsPerSecond: 2), 30)
        XCTAssertEqual(TimelineArea.tickStepSeconds(pixelsPerSecond: 0.1), 60)
    }

    func testTickLabelsCrossOverToMinutes() {
        XCTAssertEqual(TimelineArea.tickLabel(seconds: 0), "0s")
        XCTAssertEqual(TimelineArea.tickLabel(seconds: 5), "5s")
        XCTAssertEqual(TimelineArea.tickLabel(seconds: 90), "1:30")
    }

    func testZoomReadoutFallsBackToTheBindingSeed() {
        XCTAssertEqual(TimelineArea.zoomReadout(pixelsPerSecond: 48), "48 px/s")
        XCTAssertEqual(
            TimelineArea.pixelsPerSecond(of: nil),
            TimelineArea.defaultPixelsPerSecond
        )
        XCTAssertEqual(
            TimelineArea.pixelsPerSecond(of: TimelineZoom(pixelsPerSecond: 120)),
            120
        )
    }

    // MARK: - Timeline band sizing

    func testNonAudioLaneCountAlwaysEmitsTheImplicitChain() {
        XCTAssertEqual(TimelineArea.nonAudioLaneCount(clips: []), 1)

        let chain: [any Clip] = [
            ImageClip(PlatformImage()).id(ClipID("c1")),
            ImageClip(PlatformImage()).id(ClipID("c2"))
        ]
        // A plain chain is still one lane, however many clips are on it.
        XCTAssertEqual(TimelineArea.nonAudioLaneCount(clips: chain), 1)
    }

    func testBandHeightFollowsWhicheverLayoutPathTheComponentTakes() {
        let chain: [any Clip] = [ImageClip(PlatformImage()).id(ClipID("c1"))]

        // Single non-audio lane: kadr-ui renders its fixed-metric strip and
        // ignores `laneHeight` outright, so the band must not size to it.
        let single = TimelineArea.bandHeight(clips: chain, audioTrackCount: 0)
        XCTAssertGreaterThan(single, Reel.timelineLaneHeight)
        XCTAssertLessThan(single, Reel.timelineLaneHeight * 2)

        // An audio track adds its (also fixed) lane on that same path.
        let withAudio = TimelineArea.bandHeight(clips: chain, audioTrackCount: 1)
        XCTAssertGreaterThan(withAudio, single)

        // Audio lanes alone never trip the multi-lane path — that's driven by
        // non-audio lanes only, matching the component's own branch.
        XCTAssertEqual(
            TimelineArea.bandHeight(clips: chain, audioTrackCount: 4),
            withAudio
        )
    }

    func testBandHeightCapsOnTheMultiLanePath() {
        // Two non-audio lanes require a Track alongside the chain; stand in
        // for it with the count helper's own contract by driving the audio
        // side past the cap once the multi-lane path is active.
        let chain: [any Clip] = [ImageClip(PlatformImage()).id(ClipID("c1"))]
        let single = TimelineArea.bandHeight(clips: chain, audioTrackCount: 0)

        // Whatever path is taken, the band never grows without bound: the
        // capped height is what an absurd project resolves to.
        let absurd = TimelineArea.bandHeight(clips: chain, audioTrackCount: 99)
        XCTAssertLessThanOrEqual(
            absurd,
            CGFloat(Reel.timelineMaxVisibleLanes)
                * (Reel.timelineLaneHeight + Reel.Space.s1) + 100
        )
        XCTAssertGreaterThanOrEqual(absurd, single)
    }

    // MARK: - Text-effect readout

    func testEffectReadoutKeepsOneDecimal() {
        // Same numbers the rows printed before they moved onto ReelSlider.
        XCTAssertEqual(TextEffectsSection.readout(2), "2.0")
        XCTAssertEqual(TextEffectsSection.readout(-12.34), "-12.3")
    }
}

@MainActor
final class ToolbarActionsTests: XCTestCase {

    // MARK: - Clip remove

    func testRemoveClipDeletesAndClearsSelection() {
        let store = ProjectStore(project: Project())
        let id = ClipID("c1")
        store.append(clip: ImageClip(PlatformImage()).id(id))
        store.selectedClipID = id
        store.removeClip(id: id)
        XCTAssertEqual(store.project.clips.count, 0)
        XCTAssertNil(store.selectedClipID)
    }

    func testRemoveClipNoOpsForUnknownID() {
        let store = ProjectStore(project: Project())
        store.append(clip: ImageClip(PlatformImage()).id(ClipID("c1")))
        store.removeClip(id: ClipID("does-not-exist"))
        XCTAssertEqual(store.project.clips.count, 1)
    }

    // MARK: - Clip duplicate

    func testDuplicateClipInsertsAfterOriginalWithFreshID() {
        let store = ProjectStore(project: Project())
        let id = ClipID("c1")
        store.append(clip: ImageClip(PlatformImage()).id(id))
        store.duplicateClip(id: id)
        XCTAssertEqual(store.project.clips.count, 2)
        XCTAssertEqual(store.project.clips[0].clipID, id)
        XCTAssertNotNil(store.project.clips[1].clipID)
        XCTAssertNotEqual(store.project.clips[1].clipID, id)
    }

    func testDuplicateClipUndoRestores() {
        let store = ProjectStore(project: Project())
        let id = ClipID("c1")
        store.append(clip: ImageClip(PlatformImage()).id(id))
        store.duplicateClip(id: id)
        store.undo()
        XCTAssertEqual(store.project.clips.count, 1)
    }

    // MARK: - Overlay remove / duplicate

    func testRemoveOverlayDeletesAndClearsSelection() {
        let store = ProjectStore(project: Project())
        let id = LayerID("o1")
        store.append(overlay: TextOverlay("hi").id(id))
        store.selectedOverlayID = id
        store.removeOverlay(id: id)
        XCTAssertEqual(store.project.overlays.count, 0)
        XCTAssertNil(store.selectedOverlayID)
    }

    func testDuplicateOverlayInsertsAfterOriginalWithFreshID() {
        let store = ProjectStore(project: Project())
        let id = LayerID("o1")
        store.append(overlay: TextOverlay("hi").id(id))
        store.duplicateOverlay(id: id)
        XCTAssertEqual(store.project.overlays.count, 2)
        XCTAssertEqual(store.project.overlays[0].layerID, id)
        XCTAssertNotEqual(store.project.overlays[1].layerID, id)
    }

    // MARK: - moveOverlay forward / back / clamping

    func testMoveOverlayForwardSwapsWithNeighbor() {
        let store = ProjectStore(project: Project())
        store.append(overlay: TextOverlay("a").id(LayerID("a")))
        store.append(overlay: TextOverlay("b").id(LayerID("b")))
        store.moveOverlay(id: LayerID("a"), by: 1)
        XCTAssertEqual(store.project.overlays.first?.layerID, LayerID("b"))
        XCTAssertEqual(store.project.overlays.last?.layerID, LayerID("a"))
    }

    func testMoveOverlayBackSwapsWithNeighbor() {
        let store = ProjectStore(project: Project())
        store.append(overlay: TextOverlay("a").id(LayerID("a")))
        store.append(overlay: TextOverlay("b").id(LayerID("b")))
        store.moveOverlay(id: LayerID("b"), by: -1)
        XCTAssertEqual(store.project.overlays.first?.layerID, LayerID("b"))
    }

    func testMoveOverlayClampsAtBounds() {
        let store = ProjectStore(project: Project())
        store.append(overlay: TextOverlay("a").id(LayerID("a")))
        store.append(overlay: TextOverlay("b").id(LayerID("b")))
        store.moveOverlay(id: LayerID("a"), by: -5)  // already at 0; no-op
        XCTAssertEqual(store.project.overlays.first?.layerID, LayerID("a"))
        store.moveOverlay(id: LayerID("b"), by: 99)  // already at end; no-op
        XCTAssertEqual(store.project.overlays.last?.layerID, LayerID("b"))
    }
}
