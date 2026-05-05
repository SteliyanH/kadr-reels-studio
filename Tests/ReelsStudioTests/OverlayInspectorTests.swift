import XCTest
import CoreMedia
import Kadr
import KadrUI
@testable import ReelsStudio

@MainActor
final class OverlayInspectorTests: XCTestCase {

    private func cmt(_ s: Double) -> CMTime { CMTime(seconds: s, preferredTimescale: 600) }

    private func makeStore(overlays: [any Overlay] = []) -> ProjectStore {
        let project = Project(overlays: overlays)
        return ProjectStore(project: project)
    }

    private func textOverlay(id: String) -> TextOverlay {
        TextOverlay("Hello", style: .default)
            .position(.center)
            .opacity(1.0)
            .id(LayerID(id))
    }

    private func imageOverlay(id: String) -> ImageOverlay {
        ImageOverlay(PlatformImage())
            .position(.center)
            .opacity(0.8)
            .id(LayerID(id))
    }

    private func stickerOverlay(id: String) -> StickerOverlay {
        StickerOverlay(PlatformImage())
            .position(.bottomRight)
            .rotation(0)
            .opacity(0.9)
            .id(LayerID(id))
    }

    // MARK: - Selection mutual exclusion

    func testSelectingOverlayClearsClipSelection() {
        let store = makeStore(overlays: [textOverlay(id: "t1")])
        store.selectedClipID = ClipID("clip-1")
        XCTAssertNotNil(store.selectedClipID)

        store.selectedOverlayID = LayerID("t1")
        XCTAssertNil(store.selectedClipID)
        XCTAssertEqual(store.selectedOverlayID, LayerID("t1"))
    }

    func testSelectingClipClearsOverlaySelection() {
        let store = makeStore(overlays: [textOverlay(id: "t1")])
        store.selectedOverlayID = LayerID("t1")
        store.selectedClipID = ClipID("clip-1")
        XCTAssertNil(store.selectedOverlayID)
    }

    // MARK: - Common-property mutations

    func testApplyOverlayPositionUpdatesField() {
        let store = makeStore(overlays: [textOverlay(id: "t1")])
        store.applyOverlayPosition(id: LayerID("t1"), .topLeft)
        let overlay = store.project.overlays.first { $0.layerID == LayerID("t1") }
        XCTAssertEqual(overlay?.position, .topLeft)
    }

    func testApplyOverlayOpacityUpdatesField() {
        let store = makeStore(overlays: [textOverlay(id: "t1")])
        store.applyOverlayOpacity(id: LayerID("t1"), 0.5)
        let overlay = store.project.overlays.first { $0.layerID == LayerID("t1") }
        XCTAssertEqual(overlay?.opacity, 0.5)
    }

    func testApplyOverlayAnchorUpdatesField() {
        let store = makeStore(overlays: [textOverlay(id: "t1")])
        store.applyOverlayAnchor(id: LayerID("t1"), .topLeft)
        let overlay = store.project.overlays.first { $0.layerID == LayerID("t1") }
        XCTAssertEqual(overlay?.anchor, .topLeft)
    }

    // MARK: - Type-specific

    func testApplyOverlayTextOnTextOverlay() {
        let store = makeStore(overlays: [textOverlay(id: "t1")])
        store.applyOverlayText(id: LayerID("t1"), "World")
        let text = store.project.overlays.first as? TextOverlay
        XCTAssertEqual(text?.text, "World")
    }

    func testApplyOverlayTextOnNonTextOverlayIsNoOp() {
        let store = makeStore(overlays: [imageOverlay(id: "i1")])
        store.applyOverlayText(id: LayerID("i1"), "should not appear")
        XCTAssertNotNil(store.project.overlays.first as? ImageOverlay)
    }

    func testApplyOverlayRotationOnSticker() {
        let store = makeStore(overlays: [stickerOverlay(id: "s1")])
        store.applyOverlayRotation(id: LayerID("s1"), .pi / 4)
        let sticker = store.project.overlays.first as? StickerOverlay
        XCTAssertEqual(sticker?.rotation ?? 0, .pi / 4, accuracy: 0.0001)
    }

    func testApplyOverlayTextAnimationFadeIn() {
        let store = makeStore(overlays: [textOverlay(id: "t1")])
        store.applyOverlayTextAnimation(id: LayerID("t1"), .fadeIn(durationSeconds: 0.5))
        let text = store.project.overlays.first as? TextOverlay
        XCTAssertNotNil(text?.textAnimation)
    }

    // MARK: - Undo / redo

    func testUndoRevertsOverlayPosition() {
        let store = makeStore(overlays: [textOverlay(id: "t1")])
        let original = (store.project.overlays.first as? TextOverlay)?.position
        store.applyOverlayPosition(id: LayerID("t1"), .topLeft)
        store.undo()
        XCTAssertEqual(store.project.overlays.first?.position, original)
    }

    func testActionNamesSurfaceForOverlayMutations() {
        let store = makeStore(overlays: [textOverlay(id: "t1")])
        store.applyOverlayPosition(id: LayerID("t1"), .topLeft)
        XCTAssertEqual(store.undoManager.undoActionName, "Edit Position")
        store.applyOverlayOpacity(id: LayerID("t1"), 0.5)
        XCTAssertEqual(store.undoManager.undoActionName, "Edit Opacity")
        store.applyOverlayText(id: LayerID("t1"), "x")
        XCTAssertEqual(store.undoManager.undoActionName, "Edit Text")
    }

