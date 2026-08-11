import XCTest
import SwiftUI
import ViewInspector
import Kadr
@testable import ReelsStudio
#if canImport(UIKit)
import UIKit
#endif

/// Pure-helper tests for v0.5 Tier 2 accessibility wiring. The modifier
/// calls themselves (`.accessibilityLabel`, `.accessibilityHint`,
/// `.accessibilityValue`, `.accessibilityElement(children:)`) are
/// exercised by the build / Xcode Accessibility Inspector / VoiceOver QA;
/// here we pin down the few derived strings whose shape could regress
/// silently.
@MainActor
final class ProjectRowAccessibilityTests: XCTestCase {

    func testDescriptionIncludesName() {
        let doc = ProjectDocument(name: "Reels Demo")
        let desc = ProjectRow.accessibilityDescription(for: doc)
        XCTAssertTrue(desc.contains("Reels Demo"))
    }

    func testDescriptionMentionsRelativeModifiedDate() {
        let doc = ProjectDocument(name: "x", modifiedAt: Date().addingTimeInterval(-86_400 * 2))
        let desc = ProjectRow.accessibilityDescription(for: doc)
        XCTAssertTrue(desc.contains("modified"))
    }

    private func makeImageClip() -> ProjectClip {
        .image(ImageClipData(
            storage: .url(URL(fileURLWithPath: "/tmp/placeholder.png")),
            durationSeconds: 1
        ))
    }

    func testSingularClipLabel() {
        let doc = ProjectDocument(name: "x", clips: [makeImageClip()])
        let desc = ProjectRow.accessibilityDescription(for: doc)
        XCTAssertTrue(desc.contains("1 clip,") || desc.hasSuffix("1 clip"))
        XCTAssertFalse(desc.contains("1 clips"))
    }

    func testPluralClipLabel() {
        let doc = ProjectDocument(name: "x", clips: [makeImageClip(), makeImageClip(), makeImageClip()])
        let desc = ProjectRow.accessibilityDescription(for: doc)
        XCTAssertTrue(desc.contains("3 clips"))
    }

    func testEmptyProjectReportsZeroClips() {
        let doc = ProjectDocument(name: "x")
        let desc = ProjectRow.accessibilityDescription(for: doc)
        XCTAssertTrue(desc.contains("0 clips"))
    }

    // MARK: - Tier 6 contrast binding rule
    //
    // `palette.accent` at paragraph size only clears ~3:1 against either
    // ground's `bg` — legible for large text and glyphs, not body copy.
    // `accentText` is the paragraph-safe step (a700 on print, a400 on
    // studio). These pin the token wiring the Tier 6 sweep's ExportSheet fix
    // (`stage == .failed ? palette.accentText : palette.text`) depends on, so
    // a future edit that quietly re-aliases `accentText` back to the base
    // `accent` fails here instead of shipping a body-text contrast
    // regression.

    func testPrintAccentTextIsA700NotBaseAccent() {
        XCTAssertEqual(ModernistPalette.print.accentText, Modernist.Accent.a700)
        XCTAssertNotEqual(ModernistPalette.print.accentText, ModernistPalette.print.accent)
    }

    func testStudioAccentTextIsA400NotBaseAccent() {
        XCTAssertEqual(ModernistPalette.studio.accentText, Modernist.Accent.a400)
        XCTAssertNotEqual(ModernistPalette.studio.accentText, ModernistPalette.studio.accent)
    }
}

// MARK: - ModernistSlider adjustability

/// The migration replaced every native `Slider` with a `DragGesture`-driven
/// `ModernistSlider`. A drag is not operable without sight, so twelve call
/// sites — opacity, font size, chroma threshold, speed, SFX volume — went from
/// adjustable to unusable. The a11y tests of the day missed it because they
/// only ever asserted strings.
///
/// So these assert movement, not strings. `ModernistSlider.adjusted` is the
/// whole body of the `.accessibilityAdjustableAction` closure:
///
///     .accessibilityAdjustableAction { direction in
///         value = Self.adjusted(value, direction: direction, range: range, step: step)
///     }
///
/// — so exercising it exercises what a VoiceOver swipe does, step and clamping
/// included.
///
/// **On the half these can't reach.** Firing the *attached* action needs a
/// reader for it, and on this runtime there isn't one: ViewInspector 0.10.3's
/// `callAccessibilityAdjustableAction` only implements the pre-iOS-26 storage
/// layout (its `accessibilityLabel` / `accessibilityValue` readers gained an
/// iOS 26 branch; the action callers didn't), SwiftUI's UIKit accessibility
/// tree is empty when no assistive technology is attached, and the closure
/// itself doesn't survive `Mirror`. `testSliderStillCarriesItsAccessibilityBlock`
/// below is the partial guard that is reachable — it fails if the a11y
/// modifiers are stripped as a group, though not if the adjustable line alone
/// is deleted. Closing that gap needs ViewInspector to add the iOS 26 path, or
/// a VoiceOver-driven UI test.
@MainActor
final class ModernistSliderAdjustabilityTests: XCTestCase {

