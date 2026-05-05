import XCTest
import Kadr
@testable import ReelsStudio

@MainActor
final class AddOverlaySheetTests: XCTestCase {

    // MARK: - Body smoke per tab

    func testSheetBodyConstructs() {
        let store = ProjectStore(project: Project())
        let sheet = AddOverlaySheet(store: store)
        _ = sheet.body
    }

    // MARK: - Text overlay append routes through the store

    func testAppendTextOverlayLandsInProject() {
        let store = ProjectStore(project: Project())
        let style = TextStyle(
            fontSize: 56,
            color: .white,
            alignment: .center,
            weight: .bold
        )
        let overlay = TextOverlay("Hello", style: style)
            .position(.center)
            .anchor(.center)
        store.append(overlay: overlay)
        XCTAssertEqual(store.project.overlays.count, 1)
        XCTAssertNotNil(store.project.overlays.first as? TextOverlay)
    }

    // MARK: - ImageOverlay round-trips through Project

    func testAppendImageOverlay() {
        let store = ProjectStore(project: Project())
        let overlay = ImageOverlay(PlatformImage())
            .position(.center)
            .anchor(.center)
            .opacity(0.8)
            .id(LayerID("img-1"))
        store.append(overlay: overlay)
        XCTAssertNotNil(store.project.overlays.first as? ImageOverlay)
        XCTAssertEqual(store.project.overlays.first?.layerID, LayerID("img-1"))
        XCTAssertEqual(store.project.overlays.first?.opacity, 0.8)
    }

    func testAppendStickerOverlay() {
        let store = ProjectStore(project: Project())
        let overlay = StickerOverlay(PlatformImage())
            .position(.center)
            .anchor(.center)
            .opacity(0.9)
            .id(LayerID("sticker-1"))
        store.append(overlay: overlay)
        XCTAssertNotNil(store.project.overlays.first as? StickerOverlay)
    }

    // MARK: - Undo / redo

    func testUndoRevertsOverlayAppend() {
        let store = ProjectStore(project: Project())
        let overlay = StickerOverlay(PlatformImage()).id(LayerID("s1"))
        store.append(overlay: overlay)
        XCTAssertEqual(store.project.overlays.count, 1)
        store.undo()
        XCTAssertEqual(store.project.overlays.count, 0)
    }
}
