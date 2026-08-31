import XCTest
import CoreMedia
import Kadr
import KadrUI
import KadrPersistence
@testable import ReelsStudio

/// Saving a project whose text overlay has an entrance animation.
///
/// v0.12.0 shipped a regression here: `toDocument` encodes strictly, and
/// kadr-persistence reported *every* `TextAnimation` as unsaveable — so adding
/// a fade from the animation picker made autosave throw, and the project
/// silently stopped saving from that point on. Fixed upstream in
/// kadr-persistence 0.4.0, which encodes the three animations kadr ships.
///
/// These run through `ProjectStore.applyOverlayTextAnimation`, the mutation the
/// picker actually calls, rather than constructing an animation by hand — the
/// bug was in the path from picker to disk, so that is the path under test.
@MainActor
final class AnimatedOverlaySaveTests: XCTestCase {

    private func storeWithAnimatedOverlay(_ kind: OverlayTextAnimationKind) -> ProjectStore {
        let store = ProjectStore(project: Project(
            clips: [TitleSequence("clip", duration: 2.0)],
            overlays: [TextOverlay("Hello").id(LayerID("t"))]
        ))
        store.applyOverlayTextAnimation(id: LayerID("t"), kind)
        return store
    }

    /// Every kind the picker can emit. Listed by hand because the enum carries
    /// associated values and so cannot be `CaseIterable` — `.custom` is
    /// included deliberately: it stands for a consumer-built animation, which
    /// is exactly the case that must stay reported rather than crash a save.
    private static let pickerKinds: [OverlayTextAnimationKind] = [
        .none,
        .fadeIn(durationSeconds: 0.5),
        .slideIn(direction: .fromLeft, durationSeconds: 0.6),
        .slideIn(direction: .fromRight, durationSeconds: 0.6),
        .slideIn(direction: .fromTop, durationSeconds: 0.6),
        .slideIn(direction: .fromBottom, durationSeconds: 0.6),
        .scaleUp(durationSeconds: 0.4),
    ]

    func testEveryAnimationKindThePickerOffersCanBeSaved() throws {
        for kind in Self.pickerKinds {
            let store = storeWithAnimatedOverlay(kind)
            XCTAssertNoThrow(
                try store.project.toDocument(name: "Animated", images: store.images),
                "saving failed for \(kind) — autosave would throw and stop persisting edits"
            )
        }
    }

    func testTheAnimationSurvivesASaveAndReopen() throws {
        let store = storeWithAnimatedOverlay(.fadeIn(durationSeconds: 0.5))
        let document = try store.project.toDocument(name: "Animated", images: store.images)
        let reopened = try document.toRuntimeProject(images: store.images)
        let overlay = try XCTUnwrap(reopened.overlays.first as? TextOverlay)
        XCTAssertNotNil(overlay.textAnimation, "the animation was dropped across the round trip")
        XCTAssertTrue(overlay.textAnimation is FadeIn)
    }

    func testClearingTheAnimationStillSaves() throws {
        let store = storeWithAnimatedOverlay(.fadeIn(durationSeconds: 0.5))
        store.applyOverlayTextAnimation(id: LayerID("t"), .none)
        let document = try store.project.toDocument(name: "Plain", images: store.images)
        let reopened = try document.toRuntimeProject(images: store.images)
        XCTAssertNil((reopened.overlays.first as? TextOverlay)?.textAnimation)
    }

    func testNothingTheEditorCanAuthorIsReportedAsUnsaveable() throws {
        // The general form of the bug: a composition the app can build must
        // never be one the format refuses. This asserts the claim directly
        // instead of assuming it, which is how the regression got in.
        let store = storeWithAnimatedOverlay(.slideIn(direction: .fromTop, durationSeconds: 0.6))
        XCTAssertTrue(
            KadrCoding.lossyContent(in: store.project.makeVideo(), images: store.images).isEmpty,
            "the editor can author something the document format refuses to save"
        )
    }
}
