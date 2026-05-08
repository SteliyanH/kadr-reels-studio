import XCTest
import Kadr
@testable import ReelsStudio

@MainActor
final class InspectorPresentationKeyTests: XCTestCase {

    // The key drives `.animation(value:)` for the inspector reveal — when it
    // changes the spring fires; when it doesn't, the inspector is stable.
    // These tests pin the rule down so a future refactor can't silently
    // break the reveal animation.

    func testNoSelectionGivesNoneKey() {
        XCTAssertEqual(EditorView.inspectorPresentationKey(clip: nil, overlay: nil), "none")
    }

    func testClipSelectionEmitsClipKey() {
        let key = EditorView.inspectorPresentationKey(clip: ClipID("c1"), overlay: nil)
        XCTAssertEqual(key, "clip:c1")
    }

    func testOverlaySelectionEmitsOverlayKey() {
        let key = EditorView.inspectorPresentationKey(clip: nil, overlay: LayerID("o1"))
        XCTAssertEqual(key, "overlay:o1")
    }

    /// Mutual exclusion: when both slots happen to be set (impossible in
    /// production thanks to ProjectStore's didSet, but the helper has to
    /// pick one), overlay wins. Matches the body's `if/else if` order.
    func testOverlayWinsWhenBothSet() {
        let key = EditorView.inspectorPresentationKey(
            clip: ClipID("c1"),
            overlay: LayerID("o1")
        )
        XCTAssertEqual(key, "overlay:o1")
    }

    func testClipChangeYieldsDifferentKey() {
        let a = EditorView.inspectorPresentationKey(clip: ClipID("c1"), overlay: nil)
        let b = EditorView.inspectorPresentationKey(clip: ClipID("c2"), overlay: nil)
        XCTAssertNotEqual(a, b)
    }

    func testOverlayToClipSwitchYieldsDifferentKey() {
        let a = EditorView.inspectorPresentationKey(clip: nil, overlay: LayerID("o1"))
        let b = EditorView.inspectorPresentationKey(clip: ClipID("c1"), overlay: nil)
        XCTAssertNotEqual(a, b)
    }
}
