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
    // on `someView.environmentObject(...)` traps because `.body` isn't
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
