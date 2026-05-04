import XCTest
import Kadr
@testable import ReelsStudio

@MainActor
final class UndoRedoTests: XCTestCase {

    // MARK: - Fixtures

    private func makeStore() -> ProjectStore {
        ProjectStore(project: Project())
    }

    private func makeImageClip(_ id: String) -> ImageClip {
        ImageClip(PlatformImage(), duration: 1.0).id(ClipID(id))
    }

    // MARK: - Initial state

    func testFreshStoreHasNothingToUndoOrRedo() {
        let store = makeStore()
        XCTAssertFalse(store.canUndo)
        XCTAssertFalse(store.canRedo)
    }

    // MARK: - Single mutation lifecycle

    func testAppendMakesUndoAvailable() {
        let store = makeStore()
        store.append(clip: makeImageClip("a"))
        XCTAssertTrue(store.canUndo)
        XCTAssertFalse(store.canRedo)
        XCTAssertEqual(store.project.clips.count, 1)
    }

    func testUndoRevertsAppend() {
        let store = makeStore()
        store.append(clip: makeImageClip("a"))
        store.undo()
        XCTAssertEqual(store.project.clips.count, 0)
        XCTAssertFalse(store.canUndo)
        XCTAssertTrue(store.canRedo)
    }

    func testRedoReappliesAppend() {
        let store = makeStore()
        store.append(clip: makeImageClip("a"))
        store.undo()
        store.redo()
        XCTAssertEqual(store.project.clips.count, 1)
        XCTAssertEqual(store.project.clips.first?.clipID, ClipID("a"))
        XCTAssertTrue(store.canUndo)
        XCTAssertFalse(store.canRedo)
    }

    // MARK: - Multi-step history

    func testUndoStepsBackThroughMultipleMutations() {
        let store = makeStore()
        store.append(clip: makeImageClip("a"))
        store.append(clip: makeImageClip("b"))
        store.append(clip: makeImageClip("c"))
        XCTAssertEqual(store.project.clips.count, 3)
        store.undo()
        XCTAssertEqual(store.project.clips.count, 2)
        store.undo()
        XCTAssertEqual(store.project.clips.count, 1)
        store.undo()
        XCTAssertEqual(store.project.clips.count, 0)
        XCTAssertFalse(store.canUndo)
    }

    func testRedoRollsForwardAcrossMultipleStops() {
        let store = makeStore()
        store.append(clip: makeImageClip("a"))
        store.append(clip: makeImageClip("b"))
        store.undo()
        store.undo()
        store.redo()
        XCTAssertEqual(store.project.clips.count, 1)
        store.redo()
        XCTAssertEqual(store.project.clips.count, 2)
        XCTAssertEqual(store.project.clips.last?.clipID, ClipID("b"))
    }

    // MARK: - New mutation truncates redo stack

    func testNewMutationAfterUndoTruncatesRedo() {
        let store = makeStore()
        store.append(clip: makeImageClip("a"))
        store.append(clip: makeImageClip("b"))
        store.undo()
        // Now at [a], redo would re-add "b". Add "c" instead.
        store.append(clip: makeImageClip("c"))
        XCTAssertEqual(store.project.clips.map { $0.clipID }, [ClipID("a"), ClipID("c")])
        XCTAssertFalse(store.canRedo)
    }

    // MARK: - Specific mutation kinds undo correctly

    func testReplaceClipsRoundTripsThroughUndo() {
        let store = makeStore()
        let clipsBefore = [makeImageClip("a"), makeImageClip("b"), makeImageClip("c")]
        store.replaceClips(clipsBefore)
        let reordered = [makeImageClip("c"), makeImageClip("a"), makeImageClip("b")]
        store.replaceClips(reordered)
        XCTAssertEqual(store.project.clips.map { $0.clipID }, [ClipID("c"), ClipID("a"), ClipID("b")])
        store.undo()
        XCTAssertEqual(store.project.clips.map { $0.clipID }, [ClipID("a"), ClipID("b"), ClipID("c")])
    }

    func testApplyOpacityUndoes() {
        let store = makeStore()
        store.append(clip: makeImageClip("a"))
        store.applyOpacity(id: ClipID("a"), 0.5)
        XCTAssertEqual(store.project.clips.first?.opacity, 0.5)
        store.undo()
        XCTAssertNil(store.project.clips.first?.opacity)
    }

    func testApplyTransformUndoes() {
        let store = makeStore()
        store.append(clip: makeImageClip("a"))
        let transform = Transform(
            center: .normalized(x: 0.7, y: 0.3),
            rotation: .pi / 4,
            scale: 1.2,
            anchor: .center
        )
        store.applyTransform(id: ClipID("a"), transform)
        XCTAssertEqual(store.project.clips.first?.transform?.scale, 1.2)
        store.undo()
        XCTAssertNil(store.project.clips.first?.transform)
    }

    func testSetPresetUndoes() {
        let store = makeStore()
        XCTAssertEqual(documentPreset(store.project.preset), .reelsAndShorts)
        store.setPreset(.tiktok)
        XCTAssertEqual(documentPreset(store.project.preset), .tiktok)
        store.undo()
        XCTAssertEqual(documentPreset(store.project.preset), .reelsAndShorts)
    }

    // Tiny helper: kadr's `Preset` isn't Equatable for the `.custom` case, so
    // route comparisons through the Codable-friendly mirror.
    private func documentPreset(_ preset: Preset) -> ProjectPreset {
        ProjectDocument.documentPreset(from: preset)
    }

    // MARK: - Action names surface to the system menu

    func testActionNameIsRecorded() {
        let store = makeStore()
        store.append(clip: makeImageClip("a"))
        XCTAssertEqual(store.undoManager.undoActionName, "Add Clip")
    }

    func testActionNameForBatchAppend() {
        let store = makeStore()
        store.append(clips: [makeImageClip("a"), makeImageClip("b")])
        XCTAssertEqual(store.undoManager.undoActionName, "Add Clips")
    }

    // MARK: - Idempotent guards

    func testUndoOnEmptyHistoryIsNoOp() {
        let store = makeStore()
        store.undo()
        XCTAssertFalse(store.canUndo)
        XCTAssertFalse(store.canRedo)
    }

    func testRedoOnEmptyHistoryIsNoOp() {
        let store = makeStore()
        store.append(clip: makeImageClip("a"))
        // No undo yet — redo should be a no-op.
        store.redo()
        XCTAssertEqual(store.project.clips.count, 1)
    }
}
