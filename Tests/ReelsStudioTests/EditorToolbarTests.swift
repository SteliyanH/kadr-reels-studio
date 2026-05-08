import XCTest
import Kadr
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
