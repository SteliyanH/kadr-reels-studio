import XCTest
import SwiftUI
import Kadr
@testable import ReelsStudio

@MainActor
final class AppSettingsTests: XCTestCase {

    // Build a sandboxed UserDefaults so the test instance doesn't read or
    // write the real .standard suite (which the singleton shares with the
    // host process). Each test gets a fresh suite name to avoid bleed.
    private func freshDefaults(_ name: String = UUID().uuidString) -> UserDefaults {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    func testDefaultIntensityIsLight() {
        let settings = AppSettings(defaults: freshDefaults())
        XCTAssertEqual(settings.hapticIntensity, .light)
    }

    func testIntensityPersistsAcrossInstances() {
        let suite = UUID().uuidString
        let defaults = freshDefaults(suite)

        let first = AppSettings(defaults: defaults)
        first.hapticIntensity = .medium

        let second = AppSettings(defaults: defaults)
        XCTAssertEqual(second.hapticIntensity, .medium)
    }

    func testUnknownPersistedValueFallsBackToDefault() {
        let suite = UUID().uuidString
        let defaults = freshDefaults(suite)
        defaults.set("subsonic", forKey: "reels-studio.hapticIntensity")

        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.hapticIntensity, .light)
    }

    func testEveryIntensityHasDisplayName() {
        for intensity in HapticIntensity.allCases {
            XCTAssertFalse(intensity.displayName.isEmpty)
        }
    }
}

@MainActor
final class SettingsViewTests: XCTestCase {

    // SettingsView reads `@EnvironmentObject AppSettings`; calling `.body`
    // on `someView.environment(...)` traps because `.body` isn't
    // defined on the wrapping `ModifiedContent`, and constructing the
    // EnvironmentObject without a hosting controller is messy. The Form's
    // construction is exercised by the build / Xcode preview / manual QA;
    // here we just sanity-check `init`'s seed logic — useCustomAccent and
    // customAccent default off the project's existing accent.
    //
    // (Those two `@State` fields are private; we verify indirectly through
    // the store's accentColor staying unchanged after init, which it must
    // since init doesn't fire any mutation.)

    func testInitDoesNotMutateStore() {
        let store = ProjectStore(project: Project(accentColor: .red))
        _ = SettingsView(store: store)
        XCTAssertNotNil(store.project.accentColor)
    }

    func testInitWithNilAccentLeavesStoreUntouched() {
        let store = ProjectStore(project: Project())
        _ = SettingsView(store: store)
        XCTAssertNil(store.project.accentColor)
    }

    // MARK: - Haptics segment labels (v0.8 Tier 5a)

    /// The `Form` picker became a `ReelSegmentedControl`, whose segments
    /// are real `Button`s labelled with each intensity's display name.
    /// `ReelsStudioUITests.testEditorSettingsGearOpensSheet` proves the sheet
    /// presented by finding `app.buttons["Medium"]`, so the exact three
    /// labels — casing included — are a contract, not a detail.
    func testHapticSegmentLabelsAreTheOnesTheUITestReachesFor() {
        XCTAssertEqual(
            HapticIntensity.allCases.map(\.displayName),
            ["Off", "Light", "Medium"]
        )
    }

    /// The accent control's segments carry the ramp's own token numbers plus
    /// a localized "System" — Decision 3's constrained input.
    func testAccentChoiceLabelsCoverTheRampAndSystem() {
        XCTAssertEqual(
            SettingsView.AccentChoice.allCases.map(\.label),
            ["System", "500", "600", "700"]
        )
    }

    func testAccentChoiceSystemClearsTheColor() {
        XCTAssertNil(SettingsView.AccentChoice.system.color)
        XCTAssertNotNil(SettingsView.AccentChoice.a500.color)
    }

    // MARK: - Legacy custom accent (Decision 3)
    //
    // A project saved by v0.5–v0.7's unconstrained `ColorPicker` holds an
    // arbitrary hex. `choice(for:)` seeds the control to `.a500` so it reads
    // as "an accent is set" — but seeding deliberately writes nothing, so the
    // legacy colour is still on disk while the UI shows "500" selected.
    //
    // Under the `.onChange`-driven mutation, tapping the "500" segment that
    // was already showing changed no selection, fired no change, and wrote
    // nothing: the user tapped the value they wanted, the UI agreed with them,
    // and the off-ramp colour survived. The tap now commits.

    private func hex(_ color: Color?) -> String? {
        color.flatMap { ProjectDocument.hexString(from: PlatformColor($0)) }
    }