    /// One VoiceOver swipe, as the attached action performs it.
    private func swipe(
        _ direction: AccessibilityAdjustmentDirection,
        from start: Double,
        range: ClosedRange<Double>,
        step: Double? = nil
    ) -> Double {
        ModernistSlider.adjusted(start, direction: direction, range: range, step: step)
    }

    // MARK: Continuous sliders — one swipe is a twentieth of the span

    func testContinuousIncrementMovesByATwentiethOfTheSpan() {
        XCTAssertEqual(swipe(.increment, from: 0.5, range: 0...1), 0.55, accuracy: 1e-9)
    }

    func testContinuousDecrementMovesByATwentiethOfTheSpan() {
        XCTAssertEqual(swipe(.decrement, from: 0.5, range: 0...1), 0.45, accuracy: 1e-9)
    }

    func testContinuousIncrementClampsAtUpperBound() {
        XCTAssertEqual(swipe(.increment, from: 1.0, range: 0...1), 1.0, accuracy: 1e-9)
    }

    func testContinuousDecrementClampsAtLowerBound() {
        XCTAssertEqual(swipe(.decrement, from: 0.0, range: 0...1), 0.0, accuracy: 1e-9)
    }

    /// A range that doesn't start at zero — the text-shadow offset rows run
    /// -20...20, where a step computed off the *value* rather than the span
    /// would stall at zero.
    func testSignedRangeMovesByATwentiethOfTheSpanNotOfTheValue() {
        XCTAssertEqual(swipe(.increment, from: 0, range: -20...20), 2, accuracy: 1e-9)
        XCTAssertEqual(swipe(.decrement, from: 0, range: -20...20), -2, accuracy: 1e-9)
    }

    /// The stroke-width row runs 0.5...10 — a span whose twentieth is not a
    /// round number, and must still land inside the range.
    func testFractionalSpanStaysInsideItsRange() {
        XCTAssertEqual(swipe(.increment, from: 0.5, range: 0.5...10), 0.975, accuracy: 1e-9)
        XCTAssertEqual(swipe(.decrement, from: 0.5, range: 0.5...10), 0.5, accuracy: 1e-9)
        XCTAssertEqual(swipe(.increment, from: 10, range: 0.5...10), 10, accuracy: 1e-9)
    }

    // MARK: Stepped sliders — one swipe is exactly one step

    func testSteppedIncrementMovesByExactlyOneStep() {
        XCTAssertEqual(swipe(.increment, from: 56, range: 24...96, step: 2), 58, accuracy: 1e-9)
    }

    func testSteppedDecrementMovesByExactlyOneStep() {
        XCTAssertEqual(swipe(.decrement, from: 56, range: 24...96, step: 2), 54, accuracy: 1e-9)
    }

    func testSteppedIncrementClampsAtUpperBound() {
        XCTAssertEqual(swipe(.increment, from: 96, range: 24...96, step: 2), 96, accuracy: 1e-9)
    }

    func testSteppedDecrementClampsAtLowerBound() {
        XCTAssertEqual(swipe(.decrement, from: 24, range: 24...96, step: 2), 24, accuracy: 1e-9)
    }

    /// Swiping from the floor must reach the ceiling and stop there, without
    /// ever leaving the step grid on the way.
    func testRepeatedSwipesStayOnTheGridAndInsideTheRange() {
        var value: Double = 24
        for _ in 0..<60 {
            value = swipe(.increment, from: value, range: 24...96, step: 2)
            XCTAssertTrue((24...96).contains(value))
            XCTAssertEqual(value.truncatingRemainder(dividingBy: 2), 0, accuracy: 1e-9)
        }
        XCTAssertEqual(value, 96, accuracy: 1e-9)
    }

