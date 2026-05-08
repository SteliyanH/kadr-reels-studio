import XCTest
import CoreMedia
import Kadr
@testable import ReelsStudio

@MainActor
final class SplitClipTests: XCTestCase {

    // MARK: - ImageClip

    func testSplitImageClipBisectsDuration() {
        let store = ProjectStore(project: Project())
        let id = ClipID("c1")
        let clip = ImageClip(PlatformImage(), duration: 4.0).id(id)
        store.append(clip: clip)

        let result = store.splitClip(id: id, at: CMTime(seconds: 1.5, preferredTimescale: 600))
        XCTAssertEqual(result, .ok)
        XCTAssertEqual(store.project.clips.count, 2)

        let left = store.project.clips[0] as? ImageClip
        let right = store.project.clips[1] as? ImageClip
        XCTAssertEqual(left?.duration.seconds ?? 0, 1.5, accuracy: 0.001)
        XCTAssertEqual(right?.duration.seconds ?? 0, 2.5, accuracy: 0.001)

        // Left keeps the original ID; right gets a fresh one.
        XCTAssertEqual(left?.clipID, id)
        XCTAssertNotNil(right?.clipID)
        XCTAssertNotEqual(right?.clipID, id)
    }

    func testSplitImageClipUsesCompositionRelativeTime() {
        let store = ProjectStore(project: Project())
        store.append(clip: ImageClip(PlatformImage(), duration: 2.0).id(ClipID("c1")))
        store.append(clip: ImageClip(PlatformImage(), duration: 4.0).id(ClipID("c2")))

        // Composition time 3.0s → 1.0s into c2.
        let result = store.splitClip(id: ClipID("c2"), at: CMTime(seconds: 3.0, preferredTimescale: 600))
        XCTAssertEqual(result, .ok)
        XCTAssertEqual(store.project.clips.count, 3)

        let leftHalf = store.project.clips[1] as? ImageClip
        let rightHalf = store.project.clips[2] as? ImageClip
        XCTAssertEqual(leftHalf?.duration.seconds ?? 0, 1.0, accuracy: 0.001)
        XCTAssertEqual(rightHalf?.duration.seconds ?? 0, 3.0, accuracy: 0.001)
    }

    // MARK: - Failure modes

    func testSplitClipNotFoundWhenIDMissing() {
        let store = ProjectStore(project: Project())
        store.append(clip: ImageClip(PlatformImage()).id(ClipID("c1")))
        let result = store.splitClip(id: ClipID("missing"), at: CMTime(seconds: 1, preferredTimescale: 600))
        XCTAssertEqual(result, .clipNotFound)
        XCTAssertEqual(store.project.clips.count, 1)  // unchanged
    }

    func testSplitOffsetOutOfRangeAtZero() {
        let store = ProjectStore(project: Project())
        let id = ClipID("c1")
        store.append(clip: ImageClip(PlatformImage(), duration: 4.0).id(id))
        let result = store.splitClip(id: id, at: .zero)
        XCTAssertEqual(result, .offsetOutOfRange)
        XCTAssertEqual(store.project.clips.count, 1)
    }

    func testSplitOffsetOutOfRangeAtClipEnd() {
        let store = ProjectStore(project: Project())
        let id = ClipID("c1")
        store.append(clip: ImageClip(PlatformImage(), duration: 4.0).id(id))
        let result = store.splitClip(id: id, at: CMTime(seconds: 4.0, preferredTimescale: 600))
        XCTAssertEqual(result, .offsetOutOfRange)
        XCTAssertEqual(store.project.clips.count, 1)
    }

    func testSplitClipInsideTrackReportsTrackFailure() {
        let store = ProjectStore(project: Project())
        let inner = ImageClip(PlatformImage(), duration: 2.0).id(ClipID("inner"))
        let track = Track { inner }
        store.append(clip: track)

        let result = store.splitClip(id: ClipID("inner"), at: CMTime(seconds: 1, preferredTimescale: 600))
        XCTAssertEqual(result, .clipInsideTrack)
        XCTAssertEqual(store.project.clips.count, 1)
    }

    // MARK: - Undo

    func testSplitUndoRestoresOriginalClip() {
        let store = ProjectStore(project: Project())
        let id = ClipID("c1")
        store.append(clip: ImageClip(PlatformImage(), duration: 4.0).id(id))
        _ = store.splitClip(id: id, at: CMTime(seconds: 2.0, preferredTimescale: 600))
        XCTAssertEqual(store.project.clips.count, 2)
        store.undo()
        XCTAssertEqual(store.project.clips.count, 1)
        XCTAssertEqual((store.project.clips.first as? ImageClip)?.duration.seconds ?? 0, 4.0, accuracy: 0.001)
    }
}

@MainActor
final class FiltersSheetTests: XCTestCase {

    func testAddFilterAppendsToVideoClip() {
        let store = ProjectStore(project: Project())
        let id = ClipID("v1")
        let url = URL(fileURLWithPath: "/tmp/x.mov")
        store.append(clip: VideoClip(url: url).id(id))

        store.addFilter(id: id, .brightness(0.5))
        let video = store.project.clips.first as? VideoClip
        XCTAssertEqual(video?.filters.count, 1)
    }

    func testAddFilterNoOpForNonVideoClip() {
        let store = ProjectStore(project: Project())
        let id = ClipID("c1")
        store.append(clip: ImageClip(PlatformImage()).id(id))

        store.addFilter(id: id, .brightness(0.5))
        XCTAssertNotNil(store.project.clips.first as? ImageClip)
        // ImageClip has no filters surface; mutation is a no-op without
        // mutating the project. We just guard that we didn't replace the
        // clip with a different kind.
    }

    func testRemoveFilterDropsIndexed() {
        let store = ProjectStore(project: Project())
        let id = ClipID("v1")
        let url = URL(fileURLWithPath: "/tmp/x.mov")
        store.append(clip: VideoClip(url: url).id(id))
        store.addFilter(id: id, .brightness(0.5))
        store.addFilter(id: id, .contrast(1.2))

        store.removeFilter(id: id, filterIndex: 0)
        let video = store.project.clips.first as? VideoClip
        XCTAssertEqual(video?.filters.count, 1)
        if case .contrast = video?.filters.first {} else { XCTFail("Expected contrast filter to remain") }
    }

    func testRemoveFilterUndoRestoresIt() {
        let store = ProjectStore(project: Project())
        let id = ClipID("v1")
        let url = URL(fileURLWithPath: "/tmp/x.mov")
        store.append(clip: VideoClip(url: url).id(id))
        store.addFilter(id: id, .brightness(0.5))
        store.removeFilter(id: id, filterIndex: 0)
        XCTAssertEqual((store.project.clips.first as? VideoClip)?.filters.count, 0)
        store.undo()
        XCTAssertEqual((store.project.clips.first as? VideoClip)?.filters.count, 1)
    }

    func testFiltersSheetBodyConstructs() {
        let store = ProjectStore(project: Project())
        let id = ClipID("v1")
        let url = URL(fileURLWithPath: "/tmp/x.mov")
        store.append(clip: VideoClip(url: url).id(id))
        let sheet = FiltersSheet(store: store, clipID: id)
        _ = sheet.body
    }
}