    func testLegacyCustomAccentSeedsOntoTheRampBaseWithoutWriting() {
        let store = ProjectStore(project: Project(accentColor: .red))
        let seeded = SettingsView.choice(for: store.project.accentColor)
        XCTAssertEqual(seeded, .a500, "A legacy hex should display as the ramp's base step.")
        XCTAssertEqual(
            hex(store.project.accentColor),
            hex(.red),
            "Seeding the control must not mutate the project."
        )
    }

    func testTappingTheAlreadyShowingSegmentCommitsOverALegacyHex() {
        let store = ProjectStore(project: Project(accentColor: .red))
        let seeded = SettingsView.choice(for: store.project.accentColor)

        // The user taps the segment the control is already showing.
        SettingsView.commit(seeded, to: store)

        XCTAssertEqual(
            hex(store.project.accentColor),
            hex(Reel.Accent.a500),
            "Tapping '500' over a legacy custom accent must write the ramp value; "
            + "otherwise the UI claims a colour the project doesn't hold."
        )
    }

    func testCommitOverALegacyHexIsUndoableLikeAnyOtherMutation() {
        let store = ProjectStore(project: Project(accentColor: .red))
        SettingsView.commit(SettingsView.choice(for: store.project.accentColor), to: store)
        XCTAssertTrue(store.canUndo)
        store.undo()
        XCTAssertEqual(hex(store.project.accentColor), hex(.red))
    }

    /// The other half of the fix: a tap that genuinely changes nothing still
    /// writes nothing, so committing on every tap doesn't fill the undo stack
    /// with no-ops.
    func testTappingASegmentThatMatchesTheStoredColorWritesNothing() {
        let store = ProjectStore(project: Project(accentColor: Reel.Accent.a500))
        SettingsView.commit(.a500, to: store)
        XCTAssertFalse(store.canUndo)
    }

    func testTappingSystemOnAProjectWithNoAccentWritesNothing() {
        let store = ProjectStore(project: Project())
        SettingsView.commit(.system, to: store)
        XCTAssertFalse(store.canUndo)
    }

    func testTappingSystemOverAStoredAccentClearsIt() {
        let store = ProjectStore(project: Project(accentColor: .red))
        SettingsView.commit(.system, to: store)
        XCTAssertNil(store.project.accentColor)
    }

    func testTappingARampStepOnAProjectWithNoAccentSetsIt() {
        let store = ProjectStore(project: Project())
        SettingsView.commit(.a700, to: store)
        XCTAssertEqual(hex(store.project.accentColor), hex(Reel.Accent.a700))
    }

    // MARK: needsCommit, directly

    func testNeedsCommitIsTrueForALegacyHexShowingAsFiveHundred() {
        XCTAssertTrue(SettingsView.needsCommit(.a500, storedColor: .red))
    }

    func testNeedsCommitIsFalseWhenTheStoredColorAlreadyMatches() {
        XCTAssertFalse(SettingsView.needsCommit(.a500, storedColor: Reel.Accent.a500))
        XCTAssertFalse(SettingsView.needsCommit(.system, storedColor: nil))
    }

    func testNeedsCommitIsTrueWhenOneSideClearsAndTheOtherSets() {
        XCTAssertTrue(SettingsView.needsCommit(.system, storedColor: Reel.Accent.a500))
        XCTAssertTrue(SettingsView.needsCommit(.a600, storedColor: nil))
    }

    func testNeedsCommitDistinguishesAdjacentRampSteps() {
        XCTAssertTrue(SettingsView.needsCommit(.a600, storedColor: Reel.Accent.a500))
        XCTAssertTrue(SettingsView.needsCommit(.a700, storedColor: Reel.Accent.a600))
    }
}

@MainActor
final class ProjectStoreSettingsMutationsTests: XCTestCase {

    func testSetAccentColorRoutesThroughApplyMutationAndUndoes() {
        let store = ProjectStore(project: Project())
        XCTAssertNil(store.project.accentColor)
        store.setAccentColor(.red)
        XCTAssertNotNil(store.project.accentColor)
        XCTAssertTrue(store.canUndo)
        store.undo()
        XCTAssertNil(store.project.accentColor)
    }

    func testSetFixedCenterPlayheadDoesNotPushUndo() {
        // Viewport state — same shape as `updateZoom`. The flag round-trips
        // through persistence but shouldn't flood the undo stack.
        let store = ProjectStore(project: Project(fixedCenterPlayhead: true))
        store.setFixedCenterPlayhead(false)
        XCTAssertFalse(store.project.fixedCenterPlayhead)
        XCTAssertFalse(store.canUndo)
    }
}
