import XCTest
import CoreMedia
import Kadr
import KadrUI
@testable import ReelsStudio

@MainActor
final class KeyframeAuthoringTests: XCTestCase {

    // MARK: - Pure animation transforms

    private func cmt(_ s: Double) -> CMTime {
        CMTime(seconds: s, preferredTimescale: 600)
    }

    func testUpsertOnEmptyAnimationProducesSingleKeyframe() {
        let result = ProjectStore.upsertKeyframe(
            nil as Kadr.Animation<Double>?,
            time: cmt(1.0),
            value: 0.5
        )
        XCTAssertEqual(result.keyframes.count, 1)
        XCTAssertEqual(result.keyframes[0].value, 0.5)
        XCTAssertEqual(CMTimeGetSeconds(result.keyframes[0].time), 1.0, accuracy: 0.0001)
    }

    func testUpsertReplacesKeyframeAtSameTime() {
        let initial: Kadr.Animation<Double> = .keyframes([
            .at(0.0, value: 0.0),
            .at(1.0, value: 0.5),
        ])
        let result = ProjectStore.upsertKeyframe(initial, time: cmt(1.0), value: 0.9)
        XCTAssertEqual(result.keyframes.count, 2)
        XCTAssertEqual(result.keyframes.first(where: { CMTimeGetSeconds($0.time) == 1.0 })?.value, 0.9)
    }

    func testUpsertAppendsAtNewTime() {
        let initial: Kadr.Animation<Double> = .keyframes([.at(0.0, value: 0.0)])
        let result = ProjectStore.upsertKeyframe(initial, time: cmt(2.0), value: 1.0)
        XCTAssertEqual(result.keyframes.count, 2)
    }

    func testRemovingDropsMatch() {
        let initial: Kadr.Animation<Double> = .keyframes([
            .at(0.0, value: 0.0),
            .at(1.0, value: 0.5),
        ])
        let result = ProjectStore.removingKeyframe(initial, at: cmt(1.0))
        XCTAssertEqual(result?.keyframes.count, 1)
    }

    func testRemovingLastKeyframeReturnsNil() {
        let initial: Kadr.Animation<Double> = .keyframes([.at(0.0, value: 0.0)])
        let result = ProjectStore.removingKeyframe(initial, at: cmt(0.0))
        XCTAssertNil(result)
    }

    func testRetimingMovesKeyframe() {
        let initial: Kadr.Animation<Double> = .keyframes([
            .at(0.0, value: 0.0),
            .at(1.0, value: 0.5),
        ])
        let result = ProjectStore.retimingKeyframe(initial, from: cmt(1.0), to: cmt(2.5))
        XCTAssertEqual(result?.keyframes.count, 2)
        XCTAssertNotNil(result?.keyframes.first(where: { CMTimeGetSeconds($0.time) == 2.5 }))
        XCTAssertNil(result?.keyframes.first(where: { CMTimeGetSeconds($0.time) == 1.0 }))
    }

    func testRetimingDropsCollidingKeyframe() {
        let initial: Kadr.Animation<Double> = .keyframes([
            .at(0.0, value: 0.0),
            .at(1.0, value: 0.5),
            .at(2.0, value: 1.0),
        ])
        // Move 0.0 onto 1.0 — the existing 1.0 keyframe drops, the moved
        // one wins.
        let result = ProjectStore.retimingKeyframe(initial, from: cmt(0.0), to: cmt(1.0))
        XCTAssertEqual(result?.keyframes.count, 2)
        XCTAssertEqual(result?.keyframes.first(where: { CMTimeGetSeconds($0.time) == 1.0 })?.value, 0.0)
    }

    // MARK: - Live store mutations

    private func makeStoreWithImageClip() -> (ProjectStore, ClipID) {
        let store = ProjectStore(project: Project())
        let clip = ImageClip(PlatformImage(), duration: 2.0).id(ClipID("img-1"))
        store.append(clip: clip)
        return (store, ClipID("img-1"))
    }

