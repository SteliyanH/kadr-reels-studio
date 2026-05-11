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
}
