import XCTest
import CoreMedia
import SwiftUI
import ViewInspector
import Kadr
import KadrPersistence
@testable import ReelsStudio

/// Issue #73 — accessibility contract for the v0.9 transport band.
///
/// This suite exists because of a prior failure mode in this repo: controls
/// shipped with accessibility annotations attached, but the annotations were
/// static or the state they were supposed to expose (a toggle's on/off,
/// which of two faces a button was wearing) never reached VoiceOver. So
/// nothing here just checks that a modifier is present — every assertion
/// either drives the view tree with real state and reads back the label /
/// value / disabled flag ViewInspector can see, or, where ViewInspector 0.10.3
/// genuinely cannot reach a signal (traits, `accessibilityElement(children:)`
/// grouping semantics, real VoiceOver focus order), pins the pure
/// state → string mapping the view is built on and says plainly that the
/// rest needs a screen reader.
///
/// Each test is marked view-tree-backed or logic-only in its doc comment.
@MainActor
final class TransportAccessibilityTests: XCTestCase {

    private func seconds(_ value: Double) -> CMTime {
        CMTime(seconds: value, preferredTimescale: 600)
    }

    /// A store whose composition is `length` seconds long — same fixture
    /// shape as `TransportBandTests.makeStore`, built independently here so
    /// this file has no dependency on that one.
    private func makeStore(length: Double = 6) -> ProjectStore {
        ProjectStore(project: Project(clips: [
            VideoClip(url: URL(fileURLWithPath: "/dev/null"))
                .trimmed(to: 0...length)
                .id("clip-a")
        ]))
    }

    private func button(
        _ band: ReelTransportBand,
        labelled label: String
    ) throws -> InspectableView<ViewType.Button> {
        try band.inspect().find(ViewType.Button.self, where: {
            (try? $0.accessibilityLabel().string()) == label
        })
    }

    // MARK: - 1. Play/pause is one button, not two

    /// View-tree-backed. Drives `store.isPlaying` both ways and reads the
    /// button count back from the live tree each time: the total number of
    /// buttons in the band never changes, and exactly one button carries
    /// whichever of "Play" / "Pause" matches the current state. A
    /// two-buttons-swapped-in-and-out implementation would either fail the
    /// stable count or leave both labels present at once.
    func testPlayPauseIsOneButtonThatSwapsItsLabelRatherThanTwoButtons() throws {
        let store = makeStore()
        XCTAssertFalse(store.isPlaying)
        let band = ReelTransportBand(store: store)

        let totalBefore = try band.inspect().findAll(ViewType.Button.self).count
        XCTAssertNoThrow(try button(band, labelled: "Play"))
        XCTAssertThrowsError(try button(band, labelled: "Pause"))

        store.isPlaying = true

        let totalAfter = try band.inspect().findAll(ViewType.Button.self).count
        XCTAssertEqual(totalBefore, totalAfter, "toggling isPlaying must not add or remove a button")
        XCTAssertNoThrow(try button(band, labelled: "Pause"))
        XCTAssertThrowsError(try button(band, labelled: "Play"))
    }

    /// Logic-only. The label the button reads its text from is a pure
    /// function of `isPlaying` — pinned directly so a regression there is
    /// caught even in a context where the view tree is awkward to traverse.
    func testPlayPauseLabelIsAPureFunctionOfIsPlaying() {
        XCTAssertEqual(ReelTransportBand.playPauseLabel(isPlaying: false), "Play")
        XCTAssertEqual(ReelTransportBand.playPauseLabel(isPlaying: true), "Pause")
    }

    // MARK: - 2. Skip back disables at the zero bound

    /// View-tree-backed. `.disabled()` is read straight off the live button
    /// via ViewInspector's `isDisabled()`, driven by an actual playhead
    /// position rather than asserted against the pure predicate alone — this
    /// is the half of the contract that proves the predicate is actually
    /// wired to the button and not just sitting unused nearby.
    func testSkipBackIsDisabledOnlyWhenThePlayheadIsAtZero() throws {
        let store = makeStore(length: 6)
        let band = ReelTransportBand(store: store)

        XCTAssertTrue(store.currentTime == .zero)
        XCTAssertTrue(try button(band, labelled: "Skip back").isDisabled())

        store.currentTime = seconds(2)
        XCTAssertFalse(try button(band, labelled: "Skip back").isDisabled())

        store.currentTime = .zero
        XCTAssertTrue(try button(band, labelled: "Skip back").isDisabled())
    }

    // MARK: - 3. Skip forward disables at the duration bound

    /// View-tree-backed, mirroring the skip-back case at the opposite bound.
    func testSkipForwardIsDisabledOnlyAtTheCompositionDuration() throws {
        let store = makeStore(length: 6)
        let band = ReelTransportBand(store: store)

        store.currentTime = seconds(3)
        XCTAssertFalse(try button(band, labelled: "Skip forward").isDisabled())

        store.currentTime = seconds(6)
        XCTAssertTrue(try button(band, labelled: "Skip forward").isDisabled())
    }

