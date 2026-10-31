import CoreMedia
import XCTest
import Kadr
import KadrPersistence
@testable import ReelsStudio

@MainActor
final class WrapInTrackTests: XCTestCase {

    private func makeStoreWithThreeClips() -> ProjectStore {
        let store = ProjectStore(project: Project())
        store.append(clip: ImageClip(PlatformImage(), duration: 2.0).id(ClipID("c1")))
        store.append(clip: ImageClip(PlatformImage(), duration: 2.0).id(ClipID("c2")))
        store.append(clip: ImageClip(PlatformImage(), duration: 2.0).id(ClipID("c3")))
        return store
    }

    // MARK: - Success paths

    func testWrapContiguousPairCollapsesToSingleTrack() async {
        let store = makeStoreWithThreeClips()
        let result = await store.wrapInTrack(ids: [ClipID("c1"), ClipID("c2")])
        XCTAssertEqual(result, .ok)
        // A gap holds c1 + c2's place so c3 doesn't move.
        guard store.project.clips.count == 3 else {
            return XCTFail("expected [gap, Track, c3], got \(store.project.clips.count) clips")
        }
        XCTAssertTrue(store.project.clips[0] is ImageClip)
        XCTAssertTrue(store.project.clips[1] is Track)
        XCTAssertEqual(store.project.clips[2].clipID, ClipID("c3"))

        let track = store.project.clips[1] as? Track
        XCTAssertEqual(track?.clips.count, 2)
        XCTAssertEqual(track?.clips[0].clipID, ClipID("c1"))
        XCTAssertEqual(track?.clips[1].clipID, ClipID("c2"))
    }

    func testWrapSingleClipMakesSingleClipTrack() async {
        let store = makeStoreWithThreeClips()
        let result = await store.wrapInTrack(ids: [ClipID("c2")])
        XCTAssertEqual(result, .ok)
        XCTAssertEqual((store.project.clips[2] as? Track)?.clips.map(\.clipID), [ClipID("c2")])
    }

    func testWrapExitsMultiSelectMode() async {
        let store = makeStoreWithThreeClips()
        store.isMultiSelecting = true
        store.selectedClipIDs = [ClipID("c1"), ClipID("c2")]
        _ = await store.wrapInTrack(ids: store.selectedClipIDs)
        XCTAssertFalse(store.isMultiSelecting)
        XCTAssertTrue(store.selectedClipIDs.isEmpty)
    }

    /// Transitions in the wrap range travel with the surrounding clips —
    /// they don't have a `clipID` so the contiguous check passes them
    /// through.
    func testWrapPullsInTransitionsBetweenSelectedClips() async {
        let store = ProjectStore(project: Project())
        store.append(clip: ImageClip(PlatformImage(), duration: 2.0).id(ClipID("c1")))
        store.append(clip: Transition.dissolve(duration: 0.5))
        store.append(clip: ImageClip(PlatformImage(), duration: 2.0).id(ClipID("c2")))
        let result = await store.wrapInTrack(ids: [ClipID("c1"), ClipID("c2")])
        XCTAssertEqual(result, .ok)
        let track = store.project.clips.first as? Track
        XCTAssertEqual(track?.clips.count, 3)
        XCTAssertTrue(track?.clips[1] is Transition)
    }

    // MARK: - Failure paths

    func testEmptySelectionIsNoOp() async {
        let store = makeStoreWithThreeClips()
        let result = await store.wrapInTrack(ids: [])
        XCTAssertEqual(result, .noSelection)
        XCTAssertEqual(store.project.clips.count, 3)
    }

    func testNonContiguousSelectionRejects() async {
        let store = makeStoreWithThreeClips()
        // c1 + c3 with c2 in between — not contiguous.
        let result = await store.wrapInTrack(ids: [ClipID("c1"), ClipID("c3")])
        XCTAssertEqual(result, .nonContiguous)
        XCTAssertEqual(store.project.clips.count, 3)
        XCTAssertFalse(store.project.clips.contains { $0 is Track })
    }

    func testIDInsideExistingTrackRejects() async {
        let store = ProjectStore(project: Project())
        let inner = ImageClip(PlatformImage(), duration: 2.0).id(ClipID("inner"))
        store.append(clip: Track { inner })
        let result = await store.wrapInTrack(ids: [ClipID("inner")])
        XCTAssertEqual(result, .clipsNotAtTopLevel)
    }

