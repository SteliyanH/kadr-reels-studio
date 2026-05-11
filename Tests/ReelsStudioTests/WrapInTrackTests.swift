import XCTest
import Kadr
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

    func testWrapContiguousPairCollapsesToSingleTrack() {
        let store = makeStoreWithThreeClips()
        let result = store.wrapInTrack(ids: [ClipID("c1"), ClipID("c2")])
        XCTAssertEqual(result, .ok)
        XCTAssertEqual(store.project.clips.count, 2)
        XCTAssertTrue(store.project.clips[0] is Track)
        XCTAssertEqual(store.project.clips[1].clipID, ClipID("c3"))

        let track = store.project.clips[0] as? Track
        XCTAssertEqual(track?.clips.count, 2)
        XCTAssertEqual(track?.clips[0].clipID, ClipID("c1"))
        XCTAssertEqual(track?.clips[1].clipID, ClipID("c2"))
    }

    func testWrapSingleClipMakesSingleClipTrack() {
        let store = makeStoreWithThreeClips()
        let result = store.wrapInTrack(ids: [ClipID("c2")])
        XCTAssertEqual(result, .ok)
        XCTAssertTrue(store.project.clips[1] is Track)
    }

    func testWrapExitsMultiSelectMode() {
        let store = makeStoreWithThreeClips()
        store.isMultiSelecting = true
        store.selectedClipIDs = [ClipID("c1"), ClipID("c2")]
        _ = store.wrapInTrack(ids: store.selectedClipIDs)
        XCTAssertFalse(store.isMultiSelecting)
        XCTAssertTrue(store.selectedClipIDs.isEmpty)
    }

    /// Transitions in the wrap range travel with the surrounding clips —
    /// they don't have a `clipID` so the contiguous check passes them
    /// through.
    func testWrapPullsInTransitionsBetweenSelectedClips() {
        let store = ProjectStore(project: Project())
        store.append(clip: ImageClip(PlatformImage(), duration: 2.0).id(ClipID("c1")))
        store.append(clip: Transition.dissolve(duration: 0.5))
        store.append(clip: ImageClip(PlatformImage(), duration: 2.0).id(ClipID("c2")))
        let result = store.wrapInTrack(ids: [ClipID("c1"), ClipID("c2")])
        XCTAssertEqual(result, .ok)
        let track = store.project.clips.first as? Track
        XCTAssertEqual(track?.clips.count, 3)
        XCTAssertTrue(track?.clips[1] is Transition)
    }

    // MARK: - Failure paths

    func testEmptySelectionIsNoOp() {
        let store = makeStoreWithThreeClips()
        let result = store.wrapInTrack(ids: [])
        XCTAssertEqual(result, .noSelection)
        XCTAssertEqual(store.project.clips.count, 3)
    }

    func testNonContiguousSelectionRejects() {
        let store = makeStoreWithThreeClips()
        // c1 + c3 with c2 in between — not contiguous.
        let result = store.wrapInTrack(ids: [ClipID("c1"), ClipID("c3")])
        XCTAssertEqual(result, .nonContiguous)
        XCTAssertEqual(store.project.clips.count, 3)
        XCTAssertFalse(store.project.clips.contains { $0 is Track })
    }

    func testIDInsideExistingTrackRejects() {
        let store = ProjectStore(project: Project())
        let inner = ImageClip(PlatformImage(), duration: 2.0).id(ClipID("inner"))
        store.append(clip: Track { inner })
        let result = store.wrapInTrack(ids: [ClipID("inner")])
        XCTAssertEqual(result, .clipsNotAtTopLevel)
    }

    // MARK: - Undo

    func testWrapUndoRestoresOriginalClips() {
        let store = makeStoreWithThreeClips()
        _ = store.wrapInTrack(ids: [ClipID("c1"), ClipID("c2")])
        XCTAssertEqual(store.project.clips.count, 2)
        store.undo()
        XCTAssertEqual(store.project.clips.count, 3)
        XCTAssertEqual(store.project.clips[0].clipID, ClipID("c1"))
        XCTAssertEqual(store.project.clips[1].clipID, ClipID("c2"))
        XCTAssertEqual(store.project.clips[2].clipID, ClipID("c3"))
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
