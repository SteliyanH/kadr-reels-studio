import XCTest

/// v0.6 Tier 6 — XCUITest integration suite covering critical user-facing
/// flows that the unit tests don't exercise: cold launch → empty state, new
/// project creation, sample import, swipe-to-delete, editor settings gear.
///
/// Each test passes `--ui-test-reset` so `ReelsStudioApp` wipes the projects
/// directory before the library is built — every flow starts from an empty
/// library independent of previous runs and stray simulator state.
///
/// Tests that depend on the Photos picker are deliberately omitted: the
/// system picker isn't reliably automatable, and `PhotosAuthorizationGate`'s
/// `.notDetermined` branch would hang the simulator the same way it hung
/// CI in PR #48.
final class ReelsStudioUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-test-reset"]
    }

    // MARK: - Launch / empty state

    func testColdLaunchShowsEmptyState() {
        app.launch()
        // Empty-state copy from `ProjectListView.emptyState` — stable since
        // v0.2. Renders as a single static text the first frame.
        XCTAssertTrue(
            app.staticTexts["No projects yet"].waitForExistence(timeout: 5),
            "Expected empty-state title on cold launch with reset library"
        )
    }

    // MARK: - New project flow

    func testTappingNewProjectOpensEditor() {
        app.launch()
        // Two "New Project" buttons live on screen during empty state: the
        // toolbar `+` and the empty-state prominent button. Either tap will
        // do; the toolbar one is reachable across populated state too so
        // future tests can re-use the same hit point.
        let newProjectButton = app.buttons["New Project"].firstMatch
        XCTAssertTrue(newProjectButton.waitForExistence(timeout: 5))
        newProjectButton.tap()

        // EditorView's top toolbar carries the Settings gear from v0.5 — its
        // accessibilityLabel is "Settings" and it survives across editor
        // mode changes (clip / overlay selection), making it the most stable
        // editor-presence assertion.
        XCTAssertTrue(
            app.buttons["Settings"].waitForExistence(timeout: 5),
            "Tapping New Project should push the editor onto the nav stack"
        )
    }

    // MARK: - Sample import

    func testSampleButtonImportsAndOpensEditor() {
        app.launch()
        let sampleButton = app.buttons["Sample"]
        XCTAssertTrue(sampleButton.waitForExistence(timeout: 5))
        sampleButton.tap()

        XCTAssertTrue(
            app.buttons["Settings"].waitForExistence(timeout: 5),
            "Sample import should push the editor"
        )
    }

    // MARK: - Editor settings gear

    func testEditorSettingsGearOpensSheet() {
        app.launch()
        // Wait for the launch to settle before tapping — tapping immediately
        // races the cold-launch render and the tap can miss (matches the
        // pattern in testTappingNewProjectOpensEditor).
        let newProject = app.buttons["New Project"].firstMatch
        XCTAssertTrue(newProject.waitForExistence(timeout: 5))
        newProject.tap()
        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()

        // Assert on the Haptics section's "Medium" option button rather than the
        // section header text: `Form` section headers are exposed with OS-dependent
        // casing (title-case "Haptics" on some runtimes, uppercased "HAPTICS" on
        // others), so a header-text match is brittle across SDKs. Button labels keep
        // their case, and "Medium" is unique to the Haptics section — a stable proof
        // the Settings sheet presented.
        XCTAssertTrue(
            app.buttons["Medium"].waitForExistence(timeout: 5),
            "Tapping the gear should present the Settings sheet"
        )
    }

    // MARK: - Back to library

    func testBackNavigationReturnsToProjectList() {
        app.launch()
        let newProject = app.buttons["New Project"].firstMatch
        XCTAssertTrue(newProject.waitForExistence(timeout: 5))
        newProject.tap()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5))

        // v0.8 Tier 5b — the editor draws its own nav band (the system bar
        // can't carry the two-line title block or the ruled undo/redo cell
        // group), so the auto-generated "Projects" back button is gone and
        // the square 44pt back cell labelled "Back" takes its place. Same
        // affordance, same assertion — only the accessibility identifier of
        // the control being tapped changed.
        app.buttons["Back"].tap()
        XCTAssertTrue(
            app.staticTexts["Projects"].waitForExistence(timeout: 5),
            "Back navigation should return to the project list"
        )
    }
}