    // MARK: - Undo

    func testWrapUndoRestoresOriginalClips() async {
        let store = makeStoreWithThreeClips()
        _ = await store.wrapInTrack(ids: [ClipID("c1"), ClipID("c2")])
        XCTAssertEqual(store.project.clips.count, 3)
        store.undo()
        XCTAssertEqual(store.project.clips.count, 3)
        XCTAssertEqual(store.project.clips[0].clipID, ClipID("c1"))
        XCTAssertEqual(store.project.clips[1].clipID, ClipID("c2"))
        XCTAssertEqual(store.project.clips[2].clipID, ClipID("c3"))
    }

    // MARK: - Where the Track starts
    //
    // kadr draws a Track over the main chain, so the Track has to start where
    // its clips used to play. A Track at 0:00 would cover the start of the
    // video instead.

    private func trackStart(_ store: ProjectStore) -> Double? {
        let track = store.project.clips.last { $0 is Track } as? Track
        return track?.startTime.map(CMTimeGetSeconds)
    }

    func testWrapAnchorsTrackWhereTheFirstWrappedClipStarted() async {
        let store = makeStoreWithThreeClips()
        _ = await store.wrapInTrack(ids: [ClipID("c2"), ClipID("c3")])
        XCTAssertEqual(trackStart(store), 2.0)
    }

    func testWrapOfTheFirstClipAnchorsAtZero() async {
        let store = makeStoreWithThreeClips()
        _ = await store.wrapInTrack(ids: [ClipID("c1")])
        XCTAssertEqual(trackStart(store), 0.0)
    }

    /// A dissolve pulls the next clip back by its duration, so c2 started at
    /// 2.0 - 0.5.
    func testWrapAnchorFollowsADissolveOverlap() async {
        let store = ProjectStore(project: Project())
        store.append(clip: ImageClip(PlatformImage(), duration: 2.0).id(ClipID("c1")))
        store.append(clip: Transition.dissolve(duration: 0.5))
        store.append(clip: ImageClip(PlatformImage(), duration: 2.0).id(ClipID("c2")))
        _ = await store.wrapInTrack(ids: [ClipID("c2")])
        XCTAssertEqual(trackStart(store), 1.5)
    }

    /// A fade plays inside each clip and doesn't overlap them.
    func testWrapAnchorIgnoresAFade() async {
        let store = ProjectStore(project: Project())
        store.append(clip: ImageClip(PlatformImage(), duration: 2.0).id(ClipID("c1")))
        store.append(clip: Transition.fade(duration: 0.5))
        store.append(clip: ImageClip(PlatformImage(), duration: 2.0).id(ClipID("c2")))
        _ = await store.wrapInTrack(ids: [ClipID("c2")])
        XCTAssertEqual(trackStart(store), 2.0)
    }

    /// Tracks and pinned clips sit outside the chain, so they don't push the
    /// chain along.
    func testWrapAnchorSkipsTracksAndPinnedClips() async {
        let store = ProjectStore(project: Project())
        store.append(clip: ImageClip(PlatformImage(), duration: 2.0).id(ClipID("c1")))
        store.append(clip: Track { ImageClip(PlatformImage(), duration: 5.0) })
        store.append(clip: ImageClip(PlatformImage(), duration: 3.0).at(time: 10).id(ClipID("pinned")))
        store.append(clip: ImageClip(PlatformImage(), duration: 2.0).id(ClipID("c2")))
        _ = await store.wrapInTrack(ids: [ClipID("c2")])
        XCTAssertEqual(trackStart(store), 2.0)
    }

    func testWrapOfAPinnedClipAnchorsAtItsPin() async {
        let store = ProjectStore(project: Project())
        store.append(clip: ImageClip(PlatformImage(), duration: 2.0).id(ClipID("c1")))
        store.append(clip: ImageClip(PlatformImage(), duration: 3.0).at(time: 7).id(ClipID("pinned")))
        _ = await store.wrapInTrack(ids: [ClipID("pinned")])
        XCTAssertEqual(trackStart(store), 7.0)
    }

