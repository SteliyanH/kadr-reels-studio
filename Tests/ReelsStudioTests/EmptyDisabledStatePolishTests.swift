import XCTest
import Kadr
import KadrPersistence
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

    // MARK: - Render-card spec line (v0.8 Tier 5a)

    func testTimecodeFormatsMinutesAndSeconds() {
        XCTAssertEqual(ExportSheet.timecode(6), "0:06")
        XCTAssertEqual(ExportSheet.timecode(65), "1:05")
        XCTAssertEqual(ExportSheet.timecode(600), "10:00")
    }

    func testTimecodeClampsNonsenseInput() {
        // `CMTimeGetSeconds` returns NaN for an indefinite duration; the
        // render card must not print "nan:aN".
        XCTAssertEqual(ExportSheet.timecode(.nan), "0:00")
        XCTAssertEqual(ExportSheet.timecode(-1), "0:00")
    }

    // MARK: - Preset aspect glyphs

    /// The glyph is a rectangle drawn at the format's real proportion, so
    /// the ratios themselves are the thing worth pinning.
    func testPresetAspectsMatchTheirSpecStrings() {
        XCTAssertEqual(ExportSheet.ExportPreset.reelsAndShorts.aspect, CGSize(width: 9, height: 16))
        XCTAssertEqual(ExportSheet.ExportPreset.tiktok.aspect, CGSize(width: 9, height: 16))
        XCTAssertEqual(ExportSheet.ExportPreset.square.aspect, CGSize(width: 1, height: 1))
        XCTAssertEqual(ExportSheet.ExportPreset.cinema.aspect, CGSize(width: 16, height: 9))
    }

    func testEveryPresetOffersALabelAndSpec() {
        for preset in ExportSheet.ExportPreset.allCases {
            XCTAssertFalse(preset.label.isEmpty)
            XCTAssertFalse(preset.detail.isEmpty)
        }
    }
}