    func testAddKeyframeForOpacityCreatesAnimation() {
        let (store, id) = makeStoreWithImageClip()
        store.addKeyframe(clipID: id, property: .opacity, time: cmt(0.5))
        guard let image = store.project.clips.first as? ImageClip else {
            return XCTFail("Expected ImageClip")
        }
        XCTAssertNotNil(image.opacityAnimation)
        XCTAssertEqual(image.opacityAnimation?.keyframes.count, 1)
    }

    func testAddTransformKeyframeUsesIdentityWhenNoneSet() {
        let (store, id) = makeStoreWithImageClip()
        store.addKeyframe(clipID: id, property: .transform, time: cmt(0.0))
        guard let image = store.project.clips.first as? ImageClip,
              let animation = image.transformAnimation else {
            return XCTFail("Expected transformAnimation")
        }
        XCTAssertEqual(animation.keyframes.count, 1)
        XCTAssertEqual(animation.keyframes[0].value.scale, Transform.identity.scale)
    }

    func testRemoveKeyframeStripsLastEntryAndAnimationField() {
        let (store, id) = makeStoreWithImageClip()
        store.addKeyframe(clipID: id, property: .opacity, time: cmt(0.5))
        store.removeKeyframe(clipID: id, property: .opacity, time: cmt(0.5))
        guard let image = store.project.clips.first as? ImageClip else {
            return XCTFail("Expected ImageClip")
        }
        XCTAssertNil(image.opacityAnimation)
    }

    func testRetimeKeyframeMovesIt() {
        let (store, id) = makeStoreWithImageClip()
        store.addKeyframe(clipID: id, property: .opacity, time: cmt(0.5))
        store.retimeKeyframe(clipID: id, property: .opacity, from: cmt(0.5), to: cmt(1.5))
        guard let image = store.project.clips.first as? ImageClip,
              let animation = image.opacityAnimation else {
            return XCTFail("Expected opacityAnimation")
        }
        XCTAssertEqual(animation.keyframes.count, 1)
        XCTAssertEqual(CMTimeGetSeconds(animation.keyframes[0].time), 1.5, accuracy: 0.0001)
    }

    // MARK: - Undo / redo of keyframe operations

    func testUndoRevertsAddKeyframe() {
        let (store, id) = makeStoreWithImageClip()
        XCTAssertTrue(store.canUndo)  // append already there
        store.addKeyframe(clipID: id, property: .opacity, time: cmt(0.5))
        XCTAssertNotNil((store.project.clips.first as? ImageClip)?.opacityAnimation)
        store.undo()
        XCTAssertNil((store.project.clips.first as? ImageClip)?.opacityAnimation)
    }

    func testRedoReappliesAddKeyframe() {
        let (store, id) = makeStoreWithImageClip()
        store.addKeyframe(clipID: id, property: .opacity, time: cmt(0.5))
        store.undo()
        store.redo()
        XCTAssertNotNil((store.project.clips.first as? ImageClip)?.opacityAnimation)
    }

    func testKeyframeMutationActionNamesSurfaceToMenu() {
        let (store, id) = makeStoreWithImageClip()
        store.addKeyframe(clipID: id, property: .transform, time: cmt(0.0))
        XCTAssertEqual(store.undoManager.undoActionName, "Add Keyframe")
        store.removeKeyframe(clipID: id, property: .transform, time: cmt(0.0))
        XCTAssertEqual(store.undoManager.undoActionName, "Remove Keyframe")
        store.addKeyframe(clipID: id, property: .transform, time: cmt(0.0))
        store.retimeKeyframe(clipID: id, property: .transform, from: cmt(0.0), to: cmt(1.0))
        XCTAssertEqual(store.undoManager.undoActionName, "Move Keyframe")
    }

    // MARK: - Filter scalar lookup

    func testScalarOfFilterReturnsValueForScalarFilters() {
        XCTAssertEqual(ProjectStore.scalar(of: .brightness(0.3)), 0.3)
        XCTAssertEqual(ProjectStore.scalar(of: .gaussianBlur(radius: 8)), 8)
    }

    func testScalarOfMonoOrLutReturnsNil() {
        XCTAssertNil(ProjectStore.scalar(of: .mono))
    }
}