    // MARK: - 4. Loop: label is stable, value carries the toggle state

    /// View-tree-backed for label and value. A label alone ("Loop", never
    /// changing) tells VoiceOver nothing about whether loop is on; the value
    /// is what has to carry that, and this drives `store.isLooping` both ways
    /// and reads the value back off the live button each time.
    func testLoopLabelStaysConstantWhileValueCarriesTheToggleState() throws {
        let store = makeStore()
        let band = ReelTransportBand(store: store)

        XCTAssertFalse(store.isLooping)
        XCTAssertEqual(try button(band, labelled: "Loop").accessibilityLabel().string(), "Loop")
        XCTAssertEqual(try button(band, labelled: "Loop").accessibilityValue().string(), "Off")

        store.isLooping = true
        // Label must still resolve under the same fixed "Loop" query — if
        // the implementation folded the on/off state into the label instead
        // of the value, this same lookup would start failing.
        XCTAssertEqual(try button(band, labelled: "Loop").accessibilityLabel().string(), "Loop")
        XCTAssertEqual(try button(band, labelled: "Loop").accessibilityValue().string(), "On")
    }

    /// Logic-only, and the boundary is explicit: ViewInspector 0.10.3 ships
    /// no reader for `accessibilityAddTraits` (confirmed against the
    /// installed package — no `AccessibilityTraits`/`accessibilityAddTraits`
    /// symbol anywhere in its sources), so `.isSelected` firing when
    /// `store.isLooping` is true is NOT verified by this suite in the view
    /// tree. What's pinned here is the value string the trait is meant to
    /// reinforce; the trait itself needs a human with VoiceOver or the
    /// Accessibility Inspector's audit.
    func testLoopValueLabelIsAPureFunctionOfIsLooping() {
        XCTAssertEqual(ReelTransportBand.loopValueLabel(isLooping: false), "Off")
        XCTAssertEqual(ReelTransportBand.loopValueLabel(isLooping: true), "On")
    }

    // MARK: - 5. Fullscreen: only exit affordance, present and labelled

    /// View-tree-backed. Fullscreen hides the rest of the editor chrome in
    /// place, so if the exit control were mislabelled or missing while
    /// `isFullscreen` is true, there would be no other way out — this proves
    /// the exit button resolves by its expected label specifically in that
    /// state, not merely that *some* fullscreen button exists.
    func testFullscreenExitControlIsPresentAndLabelledWhenActive() throws {
        let band = ReelTransportBand(store: makeStore(), isFullscreen: .constant(true))
        XCTAssertNoThrow(try button(band, labelled: "Exit full screen"))
        XCTAssertThrowsError(try button(band, labelled: "Enter full screen"))
    }

    /// View-tree-backed. The other half of the same switch, inactive state.
    func testFullscreenEnterControlIsPresentAndLabelledWhenInactive() throws {
        let band = ReelTransportBand(store: makeStore(), isFullscreen: .constant(false))
        XCTAssertNoThrow(try button(band, labelled: "Enter full screen"))
        XCTAssertThrowsError(try button(band, labelled: "Exit full screen"))
    }

    /// Logic-only, same boundary as loop: `.isSelected` on the fullscreen
    /// button when active is not verifiable through ViewInspector 0.10.3
    /// here. What's pinned is the pure label switch it's built on.
    func testFullscreenLabelIsAPureFunctionOfIsFullscreen() {
        XCTAssertEqual(ReelTransportBand.fullscreenLabel(isFullscreen: false), "Enter full screen")
        XCTAssertEqual(ReelTransportBand.fullscreenLabel(isFullscreen: true), "Exit full screen")
    }

    // MARK: - 6. Time readout: one combined element, not two Texts

    /// View-tree-backed, as far as ViewInspector 0.10.3 can reach. This
    /// finds the `Text` carrying the elapsed time, walks up to its `HStack`
    /// parent, and confirms that *same* HStack both (a) also contains the
    /// total-time `Text` and (b) carries a single `accessibilityLabel`
    /// matching the "elapsed of total" sentence — i.e. label and both raw
    /// values live on one container, not scattered across sibling elements.
    ///
    /// What this does NOT verify: ViewInspector ships no reader for
    /// `accessibilityElement(children:)`, so whether SwiftUI actually
    /// collapses the three child `Text` views into a single accessibility
    /// node for VoiceOver (versus merely attaching a label that a reader
    /// might still enumerate three sub-elements around) is not checked here
    /// and needs VoiceOver / Accessibility Inspector confirmation.
    func testTimeReadoutIsOneElementCarryingBothElapsedAndTotal() throws {
        let store = makeStore(length: 6)
        store.currentTime = seconds(1)
        let band = ReelTransportBand(store: store)

        XCTAssertEqual(CMTimeGetSeconds(store.video.duration), 6, accuracy: 0.001)

        let elapsedText = try band.inspect().find(text: "0:01")
        let container = try elapsedText.find(ViewType.HStack.self, relation: .parent)

        XCTAssertNoThrow(try container.find(text: "0:06"))
        XCTAssertEqual(try container.accessibilityLabel().string(), "0:01 of 0:06")
    }