    /// An untrimmed VideoClip reports a zero duration until its asset loads,
    /// which is how clips arrive from Photos. The wrap has to load it, and
    /// apply the clip's speed.
    func testWrapAnchorLoadsUntrimmedVideoDurations() async throws {
        let url = try await SampleMedia.movieFileURL(seconds: 3)
        defer { try? FileManager.default.removeItem(at: url) }
        let store = ProjectStore(project: Project())
        store.append(clip: VideoClip(url: url).id(ClipID("v1")))
        store.append(clip: VideoClip(url: url).speed(.flat(2.0)).id(ClipID("v2")))
        store.append(clip: ImageClip(PlatformImage(), duration: 2.0).id(ClipID("c1")))
        XCTAssertEqual(store.project.clips[0].duration, .zero, "precondition: untrimmed clips report zero")

        // The encoded file is a frame or so shorter than asked for, so measure it.
        let file = try await CMTimeGetSeconds(VideoClip(url: url).metadata.duration)
        XCTAssertGreaterThan(file, 2.5)

        _ = await store.wrapInTrack(ids: [ClipID("c1")])
        let start = try XCTUnwrap(trackStart(store))
        XCTAssertEqual(start, file + file / 2, accuracy: 0.01)
    }

    // MARK: - The gap left in the main chain
    //
    // Lifting clips out of the chain would slide the clips after them earlier,
    // underneath the Track. A gap of the same length holds their place.

    private func seconds(_ clip: any Clip) -> Double { CMTimeGetSeconds(clip.duration) }

    func testWrapLeavesAGapSoLaterClipsKeepTheirTime() async {
        let store = makeStoreWithThreeClips()
        _ = await store.wrapInTrack(ids: [ClipID("c2")])
        let clips = store.project.clips
        guard clips.count == 4 else {
            return XCTFail("expected [c1, gap, Track, c3], got \(clips.count) clips")
        }
        XCTAssertEqual(clips[0].clipID, ClipID("c1"))
        let gap = clips[1] as? ImageClip
        XCTAssertNotNil(gap?.clipID, "the gap has an id so it can be selected and deleted")
        XCTAssertEqual(gap.map(seconds), 2.0)
        XCTAssertTrue(clips[2] is Track)
        XCTAssertEqual(clips[3].clipID, ClipID("c3"))
        XCTAssertEqual(trackStart(store), 2.0)
    }

    func testWrapAtTheEndOfTheChainLeavesNoGap() async {
        let store = makeStoreWithThreeClips()
        _ = await store.wrapInTrack(ids: [ClipID("c3")])
        XCTAssertEqual(store.project.clips.count, 3)
        XCTAssertEqual(store.project.clips[1].clipID, ClipID("c2"))
        XCTAssertTrue(store.project.clips[2] is Track)
    }

    /// The gap spans what the wrapped clips covered: 2 + 2 - 0.5 here.
    func testGapCountsADissolveInsideTheWrap() async {
        let store = ProjectStore(project: Project())
        store.append(clip: ImageClip(PlatformImage(), duration: 2.0).id(ClipID("c1")))
        store.append(clip: ImageClip(PlatformImage(), duration: 2.0).id(ClipID("c2")))
        store.append(clip: Transition.dissolve(duration: 0.5))
        store.append(clip: ImageClip(PlatformImage(), duration: 2.0).id(ClipID("c3")))
        store.append(clip: ImageClip(PlatformImage(), duration: 2.0).id(ClipID("c4")))
        _ = await store.wrapInTrack(ids: [ClipID("c2"), ClipID("c3")])
        XCTAssertEqual((store.project.clips[1] as? ImageClip).map(seconds), 3.5)
    }

    /// Without the gap the chain would end on the dissolve, which kadr
    /// refuses to build.
    func testWrapRightAfterATransitionLeavesAGap() async {
        let store = ProjectStore(project: Project())
        store.append(clip: ImageClip(PlatformImage(), duration: 2.0).id(ClipID("c1")))
        store.append(clip: Transition.dissolve(duration: 0.5))
        store.append(clip: ImageClip(PlatformImage(), duration: 2.0).id(ClipID("c2")))
        _ = await store.wrapInTrack(ids: [ClipID("c2")])
        let clips = store.project.clips
        guard clips.count == 4 else {
            return XCTFail("expected [c1, dissolve, gap, Track], got \(clips.count) clips")
        }
        XCTAssertTrue(clips[1] is Transition)
        XCTAssertEqual((clips[2] as? ImageClip).map(seconds), 2.0)
        XCTAssertTrue(clips[3] is Track)
    }