    func testAdjustmentStepPrefersAnExplicitStepOverTheSpanFraction() {
        XCTAssertEqual(
            ModernistSlider.adjustmentStep(range: 24...96, step: 2), 2, accuracy: 1e-9
        )
        XCTAssertEqual(
            ModernistSlider.adjustmentStep(range: 24...96, step: nil), 3.6, accuracy: 1e-9
        )
    }

    // MARK: Drag and adjust resolve through the same grid

    func testDragResolutionSnapsToTheStepGrid() {
        XCTAssertEqual(ModernistSlider.resolve(57.3, range: 24...96, step: 2), 58, accuracy: 1e-9)
        XCTAssertEqual(ModernistSlider.resolve(56.9, range: 24...96, step: 2), 56, accuracy: 1e-9)
    }

    func testDragResolutionWithoutAStepStaysContinuous() {
        XCTAssertEqual(
            ModernistSlider.resolve(0.3333, range: 0...1, step: nil), 0.3333, accuracy: 1e-9
        )
    }

    func testDragResolutionClampsOutsideTheRange() {
        XCTAssertEqual(ModernistSlider.resolve(-5, range: 0...1, step: nil), 0, accuracy: 1e-9)
        XCTAssertEqual(ModernistSlider.resolve(9, range: 0...1, step: nil), 1, accuracy: 1e-9)
    }

    /// Every value VoiceOver can reach must also be a value a drag can reach,
    /// or the two inputs disagree about what the control holds.
    func testAdjustedValuesAreAlwaysValidDragValues() {
        for start in stride(from: 24.0, through: 96.0, by: 2.0) {
            for direction in [AccessibilityAdjustmentDirection.increment, .decrement] {
                let landed = ModernistSlider.adjusted(
                    start, direction: direction, range: 24...96, step: 2
                )
                XCTAssertEqual(
                    landed,
                    ModernistSlider.resolve(landed, range: 24...96, step: 2),
                    accuracy: 1e-9
                )
            }
        }
    }

    // MARK: The accessibility block is still attached

    /// Reachable half of the attachment guard: the label and value readers
    /// resolve against the same `AccessibilityAttachmentModifier` the
    /// adjustable action is stored in, so stripping the a11y block fails here.
    func testSliderStillCarriesItsAccessibilityBlock() throws {
        let sut = ModernistSlider(
            label: "Opacity",
            value: .constant(0.5),
            range: 0...1,
            valueText: "50%"
        )
        XCTAssertEqual(try sut.inspect().hStack().accessibilityLabel().string(), "Opacity")
        XCTAssertEqual(try sut.inspect().hStack().accessibilityValue().string(), "50%")
    }
}

// MARK: - Sheet heading semantics

/// ~11 sheets moved off `.navigationTitle` — which carries the heading trait,
/// and with it a place in VoiceOver's heading rotor — onto a title band the
/// app draws. `ModernistSheetHeader` restates the trait so all of them get it
/// back at once.
///
/// **The trait itself is not assertable from this suite**, and that is stated
/// rather than papered over: ViewInspector 0.10.3 ships readers for
/// `accessibilityLabel`, `Value`, `Hint`, `Hidden`, `Identifier` and
/// `SortPriority`, and none for `accessibilityAddTraits`; the UIKit
/// accessibility tree that would carry `UIAccessibilityTraits.header` is empty
/// under a hosted `UIHostingController` with no assistive technology attached
/// (verified — the hosting view reports zero accessibility elements). What is
/// pinned here is the title element the trait rides on, so a header that stops
/// drawing a title — the other way this regresses — still fails.
@MainActor
final class ModernistSheetHeaderAccessibilityTests: XCTestCase {

    func testHeaderRendersTheTitleTheHeadingTraitRidesOn() throws {
        let header = ModernistSheetHeader("Add Overlay") { EmptyView() }
        XCTAssertNoThrow(try header.inspect().find(text: "Add Overlay"))
    }

    func testHeaderRendersItsTrailingActionsAlongsideTheTitle() throws {
        let header = ModernistSheetHeader("Settings") { Button("Done") { } }
        XCTAssertNoThrow(try header.inspect().find(text: "Settings"))
        XCTAssertNoThrow(try header.inspect().find(button: "Done"))
    }
}

