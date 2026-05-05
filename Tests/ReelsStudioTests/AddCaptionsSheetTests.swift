import XCTest
import CoreMedia
import Kadr
@testable import ReelsStudio

@MainActor
final class AddCaptionsSheetTests: XCTestCase {

    private func cmt(_ s: Double) -> CMTime { CMTime(seconds: s, preferredTimescale: 600) }

    private func makeStore(captions: [Caption] = []) -> ProjectStore {
        let project = Project(captions: captions)
        return ProjectStore(project: project)
    }

    private func cue(_ start: Double, _ end: Double, _ text: String) -> Caption {
        Caption(
            text: text,
            timeRange: CMTimeRange(start: cmt(start), duration: cmt(end - start))
        )
    }

    // MARK: - setCaptions mutation

    func testSetCaptionsReplacesExistingArray() {
        let store = makeStore(captions: [cue(0, 1, "old")])
        store.setCaptions([cue(2, 3, "new-1"), cue(4, 5, "new-2")])
        XCTAssertEqual(store.project.captions.map(\.text), ["new-1", "new-2"])
    }

    func testSetCaptionsActionNameSurfaces() {
        let store = makeStore()
        store.setCaptions([cue(0, 1, "x")])
        XCTAssertEqual(store.undoManager.undoActionName, "Edit Captions")
    }

    // MARK: - Undo / redo

    func testUndoRevertsSetCaptions() {
        let store = makeStore(captions: [cue(0, 1, "original")])
        store.setCaptions([cue(2, 3, "replaced")])
        XCTAssertEqual(store.project.captions.first?.text, "replaced")
        store.undo()
        XCTAssertEqual(store.project.captions.first?.text, "original")
    }

    func testRedoReappliesSetCaptions() {
        let store = makeStore(captions: [cue(0, 1, "original")])
        store.setCaptions([cue(2, 3, "replaced")])
        store.undo()
        store.redo()
        XCTAssertEqual(store.project.captions.first?.text, "replaced")
    }

    func testSetCaptionsToEmptyClearsList() {
        let store = makeStore(captions: [cue(0, 1, "a"), cue(2, 3, "b")])
        store.setCaptions([])
        XCTAssertTrue(store.project.captions.isEmpty)
        store.undo()
        XCTAssertEqual(store.project.captions.count, 2)
    }

    // MARK: - Persistence round-trip

    func testCaptionListSurvivesDocumentBridge() {
        let store = makeStore()
        let cues = [cue(0.5, 1.5, "Hello"), cue(2.5, 4.0, "World")]
        store.setCaptions(cues)

        let document = store.project.toDocument(name: "Captions")
        let restored = document.toRuntimeProject()
        XCTAssertEqual(restored.captions.count, 2)
        XCTAssertEqual(restored.captions[0].text, "Hello")
        XCTAssertEqual(restored.captions[1].text, "World")
    }

    // MARK: - Body smoke

    func testSheetBodyConstructsWithEmptyCaptions() {
        let store = makeStore()
        let sheet = AddCaptionsSheet(store: store)
        _ = sheet.body
    }

    func testSheetBodyConstructsWithExistingCaptions() {
        let store = makeStore(captions: [cue(0, 1, "Hi")])
        let sheet = AddCaptionsSheet(store: store)
        _ = sheet.body
    }
}