    func testGapSurvivesSaveAndReopen() async throws {
        let store = makeStoreWithThreeClips()
        _ = await store.wrapInTrack(ids: [ClipID("c2")])
        let gap = try XCTUnwrap(store.project.clips.dropFirst().first as? ImageClip)
        guard case .image(let data)? = ProjectDocument.documentClip(from: gap) else {
            return XCTFail("the gap didn't encode as an image clip")
        }
        let reopened = try XCTUnwrap(ProjectDocument.runtimeImageClip(from: data))
        XCTAssertEqual(reopened.clipID, gap.clipID)
        XCTAssertEqual(seconds(reopened), 2.0, accuracy: 0.001)
    }

    // MARK: - What the video shows

    /// Renders frames of red → green → blue with green wrapped. Each colour
    /// has to stay where it was: the Track over the gap, blue after it.
    func testWrappedVideoShowsEveryClipAtItsOriginalTime() async throws {
        let store = ProjectStore(project: Project())
        store.append(clip: ImageClip.color(.red, duration: 1.0).id(ClipID("red")))
        store.append(clip: ImageClip.color(.green, duration: 1.0).id(ClipID("green")))
        store.append(clip: ImageClip.color(.blue, duration: 1.0).id(ClipID("blue")))
        _ = await store.wrapInTrack(ids: [ClipID("green")])

        let video = store.project.makeVideo().preset(.custom(width: 128, height: 128, frameRate: 30, codec: .h264))
        for (time, expected) in [(0.5, "red"), (1.5, "green"), (2.5, "blue")] {
            let frame = try await video.thumbnail(at: time)
            XCTAssertEqual(dominantChannel(of: frame), expected, "at \(time)s")
        }
    }

    /// Which of red, green or blue the centre of `image` is.
    private func dominantChannel(of image: PlatformImage) -> String? {
        guard let cg = image.cgImage else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        context.draw(cg, in: CGRect(x: -w / 2 + 0.5, y: -h / 2 + 0.5, width: w, height: h))
        let (r, g, b) = (pixel[0], pixel[1], pixel[2])
        if r > 150 && g < 100 && b < 100 { return "red" }
        if g > 150 && r < 100 && b < 100 { return "green" }
        if b > 150 && r < 100 && g < 100 { return "blue" }
        return "rgb(\(r), \(g), \(b))"
    }
}

@MainActor
final class MultiSelectStateTests: XCTestCase {

    func testEnteringMultiSelectClearsOnExit() {
        let store = ProjectStore(project: Project())
        store.selectedClipIDs = [ClipID("a"), ClipID("b")]
        store.isMultiSelecting = true
        // Toggle off — set clears via didSet.
        store.isMultiSelecting = false
        XCTAssertTrue(store.selectedClipIDs.isEmpty)
    }

    func testEnteringMultiSelectDoesNotClearOnEntry() {
        let store = ProjectStore(project: Project())
        store.isMultiSelecting = true
        store.selectedClipIDs = [ClipID("a")]
        // Re-set the flag to the same value; the didSet only clears on
        // false transitions.
        store.isMultiSelecting = true
        XCTAssertEqual(store.selectedClipIDs, [ClipID("a")])
    }
}

@MainActor
final class WrapFailureDetailTests: XCTestCase {

    func testEveryFailureModeHasUserFacingCopy() {
        XCTAssertFalse(EditorToolbar.wrapFailureDetail(.noSelection).isEmpty)
        XCTAssertFalse(EditorToolbar.wrapFailureDetail(.nonContiguous).isEmpty)
        XCTAssertFalse(EditorToolbar.wrapFailureDetail(.clipsNotAtTopLevel).isEmpty)
        XCTAssertTrue(EditorToolbar.wrapFailureDetail(.ok).isEmpty)
    }
}