    /// Logic-only. The sentence format itself, independent of the view tree.
    func testTimeReadoutLabelCombinesElapsedAndTotalIntoOneSentence() {
        XCTAssertEqual(
            ReelTransportBand.timeReadoutLabel(elapsed: "0:01", total: "0:06"),
            "0:01 of 0:06"
        )
    }

    // MARK: - 7. Every control rides ReelIconButtonStyle at the 44pt token

    /// Pure fact, not view-tree-backed — pins the design-system token
    /// `ReelIconButtonStyle` frames to, so a change to `Reel.minHitTarget`
    /// that drops it below the WCAG 2.2 AA (2.5.8) 24×24 CSS-px floor — or
    /// below this app's own 44pt bar — is caught here independent of
    /// whether any view actually uses it correctly.
    func testMinHitTargetTokenIs44Points() {
        XCTAssertEqual(Reel.minHitTarget, 44)
    }

    /// View-tree-backed. Every button ViewInspector finds in the band is
    /// checked against `ReelIconButtonStyle` via `InspectableView.buttonStyle()`
    /// (ViewInspector 0.10.3 does expose a `buttonStyle()` reader that
    /// resolves the concrete `ButtonStyle` value, unlike `accessibilityAddTraits`).
    /// A later refactor that swaps one control onto a bespoke style, or onto
    /// `ReelGhostButtonStyle` (which pads to the same token but is a
    /// different type), fails this test.
    ///
    /// The band currently exposes five interactive buttons — skip back,
    /// play/pause, skip forward, loop, fullscreen — plus the time readout,
    /// which is not a button at all. The count below is a regression guard
    /// on that shape; if a sixth control is added, this test's failure is
    /// the intended signal to update it alongside the new control's own
    /// accessibility coverage.
    func testEveryButtonInTheBandUsesReelIconButtonStyle() throws {
        let band = ReelTransportBand(store: makeStore(), isFullscreen: .constant(true))
        let buttons = try band.inspect().findAll(ViewType.Button.self)

        XCTAssertEqual(buttons.count, 5)
        for control in buttons {
            let style = try control.buttonStyle()
            XCTAssertTrue(
                style is ReelIconButtonStyle,
                "expected ReelIconButtonStyle, found \(type(of: style))"
            )
        }
    }

    // MARK: - Localization: a11y-relevant keys resolve, format keeps both specifiers

    /// `NSLocalizedString` silently returns the key itself when the bundle
    /// or the entry is missing, and `LocalizationTests` doesn't cover the
    /// `transport.*` keys — so a missing entry here would currently ship
    /// unnoticed. Equality against the agreed English copy catches a missing
    /// file, a missing key and a typo'd value alike.
    func testAccessibilityRelevantTransportKeysResolveFromTheBundle() {
        XCTAssertEqual(NSLocalizedString("transport.play", comment: ""), "Play")
        XCTAssertEqual(NSLocalizedString("transport.pause", comment: ""), "Pause")
        XCTAssertEqual(NSLocalizedString("transport.skipBack", comment: ""), "Skip back")
        XCTAssertEqual(NSLocalizedString("transport.skipForward", comment: ""), "Skip forward")
        XCTAssertEqual(NSLocalizedString("transport.loop", comment: ""), "Loop")
        XCTAssertEqual(NSLocalizedString("transport.loop.on", comment: ""), "On")
        XCTAssertEqual(NSLocalizedString("transport.loop.off", comment: ""), "Off")
        XCTAssertEqual(
            NSLocalizedString("transport.fullscreen.enter", comment: ""),
            "Enter full screen"
        )
        XCTAssertEqual(
            NSLocalizedString("transport.fullscreen.exit", comment: ""),
            "Exit full screen"
        )
        XCTAssertEqual(NSLocalizedString("transport.time.a11y", comment: ""), "%1$@ of %2$@")
    }

    /// Mirrors `LocalizationTests.testFormatKeysCarryFormatSpecifiers` (line
    /// 25): a positional-specifier format string can lose one placeholder to
    /// a copy-paste fix without the string becoming empty or obviously wrong,
    /// which would silently collapse "elapsed of total" into just one time.
    func testTimeReadoutFormatRetainsBothPositionalSpecifiers() {
        let format = NSLocalizedString("transport.time.a11y", comment: "")
        XCTAssertTrue(format.contains("%1$@"))
        XCTAssertTrue(format.contains("%2$@"))
    }
}
