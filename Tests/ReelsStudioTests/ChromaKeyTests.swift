import XCTest
import Kadr
@testable import ReelsStudio

/// v0.7 Tier 4 — tests for `ProjectStore.addChromaKey`. The sheet itself is
/// state + a `ColorPicker` + a `Slider`; nothing testable without driving
/// SwiftUI's gesture surface. Mutation correctness is the load-bearing
/// part — pin it.
@MainActor
final class ChromaKeyTests: XCTestCase {

    private func makeVideoClip(id: ClipID) -> VideoClip {
        VideoClip(url: URL(fileURLWithPath: "/dev/null"))
            .trimmed(to: 0...5)
            .id(id)
    }

    func testAddChromaKeyAppendsAChromaKeyFilter() {
        let project = Project(clips: [makeVideoClip(id: "clip-a")])
        let store = ProjectStore(project: project)
        store.addChromaKey(id: "clip-a", color: .green, threshold: 0.5)

        guard let clip = store.project.clips.first as? VideoClip else {
            return XCTFail("Expected video clip")
        }
        XCTAssertEqual(clip.filters.count, 1)
        guard case .chromaKey = clip.filters[0] else {
            return XCTFail("Expected chroma key filter, got \(clip.filters[0])")
        }
    }

    func testAddChromaKeyIsUndoable() {
        let project = Project(clips: [makeVideoClip(id: "clip-a")])
        let store = ProjectStore(project: project)
        store.addChromaKey(id: "clip-a", color: .green, threshold: 0.5)
        XCTAssertEqual((store.project.clips.first as? VideoClip)?.filters.count, 1)

        XCTAssertTrue(store.canUndo)
        store.undo()
        XCTAssertEqual((store.project.clips.first as? VideoClip)?.filters.count, 0)
    }

    /// `addChromaKey` shares the "Add Filter" action name with every other
    /// filter add. The Edit menu reads "Undo Add Filter" regardless of
    /// which kind landed — keeps the menu legible.
    func testAddChromaKeyUsesAddFilterActionName() {
        // We can't read undo action names from XCTest without UIKit, but
        // by adding two filters back-to-back (one scalar + one chroma key)
        // and undoing twice, we should land back at the empty stack —
        // proving each add registered as its own undo step under any name.
        let project = Project(clips: [makeVideoClip(id: "clip-a")])
        let store = ProjectStore(project: project)
        store.addFilter(id: "clip-a", .brightness(0.2))
        store.addChromaKey(id: "clip-a", color: .green, threshold: 0.5)
        XCTAssertEqual((store.project.clips.first as? VideoClip)?.filters.count, 2)

        store.undo()
        store.undo()
        XCTAssertEqual((store.project.clips.first as? VideoClip)?.filters.count, 0)
    }

    func testAddChromaKeyNoOpForNonVideoClip() {
        // Chroma key applies to VideoClip's filter stack only. Adding to a
        // TitleSequence's clip id is a silent no-op (matches the existing
        // addFilter behavior).
        let title = TitleSequence("hi", duration: .init(seconds: 1, preferredTimescale: 600)).id("title-1")
        let project = Project(clips: [title])
        let store = ProjectStore(project: project)
        store.addChromaKey(id: "title-1", color: .green, threshold: 0.5)
        // No crash, no mutation on the title clip — the project's clip count
        // stays at 1 and the title clip remains a TitleSequence.
        XCTAssertTrue(store.project.clips.first is TitleSequence)
    }
}
