import XCTest
import Kadr
@testable import ReelsStudio

@MainActor
final class OverlayTapToSelectTests: XCTestCase {

    // The `.onLayerTap` callback in PreviewArea is wired against
    // kadr-ui's OverlayHost gesture; we can't synthesize the tap from
    // a unit test. What we can lock down is the selection-slot contract
    // that callback writes into — same path the LayersSheet uses, same
    // mutual exclusion against selectedClipID, same observability.

    func testWritingOverlayIDLandsInSelectionSlot() {
        let store = ProjectStore(project: Project())
        store.append(overlay: TextOverlay("hi").id(LayerID("o1")))
        store.selectedOverlayID = LayerID("o1")
        XCTAssertEqual(store.selectedOverlayID, LayerID("o1"))
    }

    /// Tapping an overlay while a clip is selected clears the clip
    /// selection (didSet observer from v0.3 Tier 4). The tap callback
    /// is the same write path as `LayersSheet` row-tap, so this
    /// regression-guards the v0.4 Tier 6 wiring.
    func testTappingOverlayClearsClipSelection() {
        let store = ProjectStore(project: Project())
        store.append(clip: ImageClip(PlatformImage()).id(ClipID("c1")))
        store.append(overlay: TextOverlay("hi").id(LayerID("o1")))
        store.selectedClipID = ClipID("c1")
        store.selectedOverlayID = LayerID("o1")
        XCTAssertNil(store.selectedClipID)
        XCTAssertEqual(store.selectedOverlayID, LayerID("o1"))
    }

    func testPreviewAreaBodyConstructs() {
        let store = ProjectStore(project: Project())
        store.append(overlay: TextOverlay("hi").id(LayerID("o1")))
        let area = PreviewArea(store: store)
        _ = area.body
    }
}
