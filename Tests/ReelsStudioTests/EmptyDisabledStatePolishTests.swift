import XCTest
import Kadr
@testable import ReelsStudio

@MainActor
final class ExportTooltipTests: XCTestCase {

    func testTooltipExplainsWhyButtonIsDisabled() {
        let disabledCopy = EditorToolbar.exportTooltip(hasClips: false)
        XCTAssertTrue(disabledCopy.lowercased().contains("add a clip"))
    }

    func testTooltipDescribesActionWhenEnabled() {
        let enabledCopy = EditorToolbar.exportTooltip(hasClips: true)
        XCTAssertTrue(enabledCopy.lowercased().contains("export"))
        XCTAssertFalse(enabledCopy.lowercased().contains("add a clip"))
    }

    /// The empty-vs-populated branch surfaces different copy so VoiceOver
    /// users don't hear the same tooltip in both states.
    func testDisabledAndEnabledCopyDiffer() {
        XCTAssertNotEqual(
            EditorToolbar.exportTooltip(hasClips: false),
            EditorToolbar.exportTooltip(hasClips: true)
        )
    }
}

@MainActor
final class ExportDisabledStateTests: XCTestCase {

    // The Export button's disabled state is derived inline from
    // `store.project.clips.isEmpty`; these tests pin the derivation by
    // verifying the underlying property the toolbar reads from.

    func testEmptyProjectClipsArrayDrivesDisabledState() {
        let store = ProjectStore(project: Project())
        XCTAssertTrue(store.project.clips.isEmpty)
    }

    func testNonEmptyProjectEnablesExport() {
        let store = ProjectStore(project: Project())
        store.append(clip: ImageClip(PlatformImage(), duration: 2.0).id(ClipID("c1")))
        XCTAssertFalse(store.project.clips.isEmpty)
    }
}
