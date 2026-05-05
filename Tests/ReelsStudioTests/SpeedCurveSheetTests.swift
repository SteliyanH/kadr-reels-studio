import XCTest
import CoreMedia
import Kadr
@testable import ReelsStudio

@MainActor
final class SpeedCurveSheetTests: XCTestCase {

    private func cmt(_ s: Double) -> CMTime { CMTime(seconds: s, preferredTimescale: 600) }

    private func makeStoreWithVideoClip() -> (ProjectStore, ClipID) {
        let store = ProjectStore(project: Project())
        let clip = VideoClip(url: URL(fileURLWithPath: "/tmp/test.mp4"))
            .trimmed(to: 0...4)
            .id(ClipID("vid-1"))
        store.append(clip: clip)
        return (store, ClipID("vid-1"))
    }

    private func makeCurve() -> Kadr.Animation<Double> {
        .keyframes([
            .at(0.0, value: 1.0),
            .at(2.0, value: 0.5),
            .at(4.0, value: 1.0),
        ])
    }

    // MARK: - Mutation behavior

    func testApplySpeedCurveSetsCurveOnVideoClip() {
        let (store, id) = makeStoreWithVideoClip()
        store.applySpeedCurve(id: id, makeCurve())
        guard let video = store.project.clips.first as? VideoClip else {
            return XCTFail("Expected VideoClip")
        }
        XCTAssertEqual(video.speedCurve?.keyframes.count, 3)
    }

    func testApplySpeedCurveNilClearsCurve() {
        let (store, id) = makeStoreWithVideoClip()
        store.applySpeedCurve(id: id, makeCurve())
        store.applySpeedCurve(id: id, nil)
        guard let video = store.project.clips.first as? VideoClip else {
            return XCTFail("Expected VideoClip")
        }
        XCTAssertNil(video.speedCurve)
    }

    func testApplySpeedCurveOnNonVideoClipIsNoOp() {
        let store = ProjectStore(project: Project())
        let img = ImageClip(PlatformImage(), duration: 1.0).id(ClipID("img-1"))
        store.append(clip: img)
        store.applySpeedCurve(id: ClipID("img-1"), makeCurve())
        // ImageClip doesn't have speedCurve — clip stays an ImageClip, the
        // mutation is silently rejected (the `updateClip` closure returns
        // the clip unchanged).
        XCTAssertNotNil(store.project.clips.first as? ImageClip)
    }

    func testApplySpeedCurveActionNameSurfaces() {
        let (store, id) = makeStoreWithVideoClip()
        store.applySpeedCurve(id: id, makeCurve())
        XCTAssertEqual(store.undoManager.undoActionName, "Speed Curve")
    }

    // MARK: - Undo / redo

    func testUndoRevertsSpeedCurve() {
        let (store, id) = makeStoreWithVideoClip()
        store.applySpeedCurve(id: id, makeCurve())
        XCTAssertNotNil((store.project.clips.first as? VideoClip)?.speedCurve)
        store.undo()
        XCTAssertNil((store.project.clips.first as? VideoClip)?.speedCurve)
    }

    func testRedoReappliesSpeedCurve() {
        let (store, id) = makeStoreWithVideoClip()
        store.applySpeedCurve(id: id, makeCurve())
        store.undo()
        store.redo()
        XCTAssertNotNil((store.project.clips.first as? VideoClip)?.speedCurve)
    }

    // MARK: - Persistence round-trip

    func testSpeedCurveSurvivesRuntimeBridge() {
        let (store, id) = makeStoreWithVideoClip()
        store.applySpeedCurve(id: id, makeCurve())

        // Round-trip the runtime project through the document bridge.
        let document = store.project.toDocument(name: "Sheet")
        let restored = document.toRuntimeProject()
        guard let restoredVideo = restored.clips.first as? VideoClip else {
            return XCTFail("Expected VideoClip after round-trip")
        }
        XCTAssertEqual(restoredVideo.clipID, id)
        XCTAssertEqual(restoredVideo.speedCurve?.keyframes.count, 3)
    }

    // MARK: - SpeedCurveSheet body smoke

    func testSheetBodyConstructsForExistingClip() {
        let (store, id) = makeStoreWithVideoClip()
        let sheet = SpeedCurveSheet(store: store, clipID: id)
        _ = sheet.body
    }

    func testSheetBodyConstructsForMissingClip() {
        let store = ProjectStore(project: Project())
        let sheet = SpeedCurveSheet(store: store, clipID: ClipID("missing"))
        _ = sheet.body
    }
}
