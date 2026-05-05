import XCTest
import CoreMedia
import Kadr
import KadrUI
@testable import ReelsStudio

@MainActor
final class TimelineZoomAndTracksTests: XCTestCase {

    private func cmt(_ s: Double) -> CMTime { CMTime(seconds: s, preferredTimescale: 600) }

    // MARK: - Zoom

    func testUpdateZoomMutatesProject() {
        let store = ProjectStore(project: Project())
        XCTAssertNil(store.project.zoom)
        store.updateZoom(TimelineZoom(pixelsPerSecond: 75))
        XCTAssertEqual(store.project.zoom?.pixelsPerSecond, 75)
    }

    func testUpdateZoomDoesNotPushUndo() {
        let store = ProjectStore(project: Project())
        XCTAssertFalse(store.canUndo)
        store.updateZoom(TimelineZoom(pixelsPerSecond: 100))
        XCTAssertFalse(store.canUndo, "Zoom changes shouldn't pollute the undo stack")
    }

    func testUpdateZoomToNilClearsAndUsesAutoFitToWidth() {
        let store = ProjectStore(project: Project(zoom: TimelineZoom(pixelsPerSecond: 50)))
        store.updateZoom(nil)
        XCTAssertNil(store.project.zoom)
    }

    func testZoomSurvivesDocumentRoundTrip() {
        let project = Project(zoom: TimelineZoom(pixelsPerSecond: 75))
        let document = project.toDocument(name: "Zoomed")
        XCTAssertEqual(document.zoomPixelsPerSecond, 75)
        let restored = document.toRuntimeProject()
        XCTAssertEqual(restored.zoom?.pixelsPerSecond, 75)
    }

    func testNilZoomRoundTripsAsAbsentField() {
        let project = Project()
        let document = project.toDocument(name: "NoZoom")
        XCTAssertNil(document.zoomPixelsPerSecond)
        XCTAssertNil(document.toRuntimeProject().zoom)
    }

    // MARK: - Track trim — pure helper (applyingTrim)

    func testTrimVideoClipShiftsTrimRange() {
        let url = URL(fileURLWithPath: "/tmp/x.mp4")
        let original = VideoClip(url: url).trimmed(to: 1.0...4.0)
        let trimmed = ProjectStore.applyingTrim(
            to: original,
            leadingTrim: cmt(0.5),
            trailingTrim: cmt(0.5)
        ) as? VideoClip
        XCTAssertNotNil(trimmed)
        let range = trimmed?.trimRange
        XCTAssertEqual(CMTimeGetSeconds(range?.start ?? .zero), 1.5, accuracy: 0.0001)
        XCTAssertEqual(CMTimeGetSeconds(range?.duration ?? .zero), 2.0, accuracy: 0.0001)
    }

    func testTrimImageClipShortensDuration() {
        let original = ImageClip(PlatformImage(), duration: 4.0)
        let trimmed = ProjectStore.applyingTrim(
            to: original,
            leadingTrim: cmt(0.0),
            trailingTrim: cmt(1.0)
        ) as? ImageClip
        XCTAssertNotNil(trimmed)
        XCTAssertEqual(CMTimeGetSeconds(trimmed?.duration ?? .zero), 3.0, accuracy: 0.0001)
    }

    func testTrimImageClipBelowZeroReturnsNil() {
        let original = ImageClip(PlatformImage(), duration: 1.0)
        let trimmed = ProjectStore.applyingTrim(
            to: original,
            leadingTrim: cmt(0.6),
            trailingTrim: cmt(0.6)
        )
        XCTAssertNil(trimmed)
    }

    func testTrimTransitionReturnsNil() {
        let result = ProjectStore.applyingTrim(
            to: Kadr.Transition.fade(duration: 0.3),
            leadingTrim: .zero,
            trailingTrim: .zero
        )
        XCTAssertNil(result)
    }

    // MARK: - Track trim — full applyingTrackTrim

