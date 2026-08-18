import XCTest
import SwiftUI
@testable import ReelsStudio

/// v0.8.2 — Dynamic Type, bounded.
///
/// The design migration replaced system text styles with a fixed scale, which
/// silently made the app ignore the user's text-size setting: not "Dynamic Type
/// un-audited" but "Dynamic Type unsupported". These tests hold the fix in
/// place from both ends — text must actually grow, and it must stop growing
/// where the layout says it must.
///
/// Measured by rendering `Text` through `ImageRenderer` and comparing the size
/// the renderer reports, which is the same technique `ReelTypographyTests` uses
/// to check which font cut got embedded. Asserting the token alone would prove
/// nothing: a `relativeTo:` that was never passed would still leave the token
/// looking right.
final class DynamicTypeTests: XCTestCase {

    /// Rendered height of a line of text at a given Dynamic Type size.
    @MainActor
    private func renderedHeight<V: View>(_ content: V, at size: DynamicTypeSize) -> CGFloat {
        let renderer = ImageRenderer(
            content: content.environment(\.dynamicTypeSize, size)
        )
        var height: CGFloat = 0
        renderer.render { size, _ in height = size.height }
        return height
    }

    @MainActor
    private func sample(_ font: Font) -> some View {
        Text("Hamburgefonstiv").font(font)
    }

    // MARK: - It scales

    @MainActor
    func testBodyTextGrowsWithTheUsersSetting() {
        let small = renderedHeight(sample(Reel.Typography.body), at: .large)
        let large = renderedHeight(sample(Reel.Typography.body), at: .accessibility1)

        XCTAssertGreaterThan(
            large, small,
            "Body text must respond to Dynamic Type. If these are equal the scale "
            + "has been pinned again — check for `fixedSize:` in Typography.font."
        )
    }

    @MainActor
    func testHeadingsGrowToo() {
        let small = renderedHeight(sample(Reel.Typography.h2), at: .large)
        let large = renderedHeight(sample(Reel.Typography.h2), at: .accessibility1)
        XCTAssertGreaterThan(large, small)
    }

    @MainActor
    func testCaptionAndNumericGrowToo() {
        // The numeric role carries timecodes. It is the smallest text in the app
        // and the most likely to be left behind by a partial migration.
        for font in [Reel.Typography.caption, Reel.Typography.numeric] {
            let small = renderedHeight(sample(font), at: .large)
            let large = renderedHeight(sample(font), at: .accessibility1)
            XCTAssertGreaterThan(large, small)
        }
    }

    // MARK: - And it stops

    @MainActor
    func testGrowthIsClampedAtTheDocumentedCeiling() {
        // Same content, clamped, asked for the largest size there is. It must
        // render no larger than at the ceiling itself.
        let clamped = sample(Reel.Typography.h2).dynamicTypeSize(...Reel.maxDynamicTypeSize)

        let atCeiling = renderedHeight(clamped, at: Reel.maxDynamicTypeSize)
        let beyond = renderedHeight(clamped, at: .accessibility5)

        XCTAssertEqual(
            beyond, atCeiling, accuracy: 0.5,
            "Growth past \(Reel.maxDynamicTypeSize) must be clamped — the grid "
            + "was drawn against fixed sizes and comes apart above it."
        )
    }

    @MainActor
    func testWithoutTheClampTextWouldKeepGrowing() {
        // Guards the test above from passing for the wrong reason: if the two
        // sizes were identical anyway, the clamp assertion would be vacuous.
        let unclamped = sample(Reel.Typography.h2)
        let atCeiling = renderedHeight(unclamped, at: Reel.maxDynamicTypeSize)
        let beyond = renderedHeight(unclamped, at: .accessibility5)

        XCTAssertGreaterThan(
            beyond, atCeiling,
            "If unclamped text does not grow past the ceiling, the clamp test "
            + "proves nothing."
        )
    }

    // MARK: - The decision itself

    func testCeilingIsTheDocumentedValue() {
        // Pinned so raising it is a deliberate edit with a failing test to
        // explain itself, not a quiet tweak.
        XCTAssertEqual(Reel.maxDynamicTypeSize, .accessibility1)
    }
}
