import XCTest
import CoreMedia
import Kadr
import KadrPersistence
@testable import ReelsStudio

/// v0.7 Tier 2 — tests for `insertTransition` / `removeTransition` mutations
/// and their pure helpers. Plus `EditorToolbar.clipHasSuccessor` (drives
/// the toolbar button's visibility).
@MainActor
final class TransitionsTests: XCTestCase {

    private func makeClip(id: ClipID) -> ImageClip {
        ImageClip(PlatformImage(), duration: 1.0).id(id)
    }

    private let halfSecond = CMTime(seconds: 0.5, preferredTimescale: 600)

    // MARK: - insertingTransition pure helper

    func testInsertingTransitionBetweenTwoMediaClipsAddsTransition() {
        let clips: [any Clip] = [makeClip(id: "a"), makeClip(id: "b")]
        let result = ProjectStore.insertingTransition(
            clips: clips,
            afterClipID: "a",
            kind: .fade,
            duration: halfSecond
        )
        XCTAssertEqual(result.count, 3)
        XCTAssertTrue(result[1] is Kadr.Transition)
    }

    func testInsertingTransitionWhenOneAlreadyExistsReplaces() {
        let clips: [any Clip] = [
            makeClip(id: "a"),
            Kadr.Transition.fade(duration: halfSecond),
            makeClip(id: "b")
        ]
        let result = ProjectStore.insertingTransition(
            clips: clips,
            afterClipID: "a",
            kind: .dissolve,
            duration: halfSecond
        )
        XCTAssertEqual(result.count, 3, "Replace, don't duplicate")
        guard let transition = result[1] as? Kadr.Transition else {
            return XCTFail("Expected a transition at index 1")
        }
        if case .dissolve = transition {} else { XCTFail("Expected dissolve") }
    }

    func testInsertingTransitionForLastClipIsNoOp() {
        let clips: [any Clip] = [makeClip(id: "a"), makeClip(id: "b")]
        let result = ProjectStore.insertingTransition(
            clips: clips,
            afterClipID: "b",
            kind: .fade,
            duration: halfSecond
        )
        XCTAssertEqual(result.count, 2, "Last clip has no successor — no-op")
    }

    func testInsertingTransitionForUnknownClipIDIsNoOp() {
        let clips: [any Clip] = [makeClip(id: "a"), makeClip(id: "b")]
        let result = ProjectStore.insertingTransition(
            clips: clips,
            afterClipID: "ghost",
            kind: .fade,
            duration: halfSecond
        )
        XCTAssertEqual(result.count, 2)
    }

    // MARK: - removingTransition + hasTransitionAfter + currentTransition

    func testRemovingTransitionDropsIt() {
        let clips: [any Clip] = [
            makeClip(id: "a"),
            Kadr.Transition.fade(duration: halfSecond),
            makeClip(id: "b")
        ]
        let result = ProjectStore.removingTransition(clips: clips, afterClipID: "a")
        XCTAssertEqual(result.count, 2)
    }

    func testRemovingWhenNoTransitionIsNoOp() {
        let clips: [any Clip] = [makeClip(id: "a"), makeClip(id: "b")]
        let result = ProjectStore.removingTransition(clips: clips, afterClipID: "a")
        XCTAssertEqual(result.count, 2)
    }

    func testHasTransitionAfterDetectsPresence() {
        let withTransition: [any Clip] = [
            makeClip(id: "a"),
            Kadr.Transition.fade(duration: halfSecond),
            makeClip(id: "b")
        ]
        XCTAssertTrue(ProjectStore.hasTransitionAfter(clipID: "a", in: withTransition))

        let without: [any Clip] = [makeClip(id: "a"), makeClip(id: "b")]
        XCTAssertFalse(ProjectStore.hasTransitionAfter(clipID: "a", in: without))
    }

    func testCurrentTransitionReturnsKindAndDuration() {
        let clips: [any Clip] = [
            makeClip(id: "a"),
            Kadr.Transition.dissolve(duration: CMTime(seconds: 0.75, preferredTimescale: 600)),
            makeClip(id: "b")
        ]
        guard let current = ProjectStore.currentTransition(afterClipID: "a", in: clips) else {
            return XCTFail("Expected a current transition")
        }
        XCTAssertEqual(current.kind, .dissolve)
        XCTAssertEqual(CMTimeGetSeconds(current.duration), 0.75, accuracy: 0.001)
    }

    // MARK: - Mutation routes through undo

    func testInsertTransitionIsUndoable() {
        let project = Project(clips: [makeClip(id: "a"), makeClip(id: "b")])
        let store = ProjectStore(project: project)
        store.insertTransition(afterClipID: "a", kind: .fade, duration: halfSecond)
        XCTAssertEqual(store.project.clips.count, 3)
        store.undo()
        XCTAssertEqual(store.project.clips.count, 2)
    }

    func testChangeTransitionActionNameDistinguishesFromInsert() {
        // Insert first; then changing should use a different action name —
        // we don't assert the name directly (UndoManager exposes it on the
        // menu but XCTest can't read it without UIKit), but back-to-back
        // mutations should produce two separate undo entries (replace IS
        // an action, not a no-op).
        let project = Project(clips: [makeClip(id: "a"), makeClip(id: "b")])
        let store = ProjectStore(project: project)
        store.insertTransition(afterClipID: "a", kind: .fade, duration: halfSecond)
        store.insertTransition(afterClipID: "a", kind: .dissolve, duration: halfSecond)
        XCTAssertEqual(store.project.clips.count, 3, "Still one transition (replaced)")

        store.undo()  // back to fade
        guard let after = ProjectStore.currentTransition(afterClipID: "a", in: store.project.clips) else {
            return XCTFail("Expected a transition")
        }
        XCTAssertEqual(after.kind, .fade)
    }

    // MARK: - Toolbar button visibility

    func testToolbarShowsTransitionButtonOnlyForClipsWithSuccessor() {
        let clips: [any Clip] = [makeClip(id: "a"), makeClip(id: "b")]
        XCTAssertTrue(EditorToolbar.clipHasSuccessor(id: "a", in: clips))
        XCTAssertFalse(EditorToolbar.clipHasSuccessor(id: "b", in: clips), "Last clip has no successor")
        XCTAssertFalse(EditorToolbar.clipHasSuccessor(id: "ghost", in: clips))
    }
}