    func testApplyingTrackTrimAddressesCorrectInnerClip() {
        let img = PlatformImage()
        let track = Track(at: 1.0, name: "B-roll") {
            ImageClip(img, duration: 2.0).id(ClipID("a"))
            ImageClip(img, duration: 3.0).id(ClipID("b"))
        }
        let clips: [any Clip] = [
            ImageClip(img, duration: 1.0).id(ClipID("main")),
            track,
        ]
        let result = ProjectStore.applyingTrackTrim(
            clips: clips,
            trackIndex: 0,
            clipIndex: 1,
            leadingTrim: .zero,
            trailingTrim: cmt(0.5)
        )
        guard let updatedTrack = result[1] as? Track else {
            return XCTFail("Expected Track at index 1")
        }
        XCTAssertEqual(updatedTrack.clips.count, 2)
        // First inner clip unchanged.
        XCTAssertEqual(CMTimeGetSeconds(updatedTrack.clips[0].duration), 2.0, accuracy: 0.0001)
        // Second inner clip trimmed by 0.5.
        XCTAssertEqual(CMTimeGetSeconds(updatedTrack.clips[1].duration), 2.5, accuracy: 0.0001)
        // Top-level main clip unchanged.
        XCTAssertEqual(CMTimeGetSeconds(result[0].duration), 1.0, accuracy: 0.0001)
    }

    func testApplyingTrackTrimWithOutOfRangeClipIndexIsNoOp() {
        let img = PlatformImage()
        let track = Track(at: .zero) { ImageClip(img, duration: 1.0) }
        let clips: [any Clip] = [track]
        let result = ProjectStore.applyingTrackTrim(
            clips: clips,
            trackIndex: 0,
            clipIndex: 99,
            leadingTrim: .zero,
            trailingTrim: cmt(0.1)
        )
        // Track unchanged; same identity.
        XCTAssertEqual(result.count, 1)
    }

    func testApplyingTrackTrimWithOutOfRangeTrackIndexIsNoOp() {
        let img = PlatformImage()
        let track = Track(at: .zero) { ImageClip(img, duration: 1.0) }
        let clips: [any Clip] = [track]
        let result = ProjectStore.applyingTrackTrim(
            clips: clips,
            trackIndex: 5,
            clipIndex: 0,
            leadingTrim: .zero,
            trailingTrim: cmt(0.1)
        )
        XCTAssertEqual(result.count, 1)
    }

    // MARK: - Track trim — store mutation + undo

    func testApplyTrackTrimRoutesThroughUndo() {
        let img = PlatformImage()
        let track = Track(at: .zero, name: "B-roll") {
            ImageClip(img, duration: 4.0).id(ClipID("a"))
        }
        let project = Project(clips: [track])
        let store = ProjectStore(project: project)
        store.applyTrackTrim(
            trackIndex: 0,
            clipIndex: 0,
            leadingTrim: .zero,
            trailingTrim: cmt(1.0)
        )
        XCTAssertEqual(store.undoManager.undoActionName, "Trim Clip")
        guard let trimmedTrack = store.project.clips.first as? Track,
              let inner = trimmedTrack.clips.first else {
            return XCTFail("Expected Track with inner clip")
        }
        XCTAssertEqual(CMTimeGetSeconds(inner.duration), 3.0, accuracy: 0.0001)

        // Undo restores.
        store.undo()
        guard let undoneTrack = store.project.clips.first as? Track,
              let undoneInner = undoneTrack.clips.first else {
            return XCTFail("Expected Track after undo")
        }
        XCTAssertEqual(CMTimeGetSeconds(undoneInner.duration), 4.0, accuracy: 0.0001)
    }

    // MARK: - rebuildTrack helper

    func testRebuildTrackPreservesStartTimeAndOpacityFactor() {
        let img = PlatformImage()
        let original = Track(at: 2.5, name: "B-roll") {
            ImageClip(img, duration: 1.0)
        }
        .opacity(0.5)
        let rebuilt = ProjectStore.rebuildTrack(
            original,
            clips: [ImageClip(img, duration: 2.0)]
        )
        XCTAssertEqual(rebuilt.startTime, cmt(2.5))
        XCTAssertEqual(rebuilt.name, "B-roll")
        XCTAssertEqual(rebuilt.opacityFactor, 0.5)
        XCTAssertEqual(rebuilt.clips.count, 1)
    }
}