    // MARK: - Overlay keyframe authoring

    func testAddOverlayKeyframeOnImageOverlayCreatesPositionAnimation() {
        let store = makeStore(overlays: [imageOverlay(id: "i1")])
        store.addOverlayKeyframe(layerID: LayerID("i1"), property: .position, time: cmt(0.5))
        let overlay = store.project.overlays.first as? ImageOverlay
        XCTAssertNotNil(overlay?.positionAnimation)
        XCTAssertEqual(overlay?.positionAnimation?.keyframes.count, 1)
    }

    func testAddOverlaySizeKeyframeOnStickerCreatesSizeAnimation() {
        let store = makeStore(overlays: [stickerOverlay(id: "s1")])
        store.addOverlayKeyframe(layerID: LayerID("s1"), property: .size, time: cmt(0.5))
        let sticker = store.project.overlays.first as? StickerOverlay
        XCTAssertNotNil(sticker?.sizeAnimation)
    }

    func testAddOverlayKeyframeOnTextOverlayIsNoOp() {
        // TextOverlay has no positionAnimation surface — kadr-ui's
        // OverlayKeyframeEditor renders zero rows for text. The mutation
        // routes through setPositionAnimation which is a passthrough for
        // unsupported types.
        let store = makeStore(overlays: [textOverlay(id: "t1")])
        store.addOverlayKeyframe(layerID: LayerID("t1"), property: .position, time: cmt(0.5))
        // The overlay is still a TextOverlay; no animation field exists to
        // verify, just that the call doesn't crash and doesn't change kind.
        XCTAssertNotNil(store.project.overlays.first as? TextOverlay)
    }

    func testRemoveOverlayKeyframeStripsLastEntry() {
        let store = makeStore(overlays: [imageOverlay(id: "i1")])
        store.addOverlayKeyframe(layerID: LayerID("i1"), property: .position, time: cmt(0.5))
        store.removeOverlayKeyframe(layerID: LayerID("i1"), property: .position, time: cmt(0.5))
        let overlay = store.project.overlays.first as? ImageOverlay
        XCTAssertNil(overlay?.positionAnimation)
    }

    func testRetimeOverlayKeyframeMovesIt() {
        let store = makeStore(overlays: [imageOverlay(id: "i1")])
        store.addOverlayKeyframe(layerID: LayerID("i1"), property: .position, time: cmt(0.5))
        store.retimeOverlayKeyframe(
            layerID: LayerID("i1"),
            property: .position,
            from: cmt(0.5),
            to: cmt(1.5)
        )
        let overlay = store.project.overlays.first as? ImageOverlay
        XCTAssertEqual(overlay?.positionAnimation?.keyframes.count, 1)
        XCTAssertEqual(
            CMTimeGetSeconds(overlay?.positionAnimation?.keyframes[0].time ?? .zero),
            1.5,
            accuracy: 0.0001
        )
    }

    func testUndoRevertsOverlayKeyframeAdd() {
        let store = makeStore(overlays: [imageOverlay(id: "i1")])
        store.addOverlayKeyframe(layerID: LayerID("i1"), property: .position, time: cmt(0.5))
        XCTAssertNotNil((store.project.overlays.first as? ImageOverlay)?.positionAnimation)
        store.undo()
        XCTAssertNil((store.project.overlays.first as? ImageOverlay)?.positionAnimation)
    }

    // MARK: - LayersSheet helpers

    func testLayersSheetIconAndKindForEachOverlayKind() {
        XCTAssertEqual(LayersSheet.iconAndKind(for: textOverlay(id: "t")).1, "Text")
        XCTAssertEqual(LayersSheet.iconAndKind(for: imageOverlay(id: "i")).1, "Image")
        XCTAssertEqual(LayersSheet.iconAndKind(for: stickerOverlay(id: "s")).1, "Sticker")
    }

    func testLayersSheetTitlePrefersTextContent() {
        let title = LayersSheet.title(for: textOverlay(id: "t1"), index: 0)
        XCTAssertEqual(title, "Hello")
    }

    func testLayersSheetTitleFallsBackToLayerID() {
        let title = LayersSheet.title(for: imageOverlay(id: "logo"), index: 2)
        XCTAssertEqual(title, "logo")
    }

    // MARK: - Body smoke

    func testOverlayInspectorAreaConstructsForSelectedOverlay() {
        let store = makeStore(overlays: [textOverlay(id: "t1")])
        store.selectedOverlayID = LayerID("t1")
        _ = OverlayInspectorArea(store: store).body
    }

    func testOverlayKeyframeAreaConstructs() {
        let store = makeStore(overlays: [imageOverlay(id: "i1")])
        store.selectedOverlayID = LayerID("i1")
        _ = OverlayKeyframeArea(store: store).body
    }

    func testLayersSheetBodyConstructsEmpty() {
        let store = makeStore()
        _ = LayersSheet(store: store).body
    }

    func testLayersSheetBodyConstructsWithOverlays() {
        let store = makeStore(overlays: [
            textOverlay(id: "t1"),
            imageOverlay(id: "i1"),
            stickerOverlay(id: "s1"),
        ])
        _ = LayersSheet(store: store).body
    }
}
