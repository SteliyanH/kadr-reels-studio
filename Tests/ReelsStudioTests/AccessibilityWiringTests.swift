import XCTest
import Kadr
@testable import ReelsStudio

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
