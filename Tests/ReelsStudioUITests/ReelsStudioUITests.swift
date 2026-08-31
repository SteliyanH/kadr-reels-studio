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
/// `@MainActor` because every XCUI type this suite touches — `XCUIApplication`,
/// `XCUIElement`, their subscripts — is main-actor isolated in the SDK, and
/// XCTest already runs these methods on the main thread. Without the
/// annotation the whole file compiled on 67 concurrency warnings, which is
/// exactly the kind of noise that hid three real recursion warnings in #96.
@MainActor
final class ReelsStudioUITests: XCTestCase {

    /// How long to wait for a UI element to appear.
    ///
    /// Raised from a per-call `5` after `testEditorSettingsGearOpensSheet`
    /// failed once on CI and passed on a re-run of the same commit, and passed
    /// 6/6 locally — a loaded hosted runner presenting a sheet, not a defect.
    ///
    /// A generous timeout costs nothing when the element appears promptly,
    /// because `waitForExistence` returns as soon as it does. It only costs
    /// time on a genuine failure, which is the case where waiting longer is
    /// worth it anyway. Re-running until green would have hidden this instead
    /// of fixing it.
    private static let uiTimeout: TimeInterval = 20


    private var app: XCUIApplication!

    // The `async` variant, because an override inherits its superclass's
    // isolation and `setUpWithError()` is nonisolated — so it could not touch
    // the main-actor `app` this class now holds. Swift allows an override of
    // an `async` method to add isolation; the synchronous one gives no such
    // opening.
    @MainActor
    override func setUp() async throws {
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
            app.staticTexts["No projects yet"].waitForExistence(timeout: Self.uiTimeout),
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
        XCTAssertTrue(newProjectButton.waitForExistence(timeout: Self.uiTimeout))
        newProjectButton.tap()

        // EditorView's top toolbar carries the Settings gear from v0.5 — its
        // accessibilityLabel is "Settings" and it survives across editor
        // mode changes (clip / overlay selection), making it the most stable
        // editor-presence assertion.
        XCTAssertTrue(
            app.buttons["Settings"].waitForExistence(timeout: Self.uiTimeout),
            "Tapping New Project should push the editor onto the nav stack"
        )
    }

    // MARK: - Sample import

    func testSampleButtonImportsAndOpensEditor() {
        app.launch()
        let sampleButton = app.buttons["Sample"]
        XCTAssertTrue(sampleButton.waitForExistence(timeout: Self.uiTimeout))
        sampleButton.tap()

        XCTAssertTrue(
            app.buttons["Settings"].waitForExistence(timeout: Self.uiTimeout),
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
        XCTAssertTrue(newProject.waitForExistence(timeout: Self.uiTimeout))
        newProject.tap()
        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: Self.uiTimeout))
        settings.tap()

        // Assert on the Haptics section's "Medium" option button rather than the
        // section header text: `Form` section headers are exposed with OS-dependent
        // casing (title-case "Haptics" on some runtimes, uppercased "HAPTICS" on
        // others), so a header-text match is brittle across SDKs. Button labels keep
        // their case, and "Medium" is unique to the Haptics section — a stable proof
        // the Settings sheet presented.
        XCTAssertTrue(
            app.buttons["Medium"].waitForExistence(timeout: Self.uiTimeout),
            "Tapping the gear should present the Settings sheet"
        )
    }

    // MARK: - Back to library

    func testBackNavigationReturnsToProjectList() {
        app.launch()
        let newProject = app.buttons["New Project"].firstMatch
        XCTAssertTrue(newProject.waitForExistence(timeout: Self.uiTimeout))
        newProject.tap()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: Self.uiTimeout))

        // v0.8 Tier 5b — the editor draws its own nav band (the system bar
        // can't carry the two-line title block or the ruled undo/redo cell
        // group), so the auto-generated "Projects" back button is gone and
        // the square 44pt back cell labelled "Back" takes its place. Same
        // affordance, same assertion — only the accessibility identifier of
        // the control being tapped changed.
        app.buttons["Back"].tap()
        XCTAssertTrue(
            app.staticTexts["Projects"].waitForExistence(timeout: Self.uiTimeout),
            "Back navigation should return to the project list"
        )
    }

    // MARK: - Interactive pop (edge swipe)

    /// The witness for the drawn nav band's cost. Hiding the system bar takes
    /// UIKit's interactive pop with it, and nothing in this suite could see
    /// that: the Back-button test above taps a control the app draws itself,
    /// so it stays green while the *gesture* is dead. Only a real edge drag
    /// tells the two apart, which is why this test drags rather than taps.
    ///
    /// The drag starts at dx 0.002 — inside the screen-edge recogniser's
    /// activation strip — and is preceded by a short press so the gesture is
    /// delivered as a drag rather than a flick.
    func testEdgeSwipeFromLeftEdgePopsEditorBackToProjectList() {
        app.launch()
        let newProject = app.buttons["New Project"].firstMatch
        XCTAssertTrue(newProject.waitForExistence(timeout: Self.uiTimeout))
        newProject.tap()

        // The gear is this suite's standing proof of editor presence.
        let settingsGear = app.buttons["Settings"]
        XCTAssertTrue(
            settingsGear.waitForExistence(timeout: Self.uiTimeout),
            "New Project should push the editor before the swipe is attempted"
        )

        let leftEdge = app.coordinate(withNormalizedOffset: CGVector(dx: 0.002, dy: 0.5))
        let acrossTheScreen = app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
        leftEdge.press(forDuration: 0.08, thenDragTo: acrossTheScreen)

        // Asserted first, and deliberately: "Projects" alone could pass
        // vacuously if the popped-from screen's title lingered in the tree.
        // The editor's own control disappearing is the unambiguous proof the
        // stack actually popped.
        XCTAssertTrue(
            settingsGear.waitForNonExistence(timeout: 5),
            "Edge swipe should pop the editor off the stack, taking its gear with it"
        )
        XCTAssertTrue(
            app.staticTexts["Projects"].waitForExistence(timeout: Self.uiTimeout),
            "Edge swipe should return to the project list"
        )
    }
}
